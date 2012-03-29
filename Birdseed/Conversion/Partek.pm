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

has 'append_mode' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
    documentation => 'Appends to birdseed files rather than overwrite',
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
    $probes_reader->read_probelist_into_hashref($probes_data);

    foreach my $partek_data (keys %$partek_data_hashref) {

        my ($ref_allele, $var_allele, $genotypes_arrayref, $pl_ref, $pl_var)
            =   ($partek_data_hashref->{$partek_data}->{ref_allele},
                 $partek_data_hashref->{$partek_data}->{var_allele},
                 $partek_data_hashref->{$partek_data}->{genotypes_arrayref},
                 $probes_data->{$partek_data}->{pl_ref_allele},
                 $probes_data->{$partek_data}->{pl_var_allele},
                );

        $probes_reader->align_allele_and_genotype_with_probelist(
            \$ref_allele,
            \$var_allele,
            $genotypes_arrayref,
            \$pl_ref,
            \$pl_var,
        );

        @{ $partek_data_hashref->{$partek_data} }
            { 'ref_allele', 'var_allele', 'genotypes_arrayref' }
            = ( $ref_allele, $var_allele, $genotypes_arrayref );
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

    if ((my $samples = $$header_line) =~ m{$SAMPLES_REGEX}) {
       @$sample_arrayref = split $FIELD_SEPARATOR, $samples;
    }

    return $sample_arrayref;
}

sub write_birdseed_files {
    my ($self, $samples_arrayref, $partek_data_hashref) = @_;

    my $index = 0;
    foreach my $sample (@$samples_arrayref) {
        my $birdseed_filename = $self->birdseed_dir."/"
            .$sample.".partek.birdseed";
        my $birdseed_handle;
        if ($self->append_mode != 0) {
            $birdseed_handle = IO::File->new($birdseed_filename, ">>")
                or croak "Failed to open for writing '$birdseed_filename': "
                    ."$OS_ERROR";
        }
        else {
            $birdseed_handle = IO::File->new($birdseed_filename, ">")
                or croak "Failed to open for writing '$birdseed_filename': "
                    ."$OS_ERROR";
        }

        foreach my $partek_data (values %$partek_data_hashref) {
            print $birdseed_handle
                $partek_data->{chromosome}."\t".
                $partek_data->{map_location}."\t".
                $partek_data->{ref_allele}."\t".
                $partek_data->{genotypes_arrayref}->[$index].
                "\n";
        }

        undef $birdseed_handle;
        $index++;
    }
}

sub execute {
    my ( $self, ) = @_;

    my $partek_data_hashref = {};

    my $partek_file = IO::File->new($self->partek_file, "<")
        or croak "Couldn't open for writing: '$self->partek_file': $OS_ERROR";

    my $header_line = <$partek_file>; # just get the line w/ sample names

    my $samples_arrayref = $self->get_array_ref_of_samples(\$header_line);

    while (my $partek_line = <$partek_file>) {
        chomp $partek_line;
        $self->parse_partek_line_into_hashref(
            $partek_data_hashref, $partek_line
        );
    }

    $self->align_genotypes_with_probelist($partek_data_hashref);

    $self->write_birdseed_files($samples_arrayref, $partek_data_hashref);

    undef $partek_file;

}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
