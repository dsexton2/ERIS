package Concordance::Probes::Reader;

use strict;
use warnings;

use Carp;
use English qw( -no_match_vars );
use IO::File;
use Moose;
use Moose::Util::TypeConstraints;
use Readonly;
use Regexp::DefaultFlags;

subtype 'Path',
    as 'Str',
    where { -e $_ },
    message { "$_ is not a valid path or does not exist" };

has 'probelist_file' => (
    is => 'rw',
    isa => 'Path',
    required => 1,
    documentation => 'Full path to the probelist file',
);

sub read_probelist_into_hashref {
    my ($self, $probes_ref) = @_;

    my Readonly $FIELD_SEPARATOR = qr{\s+};
    my Readonly $FIELD_COUNT = 10;

    my $probe_file = IO::File->new($self->probelist_file, "<")
        or croak "Can't open for reading '$self->probelist_file': $OS_ERROR";

    while (my $probe_line = <$probe_file>) {

        chomp $probe_line;

        my @probe_cols = split $FIELD_SEPARATOR, $probe_line, $FIELD_COUNT+1;

        @{ $probes_ref->{$probe_cols[2]} }
            {'pl_chromosome', 'pl_map_location',
                'pl_ref_allele', 'pl_var_allele'}
            = @probe_cols[0, 1, 5, 6];
    }
}

sub align_allele_and_genotype_with_probelist {
    my ($self, $ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var) = @_;

    # N.B. - all vars passed in are REFs

    foreach my $genotype (@$genotypes_arrayref) {

        my ($comp_ref_allele, $comp_var_allele, $comp_genotype)
            = ($$ref_allele, $$var_allele, $genotype);
        grep { $_ =~ tr/AGCT/TCGA/ }
            ($comp_ref_allele, $comp_var_allele, $comp_genotype);

        if ($$ref_allele =~ m{\A$$pl_ref\z}) {
            # do nothing; this is here to spell out logic
        }
        elsif ($$ref_allele =~ m{\A$$pl_var\z}) {
            $$ref_allele = $$var_allele;
            $genotype = reverse $genotype;
        }
        elsif ($comp_ref_allele =~ m{\A$$pl_ref\z}) {
            $$ref_allele = $comp_ref_allele;
            $genotype = $comp_genotype;
        }
        elsif ($comp_ref_allele =~ m{\A$$pl_var\z}) {
            $$ref_allele = $comp_var_allele;
            $genotype = reverse $comp_genotype;
        }
    }

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
