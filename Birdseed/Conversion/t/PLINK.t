use warnings;
use strict;
use diagnostics;
use Concordance::Birdseed::Conversion::PLINK;
use Data::Dumper;
use Test::More qw( no_plan );

use_ok( 'Concordance::Birdseed::Conversion::PLINK' );

my $obj = Concordance::Birdseed::Conversion::PLINK->new (
    probelist_path => "/users/p-qc/dev_concordance_pipeline/Concordance/Birdseed/Conversion/t/probes",
    tfam_file =>
"/users/p-qc/dev_concordance_pipeline/Concordance/Birdseed/Conversion/t/eg_tfam",
    tped_file =>
"/users/p-qc/dev_concordance_pipeline/Concordance/Birdseed/Conversion/t/eg_tped",
);
##############################################################################
##########################  test valid tfam lines ############################
##############################################################################

my @valid_tfam_lines = (
    "911901588 911901588 0 0 2 1",
    "911901604 911901604 0 0 2 1",
    "0 5310745133_R02C02 0 0 0 -9",
);

foreach my $valid_tfam_line (@valid_tfam_lines) {
    is( $obj->is_valid_tfam_line(\$valid_tfam_line),
        1,
        "$valid_tfam_line is a valid .tfam line"
    );
}

my @invalid_tfam_lines = (
    "911901588 911901588 0 0 2 ",
    "911901604 911901604 0 0 2 1 2 1",
    "",
);

foreach my $invalid_tfam_line (@invalid_tfam_lines) {
    is( $obj->is_valid_tfam_line(\$invalid_tfam_line),
        '',
        "$invalid_tfam_line is an invalid .tfam line"
    );
}


##############################################################################
##########################  test valid tped lines ############################
##############################################################################

my @valid_tped_lines = (
    "16 rs7205107 0 48138708 3 3 1 3 3 3 1 3 3 3 3 3 3 3 1 3 3 3 3 3 3 3 3 3 3
3 3 3 3 3",
    "16 rs7205107 0 48138708 3 3",
    "16 rs7205107 0 48138708 A G",
);

foreach my $valid_tped_line (@valid_tped_lines) {
    is( $obj->is_valid_tped_line(\$valid_tped_line),
        1,
        "$valid_tped_line is a valid .tped line"
    );
}

my @invalid_tped_lines = (
    "16 rs7205107 0 48138708 3",
    "16 rs7205107 0 48138708 5 6",
    "16 rs7205107 0 48138708 3 1 4",
    "16 rs7205107 0 48138708 A",
    "16 rs7205107 0 48138708 A G C",
    "16 rs7205107 0 48138708 Z X T W",
    "",
);

foreach my $invalid_tped_line (@invalid_tped_lines) {
    is( $obj->is_valid_tped_line(\$invalid_tped_line),
        '',
        "$invalid_tped_line is an invalid .tped line"
    );
}

##############################################################################
########################  test reading in probelist ##########################
##############################################################################

my $tped_values_ref = {};

$obj->read_probelist_into_hashref($tped_values_ref);

is( $tped_values_ref->{rs7205107}->{pl_chr}, "16", "probe chr is 16" );
is( $tped_values_ref->{rs7205107}->{pl_chr_pos}, "49581207",
    "probe pos is 49581207" );
is( $tped_values_ref->{rs7205107}->{ref_allele}, "G", "probe ref is G" );
is( $tped_values_ref->{rs7205107}->{var_allele}, "A", "probe var is A" );

##############################################################################
########################  test reading in tped file ##########################
##############################################################################

my $tped_line = "16 rs7205107 0 48138708 3 3 1 3 3 3 1 3 3 3 3 3 3 3 1 3 3 3 3 3 3 3 3
3 2 4";

$obj->parse_tped_line_into_hashref(\$tped_line, $tped_values_ref);

is( $tped_values_ref->{rs7205107}->{chromosome}, "16", "chromosome is 16" );
is( $tped_values_ref->{rs7205107}->{map_location}, "48138708", "mapLoc is 48138708" );
my $genotypes_ref = $tped_values_ref->{rs7205107}->{genotypes_ref};

my @genotypes = split /\s/, "GG AG GG AG GG GG GG AG GG GG GG GG CT";

foreach my $genotype (@$genotypes_ref) {
    my $expected_genotype = shift @genotypes;
    is( $genotype, $expected_genotype, 
        "Found expected genotype $expected_genotype");
}

##############################################################################
####################  test translating numeric alleles #######################
##############################################################################

my $numeric_alleles = ();
@$numeric_alleles = qw(33 13 33 13 33 33 33 13 33 33 33 33 33 33 33);

$obj->_translate_numeric_allele_to_letter($numeric_alleles),

my @converted_genotypes = split /\s/, "GG AG GG AG GG GG GG AG GG GG GG GG GG
GG GG";

while (@$numeric_alleles) {
    my $expected_genotype = shift @converted_genotypes;
    is(shift @$numeric_alleles, $expected_genotype,
        "received $expected_genotype");
}

##############################################################################
################# test aligning genotypes with probelist #####################
##############################################################################

$obj->align_tped_alleles_with_probelist($tped_values_ref);

$genotypes_ref = $tped_values_ref->{rs7205107}->{genotypes_ref};

@genotypes = split /\s/, "GG AG GG AG GG GG GG AG GG GG GG GG GA";

foreach my $genotype (@{ $tped_values_ref->{rs7205107}->{genotypes_ref} }) {
    my $expected_genotype = shift @genotypes;
    is( $genotype, $expected_genotype, 
        "Found expected genotype $expected_genotype");
}
