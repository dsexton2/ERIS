#!/usr/bin/perl -w

use strict;

my $inFile = $ARGV[0];
open(inFP,"<$inFile");

my $inRoot = '';
if ($inFile =~ /(\S+)\.Genome_Wide_SNP_6\.sdrf\.txt/) {
  $inRoot = $1;
} else {
  print STDERR "ERROR::Incorrect input file type -- must be *.Genome_Wide_SNP_6.sdrf.txt\n";
}

my $ouFile = $inRoot.".sample_ID.txt";
open(ouFP,">$ouFile");

while (<inFP>) {
  chomp($_);
  my $current_line = $_;

  my @data = split(/\t/,$current_line);
  my $a = $data[0];

  ### print "$data[25]\t$data[26]\t$data[27]\t$data[28]\t$data[29]\n";

  if($a =~/^(.*?)\-(.*?)\-(.*?)\-(\d+)(\D)\-(.*?)\-(.*?)\-(.*?)$/) {
    my @b=split(/_/,$data[27]);
    print ouFP "$data[27]\t$b[0]\_$a";
    if($4 eq "01"){ 
      print ouFP "\_T\n";
    } else {
      print ouFP "\_N\n";
    }
  }
}

print STDERR "SUCCESS::Converted $inFile to $ouFile\n";
