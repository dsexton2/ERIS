#!/usr/bin/perl

package Concordance::Birdseed2Csv;

use strict;
use warnings;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{PATH} = undef;
	bless($self);
	return $self;
}

sub path {
	my $self = shift;
	if (@_) { $self->{PATH} = shift; }
	return $self->{PATH};
}

sub generate_csv {
	my $self = shift;
	my @files = glob($self->path."*.birdseed.txt");
	my $OUT_CUT = 10;
	
	my %concordance;
	my %all;
	my $out_num=0;
	my $redo=0;
	my $out = '';
	
	foreach my $file (@files) {
		open(FIN,"$file");
		open(FOUT, ">$file.csv");
		$file =~ /^.*\/(.*?)\.birdseed\.txt$/;
		my $name = $1;
	
		### output sample ID from birdseed
		print FOUT "$name";
	
		my $one=""; my $one_num=-1;
		my $self=""; my $couple="";
		my $average=0; my $num=0;
		my %concordance=(); my %all=();
	
		while(<FIN>) {
			chomp;
			if ($_ =~ /\//) {
				$error_log->error("$file is an angry birdseed file!!\n");
				last;
			} 
			my @a=split(/\s+/);
			$concordance{$a[0]}=$a[8];
			$all{$a[0]}=$_;
	
			$average += $a[8];
			$num++;
	
			if($a[8] > $one_num) {
				$one_num=$a[8];
				$one=$_;
			}
	
		}
	
		$average = $average / $num;
		print FOUT ",$average";
	
		$out_num=0;
		foreach my $key (sort { $concordance{$b} <=> $concordance{$a} } (keys(%concordance))) {
			print FOUT ",$concordance{$key},$key";
			$out_num++;
			if ($out_num >= $OUT_CUT) { last; }
		}
		print FOUT "\n";
		close(FIN);	
		close(FOUT);
	} 
}
