#! /usr/bin/perl -w

use strict;
use Log::Log4perl;

Log::Log4perl->init("log4perl.cfg");
my $errorLog = Log::Log4perl->get_logger("errorLogger");
my $debugLog = Log::Log4perl->get_logger("debugLogger");

my @files = glob("*.birdseed.data.txt");
my $size = @files;

if ($size == 0) { $errorLog->error("no *.birdseed.data.txt files found in local directory\n"); exit; }

my $cmd = '';
foreach my $file (@files) {
  # covert cancer birdseed data files to geli format
  $cmd = "/users/bainbrid/bin/java -jar /stornext/snfs0/next-gen/yw14-scratch/Birdseed_converter/CancerBirdseedSNPsToGeli.jar I=$file S=TCGA-sample SNP60_DEFINITION=/stornext/snfs0/next-gen/yw14-scratch/Birdseed_converter/GenomeWideSNP_6.na26.1.annot.csv SD=/stornext/snfs0/next-gen/yw14-scratch/Birdseed_converter/Homo_sapiens_assembly18.dict R=/stornext/snfs0/next-gen/yw14-scratch/Birdseed_converter/Homo_sapiens_assembly18.fasta O=$file.geli";
  #print "building .geli for $file\n";
  $debugLog->debug("building .geli for $file\n");
  #print "$cmd\n";
  $debugLog->debug("$cmd\n");
  system("$cmd");

  # build bs file from geli
  $cmd = "/users/bainbrid/bin/java -jar /stornext/snfs0/next-gen/yw14-scratch/Birdseed_converter/GeliToTextExtended.jar OUTPUT_LIKELIHOODS=False I=$file.geli >& $file.bs";
  #print "building .bs for $file\n";
  $debugLog->debug("building .bs for $file\n");
  $debugLog->debug("$cmd\n");
  #print "$cmd\n";
  system("$cmd");
}
