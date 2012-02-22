package Concordance::Alignment::BirdseedAlignment;

use strict;
use warnings;
use diagnostics;

use Carp;
use Data::Dumper;
use Moose;
use Moose::Util::TypeConstraints;

subtype 'Path',
	as 'Str',
	where { -e $_ },
	message { "$_ is not a valid path or does not exist" };

has 'birdseed_path' => (
	is  => 'rw',
	isa => 'Path',
	required => 1,
	documentation => "The path to the birdseed file or directory of files on which to perform alignment",
);

has 'probelist_path' => (
	is  => 'rw',
	isa => 'Path',
	required => 1,
	documentation => "The path to the probelist file with which to align",
);

has 'rsId_list_path' => (
	is  => 'rw',
	isa => 'Path',
	required => 1,
	documentation => "The path to the file containing the list of rs IDs",
);

subtype 'NonNegativeInt',
	as 'Int',
	where { $_ >= 0 and $_ !~ /\./ },
	message { "The number you provided, $_, was not a non-negative integer " };

has 'rsId_col' => (
	is  => 'rw',
	isa => 'NonNegativeInt',
	default => 0,
	documentation => "The zero-indexed column of the rsId-list-path containing rsIds",
);

sub get_probelist_data {
	my ($self, $data) = @_;
	open(FIN_PROBELIST, "<".$self->probelist_path) or croak $!;
	while(<FIN_PROBELIST>) {
		chomp;
		my @vals_by_col = split(/\t/);
		$data->{$vals_by_col[2]}->{pl_chr} = $vals_by_col[0];
		$data->{$vals_by_col[2]}->{pl_chr_pos} = $vals_by_col[1];
		$data->{$vals_by_col[2]}->{ref_allele} = $vals_by_col[5];
		$data->{$vals_by_col[2]}->{var_allele} = $vals_by_col[6];
	}
	close(FIN_PROBELIST);
}

sub get_rsid_list_data {
	my ($self, $data) = @_;
	open(FIN_RSIDLIST, "<".$self->rsId_list_path) or die $!;
	while (<FIN_RSIDLIST>) {
		chomp;
		my @vals_by_col = split(/\t/);
		$data->{$vals_by_col[$self->rsId_col]}->{old_chr} = $vals_by_col[0];
		$data->{$vals_by_col[$self->rsId_col]}->{old_chr_pos} = $vals_by_col[3];
	}
	close(FIN_RSIDLIST);
}

sub execute {
	my $self = shift;
	my $data = {};
	$self->get_probelist_data($data);
	$self->get_rsid_list_data($data);

	my @files = ();
	if (-d $self->birdseed_path) {
		@files = glob($self->birdseed_path."/*.birdseed");
	}
	else {
		push @files, $self->birdseed_path;
	}
	
	open(FOUT_ERR, ">>error") or croak $!;

	foreach my $file (@files) {
		open(FIN_BS, "<".$file) or croak $!;
		open(FOUT_CONV_BS, ">".$file.".converted.birdseed") or croak $!;
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
						my $cmd = "grep -wm1 $chr_pos ".$self->rsId_list_path;
						my $rsId = `$cmd`;
						$rsId =~ s/.*(rs\d+)\t.*/$1/;
						print FOUT_ERR "rsId: $rsId $_\n";
						print FOUT_ERR Dumper(\%$value)."\n";
					}
				}
			}
		}
		close(FIN_BS) or carp $!;
		close(FOUT_CONV_BS) or carp $!;
	}
	close(FOUT_ERR) or carp $!;
}

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

B<align_birdseed_with_probelist> - process birdseed files to align with a given probelist

=head1 SYNOPSIS

B<align_birdseed_with_probelist.pl> [--birdseed-dir=</path/to/birdseed/files>] [--probelist-path=</path/top/probelist>] [--rsId-list-path=</path/to/rsId/list>] [--rsId-col=<cardinal-zero-indexed-column-of-rsId>] [--man] [--help] [--?]

Options:

 --birdseed-dir		directory containing birdseed files
 --probelist-path	path to probelist
 --rsId-list-path	path to file containing rsIds
 --rsId-col			zero-indexed rsId column number
 --help|?			prints a brief help message
 --man				prints an extended help message

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
