#!/usr/bin/perl

package Concordance::Birdseed2Csv;

use strict;
use warnings;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{path} = undef;
	bless($self);
	return $self;
}

sub path {
	my $self = shift;
	if (@_) { $self->{path} = shift; }
	return $self->{path}; #[^\0]+
}

sub execute {
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

1;

=head1 NAME

Concordance::Birdseed2Csv - writes specific information from .birdseed
files to a CSV

=head1 SYNOPSIS

 my $birdseed = Concordance::Birdseed2Csv->new;
 $birdseed->path("/foo/bar");
 $birdseed->generate_csv;

=head1 DESCRIPTION

=head2 Methods

=over 12

=item C<new>

Returns a new Concordance::Birdseed2Csv object.

=item C<path>

Gets and sets the path containing the .birdseed.txt files.

=item C<generate_csv>

Iterates on the .birdseed.txt files in the directory set in C<path> and
prints output to a file with the same name and .csv appended to it.

=back

=head1 LICENSE

This script is the property of Baylor College of Medecine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
