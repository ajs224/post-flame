#!/usr/bin/perl
#-w
#
# Perl script to generate MOPS (sweep) input file for means of species concentrations, etc., along each particle track
#
# A. J. Smith (ajs224@cam.ac.uk)
# Updated 27/07/2011
#

my $numArgs=$#ARGV+1;

if($numArgs<1)
{
    print "Usage: $0 <dir containing track files>\n";
    print "e.g., $0 mops_tst_run\n\n";
    exit(0);
}

my $runDir=$ARGV[0];
my $sourceDir="./mops_common/";
my $molWeightFile=$sourceDir."TiCl4SystemMWs.dat"; # units kg/
$gasphaseMassFrac="/gasphase_MassFrac.inp";

my %mol_weight=();
my @track_data;

# Read molecular weights into a file
open(MWFILE, "< $molWeightFile") or die("Can't open molecular weights data");
while(chomp($mwdata=<MWFILE>))
      {
	my @mwparts=split(/\s/, $mwdata);
	my $mw=pop(@mwparts);
	my $species=pop(@mwparts);
	$mol_weight{$species}=$mw;
      }
close(MWFILE);


opendir (DIR, $runDir) or die $!;
while ($track = readdir(DIR))
  {
    next unless ($track =~ m/^track/);
    $trkFile="$runDir/".$track.$gasphaseMassFrac;
    #print $trkFile;
    open(TRKFILE, "< $trkFile") or die("Can't open track file");


    chomp($header=<TRKFILE>); # Extract header

     # Extract species names from headers
    my @headers=split(/,/, $header);
    shift(@headers); # Remove time
    shift(@headers); # Remove temp
    pop(@headers); # Remove p
    pop(@headers); # Remove wdotA4
    pop(@headers); # Remove rho
    my @speciesNames=@headers;

    # Changed commas to tabs and change p to P
    $header=~ s/,/\t/g;
    $header=~ s/p/P/g;

    # This is actually required by MOPS
    $molFracGasPhaseFile="$runDir/".$track."/gasphase.inp";
    open(MOLOUTFILE, "> $molFracGasPhaseFile") or die("Can't open track mole frac gasphase file");
    print MOLOUTFILE $header,"\n";

    $molConcGasPhaseFile="$runDir/".$track."/gasphase_MolConc.inp";
    open(CONCOUTFILE, "> $molConcGasPhaseFile") or die("Can't open track mole conc gasphase file");
    print CONCOUTFILE $header,"\n";

    $timefile="$runDir/".$track."/time_intervals";
    open(TIMEFILE, "> $timefile") or die("Can't open time interval dump file file");

    my $startTime="0.0";
    print TIMEFILE "<start>",$startTime,"</start>\n";

    # Process the mass fraction gasphase profile line by line
    while(chomp($trkdata=<TRKFILE>))
      {
	@track_data=();
	@track_data=split(/,/, $trkdata); # extract track data into an array, splitting on whitespace
	$time=shift(@track_data);
	$temp=shift(@track_data); # units K
	$rho=pop(@track_data); # units kg/m^3
	$wdot=pop(@track_data);
	$pressure=pop(@track_data); # units Pa

	# Everything else in track_data is now a species
	my @speciesMassFracs=@track_data;

	my $speciesIndex=0;
	my $speciesMolFrac;

	my @speciesMolFracs=();
	my @speciesMolConcs=();

	foreach $massFrac (@speciesMassFracs)
	  {
	    $species=$speciesNames[$speciesIndex];

	    #$mol_weight{$species} # units kg/mol
	    #rho # units kg/m^3
	    my $scaleFactor=1.0e6; # convert from m^3 to cm^3
	    #push(@speciesMolConcs, $rho*$massFrac/($mol_weight{$species}*$scaleFactor)); # units mol/cm^3
	    push(@speciesMolConcs, $rho*$massFrac*$scaleFactor); # units mol/cm^3

	    $speciesIndex++;

	  }

	my $totalMolConc = eval join '+', @speciesMolConcs;

	my @speciesMolFracs=();

	foreach $molConc (@speciesMolConcs)
	  {
	    push(@speciesMolFracs, $molConc/$totalMolConc);
	  }

	## Mol fractions
	my $molfracs=join("\t",@speciesMolFracs); # Construct field of species mol fractions
	print MOLOUTFILE $time, "\t", $temp, "\t", $molfracs, "\t", $pressure, "\t", $wdot, "\n";

	## Mol concentrations
	my $molconcs=join("\t",@speciesMolFracs); # Construct field of species mol fractions
	print CONCOUTFILE $time, "\t", $temp, "\t", $molconcs, "\t", $pressure, "\t", $wdot, "\n";

	# Output time intervals - the steps possibly need to be changed based on the local conc gradient, but keep them fixed for now
	my $steps=1;
	my $splits=10;
	print TIMEFILE "<time steps=\"",$steps,"\" splits=\"",$splits,"\">",$time,"</time>\n";


      }

    close(CONCOUTFILE);
    close(MOLOUTFILE);
    close(TRKFILE);
    close(TIMEFILE);
  }

close(DIR);

print "Done!\n";
