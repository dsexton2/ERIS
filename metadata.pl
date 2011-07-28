#! /usr/bin/perl -w

use strict;
use warnings;

my @files = glob("*.pm");

open(FOUT, ">metadata.txt");

foreach my $file (@files) {
	open(FIN, $file);
	my @params = ();
	while (my $line = <FIN>) {
		chomp($line);
		if ($line =~ m/\$self->{(\w+)};$/) {
			push(@params, $1);
		}
	}
	close(FIN);
	if ($#params != -1) {
		$file =~ s/\.pm//;
		print FOUT $file."\n";
		foreach my $param (@params) {
			print FOUT "\t".$param."\n";
		}
	}
}

close(FOUT);

=head1 NAME

metadata.pl - script to extract class members from module source

=head1 SYNOPSIS

perl metadata.pl

=head1 DESCRIPTION

Run this script in the directory in which the source for the Perl
modules is located.  It will write to a file called 'metadata.txt' the
module name, followed by a tabbed list of class members for that
module.

=head1 LICENSE

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
