#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;
use Carp;
use IO::File;
use Test::More qw( no_plan );

use_ok('Concordance::Birdseed::Conversion::Partek');

my $partek_converter = Concordance::Birdseed::Conversion::Partek->new(
    probelist_file => 
"/users/p-qc/dev_concordance_pipeline/Concordance/Birdseed/Conversion/t/partek_probes",
    partek_file => 
"/users/p-qc/dev_concordance_pipeline/Concordance/Birdseed/Conversion/t/partek.txt",
    "birdseed_dir" => ".",
);

isa_ok($partek_converter, "Concordance::Birdseed::Conversion::Partek");

my $partek_sample = IO::File->new($partek_converter->partek_file, "<")
    or croak "Failed to open partek.txt: $!";

my $header_line = <$partek_sample>;

my $partek_line = <$partek_sample>;

undef $partek_sample;

can_ok($partek_converter, q(parse_partek_line_into_hashref) );

my $data_hashref = {};

$partek_converter->parse_partek_line_into_hashref($data_hashref, $partek_line);

is (keys %$data_hashref, 1, "hash should have one record");
is([keys %$data_hashref]->[0], "rs6576700", "RS ID should be rs6576700");
is($data_hashref->{rs6576700}->{chromosome}, "1", "expected chromosome 1");
is(
    $data_hashref->{rs6576700}->{map_location},
    "84875173",
    "expected map location 84875173"
);
is($data_hashref->{rs6576700}->{ref_allele}, "A", "expected ref allele A");
is($data_hashref->{rs6576700}->{var_allele}, "G", "expected var allele G");

my @genotypes = qw(
    AA  AB  AB  AB  AA  AB  AA  AB  BB  AA  AA  AB  AB  AB  AB  AB  AA  BB
    AB  BB  BB  AB  BB  AB  AB  AB  AB  AA  AA  BB  AA  AB  AB  AA  AA  AA
    AA  AB  BB  AA  AA  AB  AB  AB  BB  AB  AB  AB  AB  AB  AA  AB  AA  BB
    BB  BB
);

grep {
        $_ =~ s/A/A/g;
        $_ =~ s/B/G/g;
} @genotypes;

my $returned_genotypes = $data_hashref->{rs6576700}->{genotypes_arrayref};

for my $i (0..$#genotypes) {
    is(
        $returned_genotypes->[$i],
        $genotypes[$i],
        "Expected $genotypes[$i] at index $i"
    );
}

can_ok($partek_converter, q(_translate_ab_alleles));

my ($ref_allele, $var_allele, $genotypes_arrayref)
    = ("C", "T", ["AA", "AB", "BA", "BB"]);
$partek_converter->_translate_ab_alleles(
    \$ref_allele, \$var_allele, $genotypes_arrayref);
is($genotypes_arrayref->[0], "CC", "AA => CC");
is($genotypes_arrayref->[1], "CT", "AB => CT");
is($genotypes_arrayref->[2], "TC", "BA => TC");
is($genotypes_arrayref->[3], "TT", "BB => TT");

can_ok($partek_converter, q(align_genotypes_with_probelist) );
$partek_converter->align_genotypes_with_probelist($data_hashref);

can_ok($partek_converter, q(get_array_ref_of_samples) );

my $samples_arrayref = $partek_converter->get_array_ref_of_samples(
    \$header_line);

is ( defined @$samples_arrayref , 1, "samples array should be defined");

is ( $samples_arrayref->[0], 'hus001-snp6.birdseed-v2.chp',
    "First sample name should be hus001-snp6.birdseed-v2.chp");

can_ok($partek_converter, q(write_birdseed_files) );

$partek_converter->write_birdseed_files($samples_arrayref, $data_hashref);
