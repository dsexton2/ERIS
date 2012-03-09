package Concordance::Birdseed::Conversion::PLINK;

use strict;
use warnings;
use diagnostics;
use Carp;
use Moose;
use Moose::Util::TypeConstraints;

subtype 'Path',
    as 'Str',
    where { -e $_ },
    message { "$_ is not a valid path or does not exist" };

has 'probelist_path' => (
    is => 'rw',
    isa => 'Path',
    required => 1,
    documentation => 'Full path to the probelist file',
);

has 'tped_file' => (
    is => 'rw',
    isa => 'Path',
    required => 1,
    documentation => 'Full path to the tped file',
);

has 'tfam_file' => (
    is => 'rw',
    isa => 'Path',
    required => 1,
    documentation => 'Full path to the tfam file',
);

sub is_valid_tfam_line {
    my ($self, $tfam_line) = @_;
    return ( $$tfam_line =~ m/^\d+\s\d+(\s\d){4}$/ );
}

sub is_valid_tped_line {
    my ($self, $tped_line) = @_;
    return ( $$tped_line
        =~ m/^\d+\srs\d+\s\d\s\d+((\s[0-4]){2}|(\s[AGCTagct]){2})+$/ );
}

sub _translate_numeric_allele_to_letter {
    my ($self, $tped_numeric_genotypes_ref) = @_;
    grep { $_ =~ tr/1234/ACGT/ } @$tped_numeric_genotypes_ref;
}

sub parse_tped_line_into_hashref {
    my ($self, $tped_line_ref, $tped_data_hashref) = @_;
    my @tped_columns = split /\s|\t/, $$tped_line_ref;

    # tped line: 16 rs7205107 0 48138708 3 3 1 3 (allele pairs continue ... )
    my $rs_id = $tped_columns[1];
    if (!exists $tped_data_hashref->{$rs_id}) {
        carp "Found $rs_id in TPED but not in probelist ... \n";
        return;
    }
    $tped_data_hashref->{$rs_id}->{chromosome} = $tped_columns[0];
    $tped_data_hashref->{$rs_id}->{map_location} = $tped_columns[3];

    # splice the array so all that's left are the allele pairs
    splice(@tped_columns, 0, 4);

    # merge each allele pair into one array element
    my $genotypes_ref = ();
    while (@tped_columns) {
        push @$genotypes_ref, ( (shift @tped_columns).(shift @tped_columns) );
    }
    $tped_data_hashref->{$rs_id}->{genotypes_ref} = $genotypes_ref;

    #if necessary, convert numeric alleles to letters
    $self->_translate_numeric_allele_to_letter(
        $tped_data_hashref->{$rs_id}->{genotypes_ref});
}

sub read_probelist_into_hashref {
    # TODO I've read probelist data into an rsID-keyed hash so much, there
    # really ought to be a class for this and other probelist methods
    my ($self, $conversion_data_hashref) = @_;
    open(FIN_PROBELIST, "<".$self->probelist_path) or croak $!;
    while(<FIN_PROBELIST>) {
        chomp;
        my @vals_by_col = split(/\t|\s/);
        my $rs_id = $vals_by_col[2];
        $conversion_data_hashref->{$rs_id}->{pl_chr} = $vals_by_col[0];
        $conversion_data_hashref->{$rs_id}->{pl_chr_pos} = $vals_by_col[1];
        $conversion_data_hashref->{$rs_id}->{ref_allele} = $vals_by_col[5];
        $conversion_data_hashref->{$rs_id}->{var_allele} = $vals_by_col[6];
    }
    close(FIN_PROBELIST);
}

# You will need to use our hg 18 and HG 19 probe files to find the ref allele
# and to make sure that the genotype matches the ref or var allele from the
# probe file as we have for all the other file conversions.  i.e if the .tped
# file says the genotype is GG but the probefile says the ref and var are C/T
# then you would change the genotype to CC in the birdseed file.

sub align_tped_alleles_with_probelist {
    my ($self, $tped_and_probe_data_hashref) = @_;

    foreach my $val_hashref (values %$tped_and_probe_data_hashref) {
        foreach my $genotype (@{ $val_hashref->{genotypes_ref} }) {
            if ($genotype !~
                m/[$val_hashref->{'ref_allele'}|$val_hashref->{'var_allele'}]{2}/) {
                $genotype =~ tr/AGCT/TCGA/;
            }
        }
    }
}

sub _correlate_chromosome_and_position {
    my ( $self, $tped_and_probe_hashref ) = @_;
    foreach my $val_hashref (values %$tped_and_probe_hashref) {
        if ($val_hashref->{chromosome} ne $val_hashref->{pl_chr}) {
            $val_hashref->{chromosome} = $val_hashref->{pl_chr};
        }
    }
    foreach my $val_hashref (values %$tped_and_probe_hashref) {
        if ($val_hashref->{map_location} ne $val_hashref->{pl_chr_pos}) {
            $val_hashref->{map_location} = $val_hashref->{pl_chr_pos};
        }
    }
}

