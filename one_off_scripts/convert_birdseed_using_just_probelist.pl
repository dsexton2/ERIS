#!/hgsc_software/perl/latest/bin

use strict;
use warnings;
use diagnostics;

use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
	\%options,
	'birdseed-file=s',
	'old-probelist-path=s',
	'new-probelist-path=s',
	'help|?',
	'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

if (!-e $options{'birdseed-file'}) { die "birdseed-file DNE: ".$options{'birdseed-dir'}."\n" }
if (!-e $options{'old-probelist-path'}) { die "probelist-file DNE: ".$options{'old-probelist-path'}."\n" }
if (!-e $options{'new-probelist-path'}) { die "probelist-file DNE: ".$options{'new-probelist-path'}."\n" }

my $data = {};
my $old_chr_maploc_to_rsid = {};

open(FIN_OLD_PROBELIST, "<".$options{'old-probelist-path'}) or die $!;
while (<FIN_OLD_PROBELIST>) {
	chomp;
	my @vals_by_col = split(/\t/);
	$data->{$vals_by_col[2]}->{old_pl_chr} = $vals_by_col[0];
	$data->{$vals_by_col[2]}->{old_pl_chr_pos} = $vals_by_col[1];
	$old_chr_maploc_to_rsid->{$vals_by_col[0]."_".$vals_by_col[1]} = $vals_by_col[2];
}
close(FIN_OLD_PROBELIST) or warn $!;

open(FIN_NEW_PROBELIST, "<".$options{'new-probelist-path'}) or die $!;
while (<FIN_NEW_PROBELIST>) {
	chomp;
	my @vals_by_col = split(/\t/);
	$data->{$vals_by_col[2]}->{new_pl_chr} = $vals_by_col[0];
	$data->{$vals_by_col[2]}->{new_pl_chr_pos} = $vals_by_col[1];
	$data->{$vals_by_col[2]}->{ref_allele} = $vals_by_col[5];
}
close(FIN_NEW_PROBELIST) or warn $!;

open(FIN_BIRDSEED, "<".$options{'birdseed-file'}) or die $!;
open(FOUT_CONV_BIRDSEED, ">".$options{'birdseed-file'}.".conv_hg19+.birdseed") or die $!;
my $bad_count = 0;
while (<FIN_BIRDSEED>) {
	chomp;
	my @vals_by_col = split(/\t/);
	(my $bs_chr = $vals_by_col[0]) =~ s/chr//;
	my $map_loc = $vals_by_col[1];
	my $bs_ref_allele = $vals_by_col[2];
	(my $rev_comp_bs_ref_allele = $bs_ref_allele) =~ tr/acgtACGT/tgcaTGCA/;
	my $genotype_call = $vals_by_col[3];
	(my $rev_comp_genotype_call = $genotype_call) =~ tr/acgtACGT/tgcaTGCA/;
	my $target_rsid = $old_chr_maploc_to_rsid->{$bs_chr."_".$map_loc};


	if (!defined($target_rsid)) { $bad_count++; next; }

	if (defined($data->{$target_rsid})) {
		if ($bs_ref_allele = $data->{$target_rsid}->{ref_allele}) {
			print FOUT_CONV_BIRDSEED $data->{$target_rsid}->{new_pl_chr}."\t".
				$data->{$target_rsid}->{new_pl_chr_pos}."\t".
				$bs_ref_allele."\t".
				$genotype_call."\n";
		}
		elsif ($rev_comp_bs_ref_allele = $data->{$target_rsid}->{ref_allele}) {
			print FOUT_CONV_BIRDSEED $data->{$target_rsid}->{new_pl_chr}."\t".
				$data->{$target_rsid}->{new_pl_chr_pos}."\t".
				$rev_comp_bs_ref_allele."\t".
				$rev_comp_genotype_call."\n";
		}
	}
}
close(FIN_BIRDSEED) or warn $!;
close(FOUT_CONV_BIRDSEED) or warn $!;

print STDERR $bad_count."\n";

=head1 NAME

B<convert_birdseed_using_just_probelist.pl> - convert birdseeds from hg18 to hg19 (or reverse)

=head1 SYNOPSIS

convert_birdseed_using_just_probelist.pl --birdseed-file=/path/to/bs/to/convert --old-probelist-path=/path/to/old/probelist --new-probelist-path=/path/to/new/probelist

Options:

 --birdseed-file	birdseed file to convert
 --old-probelist-path	path to the old probelist used to look up rsID via chr & map_loc
 --new-probelist-path	path to new probelist to get new chr & map_loc and check strandedness
 --help|?	display help
 --man	display man

=head1 OPTIONS

=over 8

=item B<--birdseed-file>

The path to the birdseed file to convert.

=item B<--old-probelist-path>

The path to the old probelist used to look up the rsID via the chromosome number and map location.

=item B<--new-probelist-path>

The path to the new probelist used to obtain the new chromosome and map location as well as to check the strandedness.

=item B<--help|?>

Prints a short help message concerning usage of this script.

=item B<--man>

Prints a man page containing detailed usage of this script.

=back

=head1 DESCRIPTION

B<convert_birdseed_using_just_probelist> takes a birdseed file and two probelists.  The birdseed files are already aligned against one probelist, and the second probelist is the one against which they should be aligned.  It also accounts for strandedness.  The result is a birdseed file aligned against the new probelist.

=head1 LICENSE

GPLv3

=head1 AUTHOR

John McAdams - (mcadams@bcm.edu)

=cut
