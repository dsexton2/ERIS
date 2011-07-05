#! /usr/bin/perl -w

use strict;
use Log::Log4perl;

Log::Log4perl->init("log4perl.cfg");

my $errorLog = Log::Log4perl->get_logger("errorLogger");
my $debugLog = Log::Log4perl->get_logger("debugLogger");
print @ARGV;
my $e_geno_list=$ARGV[0];
my $SNP_array=$ARGV[1];
if ($SNP_array eq '') {
  #print STDERR "ERROR :: You must specify a project directory containing the *.birdseed files!\n";
  $errorLog->error("You must specify a project directory containing the *.birdseed files!\n");
  exit;
}

open(FIN,"$e_geno_list");
my $i=1;
my @com_array;
while(<FIN>)
{
  chomp;
  my @a=split(/\s+/);
  my $size=@a;
  my  $temp=$a[0];
  for (my $j=1;$j<$size;$j++) { $temp .= "#".$a[$j]; }
  
  my $command = "bsub -e $i.e -o $i.o -J $i-eGT-$SNP_array \"/stornext/snfs0/next-gen/concordance_analysis/e-Genotyping_concordance_Illumina.pl $temp $SNP_array\"\;";
  $com_array[$i] = $command;
  $i++;

  #print "$command\n";
  $debugLog->debug("executing command: $command\n");
  #system("$command");
  sleep(2);
}
close(FIN);
