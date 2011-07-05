#! /usr/bin/perl -w

# FADGE_p_TCGA_b100_SNP_N_GenomeWideSNP_6_E07_747548.birdseed.data.txt	FADGE_TCGA-DD-A1EE-01A-11D-A12Y-01_T

use strict;

my $sample_id_file = $ARGV[0];
my $final_resting_place = $ARGV[1];

if ($sample_id_file !~ /\.sample_ID\.txt/) {
  print STDERR "ERROR :: sample ID file is not a *.sample_ID.txt file\n";
  exit;
}

if ($final_resting_place eq '') {
  print STDERR "ERROR :: must specify a final data directory\n";
  exit;
}

# build a hash of Broad IDs and the associated TCGA IDs
my %sdrf = ();
open (idFP,"<$sample_id_file");
while (<idFP>) {
  chomp($_);
  my @id = split(/[\.\t]/,$_);
  ### print "$id[0]\t$id[4]\n";
  $sdrf{$id[0]} = $id[4];  
}

my @files=glob("*.birdseed");
my $size = @files;
if ($size == 0) { print STDERR "ERROR :: no *.birdseed files found in local directory\n"; exit; }

foreach my $file (@files) {
  print "current file is: $file\n";
  $file =~ /(\S+)\.birdseed/;
  my $fileRoot = $1;
  print "mv $file /users/p-qc/SNP_array/$final_resting_place/$sdrf{$fileRoot}.birdseed\n";
  `mv $file /users/p-qc/SNP_array/$final_resting_place/$sdrf{$fileRoot}.birdseed`;
}