sub _validate_hash {
    my ( $self, $hashref ) = @_;
    foreach my $rs_id (keys %$hashref) {
        foreach my $attribute (keys %{ $hashref->{$rs_id} }) {
            if (!defined($hashref->{$rs_id}->{$attribute})) {
                print STDERR "undefined $attribute for $rs_id, deleting ... \n";
                delete $hashref->{$rs_id};
                last;
            }
        }
        if (defined $hashref->{$rs_id}
            and defined($hashref->{$rs_id}->{genotypes_ref})) {
            if (scalar @{ $hashref->{$rs_id}->{genotypes_ref} } == 0) {
                print STDERR "no genotypes for $rs_id!!! deleting ...\n";
                delete $hashref->{$rs_id};
            }
        }
        else {
             print STDERR "undef attr gen: no genotypes for $rs_id!!! deleting ...\n";
             delete $hashref->{$rs_id};

        }
    }
    print STDERR "Validated hash ... \n";
}
# To make the final birdseed file use the sampleID from the .tfam file as the
# name of the birdseed file.  Use the rsId from the .tped file to query the
# probefile.  Use the chromosome, position, and ref allele from the probefile,
# making sure that the chromosome and position match the .tped file.  Use the
# genotype from the .tped file but check to make sure that the alleles match
# the ref and var from the probefile.

sub write_birdseed_file {
    my ( $self, $tped_and_probe_data_hashref ) = @_;
    open(FIN_TFAM, "<".$self->tfam_file) or croak $!;
    my $genotypes_ref_index = 0;
    while (<FIN_TFAM>) {
        chomp $_;
        if (!$self->is_valid_tfam_line(\$_)) {
            next;
        }
        my @tfam_line_tabbed_vals = split /\t|\s/, $_;
        open(FOUT_BIRDSEED,
            ">".$tfam_line_tabbed_vals[0].".tplink.birdseed") or croak $!;
        foreach my $values_hashref (values %$tped_and_probe_data_hashref) {
            my $snp_data = $values_hashref->{pl_chr}."\t";
            $snp_data .= $values_hashref->{pl_chr_pos}."\t";
            $snp_data .= $values_hashref->{ref_allele}."\t";
            # throw away no-call lines; TODO put this check elsewhere
            if ($values_hashref->{genotypes_ref}->[$genotypes_ref_index]
                    eq '00') {
                print STDERR "No call at index ".$genotypes_ref_index.
                    " for data ".$snp_data;
                next;
            }
            $snp_data .= $values_hashref->{genotypes_ref}->[$genotypes_ref_index].
                "\n";
            print FOUT_BIRDSEED $snp_data;
        }
        close(FOUT_BIRDSEED) or carp $!;
        $genotypes_ref_index++;
    }
    close(FIN_TFAM) or carp $!;
}

