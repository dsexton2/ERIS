use strict;
use warnings;
use diagnostics;
use Carp;

if (scalar @ARGV != 2) {
	croak "usage: perl calculateContamination.pl ".
	"/path/to/snp/birdseed/file ".
	"/comma-delimited,/path[s]/to/result/file[s] ".
	"\n";
}

my $snp_file = $ARGV[0];
my @result_files = split(/,/, $ARGV[1]);

if (!-e $snp_file) { croak "$snp_file DNE\n" }
foreach my $result_file (@result_files) {
	if (!-e $result_file) { croak "$result_file DNE\n" }
}

# need to read the snp array birdseed file, getting positions for calls that
# don't contain the reference allele

open(FIN_SNP_FILE, $snp_file);
while (my $snp_file_line = <FIN>) {
	chomp($snp_file_line);
	my @tab_delimited_line_values = split(/\t/, $snp_file_line);
	my $reference_allele = $tab_delimited_line_values[2];
	my $genotyping_call = $tab_delimited_linie_values[3];
	if ($genotyping_call !~ m/$reference_allele/) {
		# add to structure of things to check against results file
	}
}
close(FIN);

# now read the results file, check against the data from the SNP array
