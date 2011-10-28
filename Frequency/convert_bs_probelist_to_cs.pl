#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;

if (scalar @ARGV != 2) { die "usage: convert_bs_probelist_to_cs.pl /path/to/probelist /path/to/output\n" }

my $bs_probe_file = $ARGV[0];
my $cs_probe_file = $ARGV[1];


open(FOUT, ">".$cs_probe_file) or die $!;
open(FIN, $bs_probe_file) or die $!;

my @indices_of_interest = qw(0 1 2 3 4 5 6 7 8);

my %bs_to_cs = ( 
	'AA' => '0', 'AC' => '1', 'AG' => '2', 'AT' => '3',
	'CA' => '1', 'CC' => '0', 'CG' => '3', 'CT' => '2',
	'GA' => '2', 'GC' => '3', 'GG' => '0', 'GT' => '1',
	'TA' => '3', 'TC' => '2', 'TG' => '1', 'TT' => '0',
	'AN' => '.', 'GN' => '.', 'TN' => '.', 'CN' => '.',
	'NN' => '.', 'NA' => '3', 'NC' => '2', 'NG' => '1',
	'NT' => '0'
);

while(my $line = <FIN>) {
	chomp($line);

	my @probe_with_cs_vals = add_colorspace_values($line);
	my $cs_probe_line = "";

	foreach my $index (@indices_of_interest) {
		$cs_probe_line .= $probe_with_cs_vals[$index]."\t";
	}
	$cs_probe_line =~ s/\t$/\n/;

	print FOUT $cs_probe_line;
}

close(FIN);
close(FOUT);



sub sequence_to_colorspace {
	my @sequence_space = split(//, shift);
	my @color_space = ();
	for (my $i = 0; $i < scalar @sequence_space - 2; $i++) {
		if (!exists $bs_to_cs{$sequence_space[$i].$sequence_space[$i+1]}) {
			push @color_space, ".";	
		}
		else {
			push @color_space, $bs_to_cs{$sequence_space[$i].$sequence_space[$i+1]};
		}
	}
	return join('', @color_space);

}

sub add_colorspace_values {
	my @vals = split(/\t/, shift);

	my $chromosome = $vals[0];
	my $mapLoc = $vals[1];
	my $rsId = $vals[2];
	my $seq5 = $vals[3];
	my $seq3 = $vals[4];
	my $ref_allele = $vals[5];
	my $var_allele = $vals[6];
	my $major_homo = $vals[7];
	my $hetero = $vals[8];
	my $minor_homo = $vals[9];

	my $cs_seq5_ref_seq3 = sequence_to_colorspace($seq5.$ref_allele.$seq3);
	my $cs_seq5_var_seq3 = sequence_to_colorspace($seq5.$var_allele.$seq3);

	my $cs_seq5 = substr($cs_seq5_ref_seq3, 3, 11);
	my $cs_seq3 = substr($cs_seq5_ref_seq3, 16, 11);
	my $cs_ref_allele = substr($cs_seq5_ref_seq3, 14, 2);
	my $cs_var_allele = substr($cs_seq5_var_seq3, 14, 2);

	my @cs_vals = ($chromosome, $mapLoc, $rsId, $cs_seq5, $cs_seq3,
		$ref_allele, $var_allele, $cs_ref_allele, $cs_var_allele,
		$major_homo, $hetero, $minor_homo);
	return @cs_vals;
}
