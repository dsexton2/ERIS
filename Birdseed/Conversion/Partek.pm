package Concordance::Birdseed::Conversion::Partek;

use strict;
use warnings;

use Carp;
use Concordance::Probes::Reader;
use English qw( -no_match_vars );
use IO::File;
use Moose;
use Moose::Util::TypeConstraints;
use Readonly;
use Regexp::Common;
use Regexp::DefaultFlags;

subtype 'Partek::Path',
    as 'Str',
    where { -e $_ },
    message { "$_ is not a valid path or does not exist" };

has 'probelist_file' => (
    is => 'rw',
    isa => 'Partek::Path',
    required => 1,
    documentation => 'Full path to the probelist file',
);

has 'partek_file' => (
    is => 'rw',
    isa => 'Partek::Path',
    required => 1,
    documentation => 'Full path to Partek file',
);

has 'birdseed_dir' => (
    is => 'rw',
    isa => 'Partek::Path',
    required => 1,
    documentation => 'Full path to converted birdseed destination',
);

sub parse_partek_line_into_hashref {
    my ($self, $partek_data_hashref, $partek_line) = @_;

    Readonly my $PARTEK_LINE_REGEX => qr{
        \A                  # start of string
        SNP[\w\d_-]+        # SNP name
        \s+                 # separated by whitespace
        (rs\d+)             # rs ID
        \s+                 # separated by whitespace
        ([\w\d]+)           # chromosome
        \s+                 # separated by whitespace
        (\d+)               # map location
        \s+                 # separated by whitespace
        [-+]+               # strand
        \s+                 # separated by whitespace
        [\w\d\.]+           # cytoband
        \s+                 # separated by whitespace
        (\w)+               # reference allele
        \s+                 # separated by whitespace
        (\w)+               # variant allele
        \s+                 # separated by whitespace
        (.*)
        \z                  # end of string
    };

    Readonly my $FIELD_SEPARATOR => qr{\s+};

    if(my ($rs_id, $chromosome, $map_loc, $ref_allele, $var_allele, $genotypes)
        = $partek_line =~ m{$PARTEK_LINE_REGEX} ) {

        @{ $partek_data_hashref->{$rs_id} }
            {'chromosome', 'map_location', 'ref_allele', 'var_allele'}
            = ($chromosome, $map_loc, $ref_allele, $var_allele);

        my @genotype_calls = split $FIELD_SEPARATOR, $genotypes;
        $self->_translate_ab_alleles(
            \$ref_allele, \$var_allele, \@genotype_calls);
        $partek_data_hashref->{$rs_id}->{genotypes_arrayref}
            = \@genotype_calls;
    }

}

sub _translate_ab_alleles {
    my ($self, $ref_allele, $var_allele, $genotypes_arrayref) = @_;

    foreach my $genotype (@$genotypes_arrayref) {
        $genotype =~ s{A}{$$ref_allele}g;
        $genotype =~ s{B}{$$var_allele}g;
    }
}

sub align_genotypes_with_probelist {
    my ($self, $partek_data_hashref) = @_;

    my $probes_reader = Concordance::Probes::Reader->new(
        probelist_file => $self->probelist_file);

    my $probes_data = {};
    $probes_reader->read_probelist_into_hashref;

    foreach my $partek_data (keys %$partek_data_hashref) {
        $probes_reader->align_allele_and_genotype_with_probelist(
            $partek_data_hashref->{$partek_data}->{ref_allele},
            $partek_data_hashref->{$partek_data}->{var_allele},
            $partek_data_hashref->{$partek_data}->{genotypes_arrayref},
            $probes_data->{$partek_data}->{pl_ref_allele},
            $probes_data->{$partek_data}->{pl_var_allele},
        );
    }

}

sub get_array_ref_of_samples {
    my ($self, $header_line) = @_;

    Readonly my $SAMPLES_REGEX => qr{
        \A              # start of string
        .*Allele\sB     # throw out the headers
        \s+             # whitespace
        (.*)            # grab the sample names
        \z              # end of string
    };

    Readonly my $FIELD_SEPARATOR => qr{\s+};

    my $sample_arrayref = ();

    if (my ($samples) = $$header_line =~ m{$SAMPLES_REGEX}) {
       @$sample_arrayref = split $FIELD_SEPARATOR, $samples;
    }

    return $sample_arrayref;
}

sub write_birdseed_files {
    my ($self, $samples_arrayref) = @_;
}

sub execute {
    my ( $self, ) = @_;
    # pair sample with genotype
    my $partek_file = IO::File->new($self->partek_file, "<")
        or croak "Couldn't open for writing: '$self->partek_file': $OS_ERROR";

    my $header_line = <$partek_file>; # just get the line w/ sample names

    undef $partek_file;

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
