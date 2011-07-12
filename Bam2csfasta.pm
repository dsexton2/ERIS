#!/usr/bin/perl -w

=head1 NAME

Concordance::Bam2csfasta - converts .bam files to .csfasta files

=head1 SYNOPSIS

 use Concordance::Bam2csfasta;
 my $bam_2_csfasta = Concordance::Bam2csfasta->new;
 $bam_2_csfasta->config(%config);
 $bam_2_csfasta->csv_file("foo.csv");
 $bam_2_csfasta->convert_bam_to_csfasta;

=head1 DESCRIPTION

This script takes a CSV file with sample ID / .bam path pairs.  It
iterates on each line of this CSV file, calling a JAR to convert the
.bam files into .csfasta files.  It also produces a new CSV file with
sample ID / .csfasta path pairs.

=head2 Methods

=over 12

=item C<new>

Returns a new Concordance::Bam2csfasta object.

=item C<config>

Gets and or sets the General::Config object.

=item C<csv_file>

Gets and sets the CSV file containing sample ID / .bam path pairs.

=item C<convert_bam_to_csfasta>

Iterates on the .bam files provided in the CSV and calls a JAR to convert each to a .csfasta.  Also writes sample ID / .csfasta path pairs to a new CSV file.

=back

=head1 LICENSE

This script is the property of Baylor College of Medecine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut

package Concordance::Bam2csfasta;

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{CSVFILE} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

sub csv_file {
	my $self = shift;
	if (@_) { $self->{CSVFILE} = shift; }
	return $self->{CSVFILE};
}

sub convert_bam_to_csfasta {
	my $self = shift;
	my $error_log = Log::Log4perl->get_logger("errorLogger");
	my $debug_log = Log::Log4perl->get_logger("debugLogger");

	if ($self->{CSVFILE} !~ /.+\.csv$/) {
		$error_log->error("This script requires a *.csv file as an argument.\n");
		exit;
	}

	open(CSV_FILE_BAM, $self->{CSVFILE});
	open(CSV_FILE_CSFASTA, "> ".$self->csv_file.".csfasta.csv");

	my %config = $self->config;

	while (<CSV_FILE_BAM>) {
		chomp;
		if($_ !~ /^(.*),+(.*)$/) { next; }
		my $sample_id = $1;
		my $input_bam_file = $2;
		if ($input_bam_file !~ /.bam$/) {
			print "Bad sample_id/input_bam_file pair: $sample_id\t$input_bam_file\n";
			next;
		}
		(my $output_csfasta_file = $input_bam_file) =~ s/bam$/csfasta/g;
		$output_csfasta_file =~ s/\.sorted\.dups\.rg//g;
		my $command = $config{"java"}." -Xmx2G -jar ".$config{"bam2csfastaJAR"}.
			" $input_bam_file".
			" >".
			" $output_csfasta_file";
		$debug_log->debug("Executing command: $command\n");
		$input_bam_file =~ s/\.sorted\.dups\.rg//g;
		print CSV_FILE_CSFASTA "$sample_id,$output_csfasta_file\n";
		system($command);
	}

	close(CSV_FILE_BAM);
	close(CSV_FILE_CSFASTA);
}

1;