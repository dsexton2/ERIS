#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;
use Test::More qw( no_plan );

use_ok('Concordance::Probes::Reader');

my $probe_reader = Concordance::Probes::Reader->new(
    probelist_file =>
"/users/p-qc/dev_concordance_pipeline/Concordance/Probes/t/partek_probes",
);

isa_ok($probe_reader, 'Concordance::Probes::Reader');

can_ok( $probe_reader, q(read_probelist_into_hashref) );

my $probe_hashref = {};

isa_ok($probe_hashref, 'HASH');

$probe_reader->read_probelist_into_hashref($probe_hashref);

# 1 84875173    rs6576700   AAAATACTCTGCAAG GCAATAAAATGTATC C   T
is(keys %$probe_hashref, 1, "hash should have one record");
is([keys %$probe_hashref]->[0], "rs6576700", "RS ID should be rs6576700");
is($probe_hashref->{rs6576700}->{pl_chromosome}, "1", "expected chromosome 1");
is(
    $probe_hashref->{rs6576700}->{pl_map_location},
    "84875173",
    "expected map location 84875173"
);
is($probe_hashref->{rs6576700}->{pl_ref_allele}, "C", "expected ref allele A");
is($probe_hashref->{rs6576700}->{pl_var_allele}, "T", "expected var allele G");

can_ok( $probe_reader, q(align_allele_and_genotype_with_probelist) );


# (G A GA) + (G A) = (G GA)
my ($ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var)
    = ("G", "A", ["GA"], "G", "A");
$probe_reader->align_allele_and_genotype_with_probelist
    (
        \$ref_allele,
        \$var_allele,
        $genotypes_arrayref,
        \$pl_ref,
        \$pl_var,
    );
is($ref_allele, "G", "ref allele should be G");
is($genotypes_arrayref->[0], "GA", "genotype should be GA");

# (G A GA) + (A G) = (A AG)
($ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var)
    = ("G", "A", ["GA"], "A", "G");
$probe_reader->align_allele_and_genotype_with_probelist
    (
        \$ref_allele,
        \$var_allele,
        $genotypes_arrayref,
        \$pl_ref,
        \$pl_var,
    );
is($ref_allele, "A", "ref allele should be A");
is($genotypes_arrayref->[0], "AG", "genotype should be AG");

# (G A GA) + (C T) = (C CT)
($ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var)
    = ("G", "A", ["GA"], "C", "T");
$probe_reader->align_allele_and_genotype_with_probelist
    (
        \$ref_allele,
        \$var_allele,
        $genotypes_arrayref,
        \$pl_ref,
        \$pl_var,
    );
is($ref_allele, "C", "ref allele should be C");
is($genotypes_arrayref->[0], "CT", "genotype should be CT");


# (G A GA) + (T C) = (T TC)

($ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var)
    = ("G", "A", ["GA"], "T", "C");
$probe_reader->align_allele_and_genotype_with_probelist
    (
        \$ref_allele,
        \$var_allele,
        $genotypes_arrayref,
        \$pl_ref,
        \$pl_var,
    );
is($ref_allele, "T", "ref allele should be T");
is($genotypes_arrayref->[0], "TC", "genotype should be TC");


