#!/hgsc_software/perl/latest/bin/

use strict;
use warnings;
use diagnostics;

use Data::Dumper;
use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
    \%options,
    'birdseed-dir=s',
    'probelist-path=s',
    'rsId-list-path=s',
    'rsId-col=i',
    'help|?',
    'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

if (!-e $options{'birdseed-dir'}) { die "birdseed-dir DNE: ".$options{'birdseed-dir'}."\n" }
if (!-e $options{'probelist-path'}) { die "probelist-path DNE: ".$options{'probelist-path'}."\n" }
if (!-e $options{'rsId-list-path'}) { die "rsId-list-path DNE: ".$options{'rsId-list-path'}."\n" }
if ($options{'rsId-col'} !~ m/\d+/) { die "rsId-col NaN: ".$options{'rsId-list-path'}."\n" }

my $data = {};

open(FIN_PROBELIST, "<".$options{'probelist-path'}) or die $!;
# 12    71476367    rs11178591    CACCAACTTTGTTAA    TTTATTACTTCTAAT    A    G    0.708624708624708625    0.264957264957264957    0.026418026418026418
while(<FIN_PROBELIST>) {
    chomp;
    my @vals_by_col = split(/\t/);
    $data->{$vals_by_col[2]}->{pl_chr} = $vals_by_col[0];
    $data->{$vals_by_col[2]}->{pl_chr_pos} = $vals_by_col[1];
    $data->{$vals_by_col[2]}->{ref_allele} = $vals_by_col[5];
    $data->{$vals_by_col[2]}->{var_allele} = $vals_by_col[6];
}
close(FIN_PROBELIST);

open(FIN_RSIDLIST, "<".$options{'rsId-list-path'}) or die $!;
# 11    rs4127392    0    94010034
while (<FIN_RSIDLIST>) {
    chomp;
    my @vals_by_col = split(/\t/);
    $data->{$vals_by_col[$options{'rsId-col'}]}->{old_chr} = $vals_by_col[0];
    $data->{$vals_by_col[$options{'rsId-col'}]}->{old_chr_pos} = $vals_by_col[3];
}
close(FIN_RSIDLIST);

my @birdseed_files = glob($options{'birdseed-dir'}."/*.birdseed");
open(FOUT_ERR, ">>error") or die $!;
foreach my $birdseed_file (@birdseed_files) {
    open(FIN_BS, "<".$birdseed_file) or die $!;
    open(FOUT_CONV_BS, ">".$birdseed_file.".converted.birdseed") or die $!;
    while (<FIN_BS>) {
        chomp;
        # col0 = chr num, col1 = chr pos, col2 = allele, col3 = genotype call
        my @vals_by_col = split(/\t/);
        my $genotype_call = pop @vals_by_col;
        (my $comp_genotype_call = $genotype_call) =~ tr/agctAGCT/tcgaTCGA/;
        (my $chr, my $chr_pos, my $allele) =  @vals_by_col;
        $chr =~ s/chr//g;
        (my $comp_allele = $allele) =~ tr/agctAGCT/tcgaTCGA/;
        foreach my $value (values %$data) {
            if ($chr eq $value->{old_chr} and $chr_pos eq $value->{old_chr_pos}) {
                # find out, based on some arcane formulae, what allele and genotype call to write out
                if ($allele =~ m/[$value->{'ref_allele'}|$value->{'var_allele'}]/i
                    and $genotype_call =~ m/[$value->{'ref_allele'}|$value->{'var_allele'}]{2}/i) {
                    print FOUT_CONV_BS $value->{pl_chr}."\t".$value->{pl_chr_pos}."\t".$allele."\t".$genotype_call."\n";
                }
                elsif ($comp_allele =~ m/[$value->{'ref_allele'}|$value->{'var_allele'}]/i
                    and $comp_genotype_call =~ m/[$value->{'ref_allele'}|$value->{'var_allele'}]{2}/i) {
                    # the birdseed is complemented relative to the probelist; compl
                    print FOUT_CONV_BS $value->{pl_chr}."\t".$value->{pl_chr_pos}."\t".$comp_allele."\t".$comp_genotype_call."\n";
                }
                else {
                    # print out lots of happy time error info.  grab the rsId from the map file
                    my $cmd = "grep -wm1 $chr_pos ".$options{'rsId-list-path'};
                    my $rsId = `$cmd`;
                    $rsId =~ s/.*(rs\d+)\t.*/$1/;
                    print FOUT_ERR "rsId: $rsId $_\n";
                    print FOUT_ERR Dumper(\%$value)."\n";
                }
            }
        }
    }
    close(FOUT_CONV_BS) or warn $!;
    close(FIN_BS) or warn $!;
}
close(FOUT_ERR) or warn $!;

=head1 NAME

B<align_birdseed_with_probelist> - process birdseed files to align with a given probelist

=head1 SYNOPSIS

B<align_birdseed_with_probelist.pl> [--birdseed-dir=</path/to/birdseed/files>] [--probelist-path=</path/top/probelist>] [--rsId-list-path=</path/to/rsId/list>] [--rsId-col=<cardinal-zero-indexed-column-of-rsId>] [--man] [--help] [--?]

Options:

 --birdseed-dir        directory containing birdseed files
 --probelist-path    path to probelist
 --rsId-list-path    path to file containing rsIds
 --rsId-col            zero-indexed rsId column number
 --help|?            prints a brief help message
 --man                prints an extended help message

=head1 OPTIONS

=over 8

=item B<--birdseed-dir>

The path to the directory containing the *.birdseed files.

=item B<--probelist-path>

The path to the probelist file with which to align.

=item B<--rsId-list-path>

The path to the file containing the list of rs IDs.

=item B<--rsId-col>

The zero-indexed column of the rsId-list-path containing rsIds.

=item B<--help|?>

Prints a short help message concerning usage of this script.

=item B<--man>

Prints a man page containing detailed usage of this script.

=back

=head1 DESCRIPTION

B<align_birdseed_with_probelist> will align a group of birdseed files with a given probelist.

=over 12

=item 1. Generate probelist file using rsIDs from .map file, pulling lines with matching rsIDs from dbsnp/hg19 master probelist.

=item 2. Get data to match from all three files: 

=over 16

=item a. Match lines from .birdseed to .map using chromosome number and position.

=item b. Match the resulting lines to the probelist using rsIDs.

=back

=item 3. Do some kung fu on the allele and genotype data from the birdseed file against the reference and variant alleles in the probelist.

=back

=cut
