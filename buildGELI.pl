#! /usr/bin/perl -w

=head1 NAME

buildGELI

=head1 SYNOPSIS

perl buildGELI.pl

=head1 DESCRIPTION

This script converts all .birdseed.data.txt files in the target directory into .bs, using .geli as an intermediate format.  It does this by calling two JARs, which each accomplish one of the conversions.

=head1 LICENSE

This script is the property of Baylor College of Medicine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut

use strict;
use Config::General;
use Log::Log4perl;

my %config = new Config::General("tertiary_pipeline.cfg")->getall;

Log::Log4perl->init("log4perl.cfg");
my $errorLog = Log::Log4perl->get_logger("errorLogger");
my $debugLog = Log::Log4perl->get_logger("debugLogger");

my @files = glob("*.birdseed.data.txt");
my $size = @files;

if ($size == 0) { $errorLog->error("no *.birdseed.data.txt files found in local directory\n"); exit; }

my $cmd = '';
foreach my $file (@files) {
  # covert cancer birdseed data files to geli format
  $cmd = $config{"java"}." -jar ".$config{"CancerBirdseedSNPsToGeliJAR"}.
	" I=$file".
	" S=".$config{"SAMPLE"}.
	" SNP60_DEFINITION=".$config{"SNP60_DEFINITION"}.
	" SD=".$config{"SEQUENCE_DICTIONARY"}.
	" R=".$config{"REFERENCE"}.
	" O=$file.geli";
  $debugLog->debug("building .geli for $file\n");
  $debugLog->debug("$cmd\n");
  system("$cmd");

  # build bs file from geli
  $cmd = $config{"java"}." -jar ".$config{"GeliToTextExtendedJAR"}.
	" OUTPUT_LIKELIHOODS=".$config{"OUTPUT_LIKELIHOODS"}.
	" I=$file.geli".
	" >& ".
	" $file.bs";
  $debugLog->debug("building .bs for $file\n");
  $debugLog->debug("$cmd\n");
  system("$cmd");
}
