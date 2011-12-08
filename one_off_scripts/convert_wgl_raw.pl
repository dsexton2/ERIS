#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;
use File::Touch;

if (@ARGV != 2) {
	die "usage: convert_wgl_raw.pl /path/to/raw/birdseed/to/convert /path/to/probelist/";
}

my $wgl_raw_bs_file = $ARGV[0];
(my $output_file = $wgl_raw_bs_file) =~ s/(.*)\.txt/$1.birdseed.data.txt/;
my $probelist_file = $ARGV[1];

if (!-e $wgl_raw_bs_file) {
	die "DNE: $wgl_raw_bs_file\n";
}
if (!-e $probelist_file) {
	die "DNE: $probelist_file\n";
}
eval { touch($output_file) };
die $@ if $@;

# wgl_raw_bs_file example
# 509216	7	17554597	rs10242846	C	C	B	B	0.9210	0.8837	1.0000	0.1270
# probelist_file example
# 4	44135358	rs59361075	CTTTGCCATAACAAA	ACTGTACTACTTCAG	T	G	0	0	0 

# match the rs#s in the wgl_raw against those in the probelist
# grab the first two alleles from the wgl_raw as the genotype call
# grab the chromosome #, position #, and reference allele from the probelist
# print out converted raw birdseed in the format:
# chr	pos	ref	genotype_call

# a hash of rs# => genotype pairs
my %wgl_rawbs_data = ();

print "processing WGL raw birdseed file $wgl_raw_bs_file ... \n";
open(FIN_RAWBS, $wgl_raw_bs_file) or die $!;
while (<FIN_RAWBS>) {
	chomp;
	my @tabbed_columns = split(/\t/);
	if ($tabbed_columns[3] =~ m/^rs\d+$/ and $tabbed_columns[4].$tabbed_columns[5] ne "--") {
		$wgl_rawbs_data{$tabbed_columns[3]} = $tabbed_columns[4].$tabbed_columns[5];
	}
}
close(FIN_RAWBS) or warn $!;

print "matching against probelist $probelist_file ... \n";
open(FIN_PROBES, $probelist_file) or die $!;
open(FOUT, ">".$output_file) or die $!;
while (<FIN_PROBES>) {
	chomp;
	my @tabbed_columns = split(/\t/);
	if (defined($wgl_rawbs_data{$tabbed_columns[2]})) {
		print FOUT $tabbed_columns[0]."\t".
			$tabbed_columns[1]."\t".
			$tabbed_columns[5]."\t".
			$wgl_rawbs_data{$tabbed_columns[2]}."\n";
	}
}
close(FIN_PROBES) or warn $!;
close(FOUT) or warn $!;