sub execute {
    my ( $self ) = @_;
    my $tped_and_probe_data_hashref = {};

    $self->read_probelist_into_hashref($tped_and_probe_data_hashref);

    # read in tped file; TODO put this in its own method
    print STDERR "Reading ".$self->tped_file." ...\n";
    open(FIN_TPED, "<".$self->tped_file) or croak $!;
    while (<FIN_TPED>) {
        chomp $_;
        if ( $self->is_valid_tped_line(\$_) ) {
            $self->parse_tped_line_into_hashref(
                \$_,
                $tped_and_probe_data_hashref
            );
        }
    }

    $self->_validate_hash($tped_and_probe_data_hashref);
    $self->align_tped_alleles_with_probelist($tped_and_probe_data_hashref);
    $self->_correlate_chromosome_and_position($tped_and_probe_data_hashref);
    $self->write_birdseed_file($tped_and_probe_data_hashref);

    close(FIN_TPED) or carp $!;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;


##############################################################################
##    Example 7.1 (Recommended) from Chapter 7 of "Perl Best Practices"     ##
##     Copyright (c) O'Reilly & Associates, 2005. All Rights Reserved.      ##
##  See: http://www.oreilly.com/pub/a/oreilly/ask_tim/2001/codepolicy.html  ##
##############################################################################


#  Example 7-1. User documentation template for modules

=head1 NAME
 
Birdseed::Conversion::PLINK - converts PLINK transposed files to birdseed
 
 
=head1 VERSION
 
This documentation refers to Concordance::Birdseed::Conversion::PLINK version 
0.0.1
 
 
=head1 SYNOPSIS
 
    use Concordance::Birdseed::Conversion::PLINK;

    my $plink_converter = Concordance::Birdseed::Conversion::PLINK->new(
        probelist_path => '/foo/bar/probelist',
        tfam_file => '/foo/bar/tfam',
        tped_file => '/foo/bar/tped',
    );
    $plink_converter->execute;
  
  
=head1 DESCRIPTION
 
An object of this class represents a transposed PLINK to Birdseed converter.

=head3 is_valid_tfam_line

Usage       : $self->is_valid_tfam_line(\$tfam_line);
Purpose     : Checks that the tfam line is in a valid format.
Returns     : True if the tfam line is valid; false otherwise.
Parameters  : A scalar reference to a line of tfam data.
Throws      : No exceptions.
Comments    : Validates against a regex.
See Also    : n/a

=head3 is_valid_tped_line

Usage       : $self->is_valid_tped_line(\$tped_line);
Purpose     : Checks that the tped line is in a valid format.
Returns     : True if the tped line is valid; false otherwise.
Parameters  : A scalar reference to a line of tped data.
Throws      : No exceptions.
Comments    : Validates against a regex.
See Also    : n/a

=head3 _translate_numeric_allele_to_letter

Usage       : $self->_translate_numeric_allele_to_letter($array_ref);
Purpose     : Translate nucleotides from numeric to alphabetic representation.
Returns     : n/a
Parameters  : A reference to an array of alleles or genotypes.
Throws      : No exceptions.
Comments    : n/a
See Also    : n/a

=head3 parse_tped_line_into_hashref

Usage       : $self->parse_tped_line_into_hashref(\$tped_line, $hashref);
Purpose     : Extracts data from a tped line into a named hash reference 
            : whose nested data structure is keyed off of rsID.
Returns     : n/a
Parameters  : Scalar reference to a line of tped data; hash reference.
Throws      : No exceptions.
Comments    : n/a
See Also    : n/a

=head3 read_probelist_into_hashref

Usage       : $self->read_probelist_into_hashref($hashref);
Purpose     : Extracts data from probelist file into a named hash reference 
            : whose nested data structure is keyed off of rsID.
Returns     : n/a
Parameters  : Hash reference.
Throws      : No exceptions.
Comments    : n/a
See Also    : n/a

=head3 align_tped_alleles_with_probelist

Usage       : $self->align_tped_alleles_with_probelist($hashref);
Purpose     : Aligns the alleles from the tped file against the indicated 
            : probelist, allowing
Returns     : 
Parameters  : 
Throws      : 
Comments    : 
See Also    : 

=head3 _correlate_chromosome_and_position

Usage       : 
Purpose     : 
Returns     : 
Parameters  : 
Throws      : 
Comments    : 
See Also    : 

=head3 _validate_hash

Usage       : 
Purpose     : 
Returns     : 
Parameters  : 
Throws      : 
Comments    : 
See Also    : 

=head3 write_birdseed_file

Usage       : 
Purpose     : 
Returns     : 
Parameters  : 
Throws      : 
Comments    : 
See Also    : 

=head3 execute

Usage       : 
Purpose     : 
Returns     : 
Parameters  : 
Throws      : 
Comments    : 
See Also    : 

 
=head1 SUBROUTINES/METHODS 
 
A separate section listing the public components of the module's interface. 
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.
 
In an object-oriented module, this section should begin with a sentence of the 
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.
 
 
=head1 DIAGNOSTICS
 
A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each 
problem, one or more likely causes, and any suggested remedies.
(See also  QUOTE \" " INCLUDETEXT "13_ErrorHandling" "XREF83683_Documenting_Errors_"\! Documenting Errors QUOTE \" " QUOTE " in Chapter "  in Chapter  INCLUDETEXT "13_ErrorHandling" "XREF40477__"\! 13.)
 
 
=head1 CONFIGURATION AND ENVIRONMENT
 
A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.
(also see  QUOTE \" " INCLUDETEXT "19_Miscellanea" "XREF40334_Configuration_Files_"\! Configuration Files QUOTE \" " QUOTE " in Chapter "  in Chapter  INCLUDETEXT "19_Miscellanea" "XREF55683__"\! 19.)
 
 
=head1 DEPENDENCIES
 
A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.
 
 
=head1 INCOMPATIBILITIES
 
A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for 
system or program resources, or due to internal limitations of Perl 
(for example, many modules that use source code filters are mutually 
incompatible).
 
 
=head1 BUGS AND LIMITATIONS
 
A list of known problems with the module, together with some indication
whether they are likely to be fixed in an upcoming release.
 
Also a list of restrictions on the features the module does provide: 
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets, 
special cases that are not (yet) handled, etc.
 
The initial template usually just has:
 
There are no known bugs in this module. 
Please report problems to <Maintainer name(s)>  (<contact address>)
Patches are welcome.
 
=head1 AUTHOR
 
<Author name(s)>  (<contact address>)
 
 
=head1 LICENCE AND COPYRIGHT
 
Copyright (c) 2012 John McAdams (mcadams@bcm.edu). All rights reserved.

This file is part of the Birdseed Conversion and Alignment Suite (BCAS).

BCAS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

BCAS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with BCAS.  If not, see <http://www.gnu.org/licenses/>.
