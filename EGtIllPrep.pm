#!/usr/bin/perl -w

package Concordance::EGtIllPrep;

use strict;
use warnings;
use Log::Log4perl;

# /stornext/snfs0/next-gen/Illumina/Instruments/700738/110330_SN738_0062_AB05LKABXX/Data/Intensities/BaseCalls/GERALD_09-04-2011_p-illumina.8
# /stornext/snfs5/next-gen/Illumina/Instruments/700166/100818_SN166_0135_A20AA7ABXX/mini_analysis/lane7

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}



my $inFile = $ARGV[0];
open(inFP,"<$inFile");
while (<inFP>) {
  chomp($_);
  my $current_line = $_;

  my @data = split(/[,\s]/,$current_line);
  my $NAME = $data[0];
  my $PATH = $data[1];
#  print "\n$data[0]\n";  
$debug_log->debug("data[0]: ",$data[0],"\n");
chomp($PATH);

  my @dirs = split(/\//,$PATH);
  my $instrument = $dirs[6];

  my @fcra = split(/_/,$dirs[7]);
  my $flowcell = $fcra[3];

  my $SE = '';
  my $analysis_number = 0;
  if ($PATH =~ /Demultiplexed/) {
    my $barcode = $dirs[12];
    $dirs[13] =~ /(\d+)$/;
    $analysis_number = $1; 
    #my @grld = split(/\./,$dirs[13]);
    #$analysis_number = $grld[1];
    if ($analysis_number eq '') { $analysis_number = 1; }    
    $SE = "${flowcell}_${barcode}_${analysis_number}";
  } else {
    if ($dirs[11] =~ /GERALD/) {
      my @grld = split(/\./,$dirs[11]);
      $analysis_number = $grld[1];
    } elsif ($dirs[9] =~ /lane(\d+)/) {
      $analysis_number = $1;
    }
    if ($analysis_number eq '') { $analysis_number = 1; }
    $SE = "${flowcell}_${analysis_number}";
  }

  ### print "\n|${PATH}|\n";
  ### print ":${NAME}_${SE}:\n";

  my @files = `ls $PATH/*sequence.txt.bz2`;

  if ($files[0] ne '') {
    #print "${NAME}_${SE}";
    $debug_log->debug("{NAME}_${SE}:${NAME}_${SE}\n");
    foreach my $fastq (@files) {
      chomp($fastq);
      #print "\t$fastq";
      $debug_log->debug("fastq:\s",$fastq,"\n");
    }
    #print "\n";
  } else {
    #print STDERR "ERROR :: $PATH/*sequence.txt.bz2 not found for ${NAME}_${SE}\n";
    $error_log->error("$PATH/*sequence.txt.bz2 not found for ${NAME}_${SE}\n");
  }
}
