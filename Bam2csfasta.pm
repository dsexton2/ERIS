package Concordance::Bam2csfasta;

use strict;
use warnings;
use diagnostics;
use Config::General;
use Log::Log4perl;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{config} = ();
	$self->{csv_file} = undef;
	$self->{samples} = ();
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{config} } = @_ }
	return %{ $self->{config} };
}

sub csv_file {
	my $self = shift;
	if (@_) { $self->{csv_file} = shift }
	return $self->{csv_file}; #\w+.csv$
}

sub samples {
	my $self = shift;
	if (@_) { %{ $self->{samples} } = @_ }
	return %{ $self->{samples} };
}

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift }
	return $self->{debug_flag};
}

sub __submit__ {
	my $self = shift;
	my $sample_id = shift;
	my $input_bam_file = shift;
	my $fh = shift;
	my %config = $self->config;

	if ($input_bam_file !~ /.bam$/) {
		print "Bad sample_id/input_bam_file pair: $sample_id\t$input_bam_file\n";
		next;
	}
	(my $output_csfasta_file = $input_bam_file) =~ s/bam$/csfasta/g;
	my $command = $config{"java"}." -Xmx2G -jar ".$config{"bam_2_csfasta_jar"}.
		" $input_bam_file".
		" >".
		" $output_csfasta_file";
	print $fh "$sample_id,$output_csfasta_file\n";

	my $scheduler = new Concordance::Bam2csfasta::Scheduler($sample_id, $command);
	$scheduler->setMemory(2000);
	$scheduler->setNodeCores(2);
	$scheduler->setPriority('normal');
	$debug_log->debug("Submitting job with command: $command\n");
	if ($self->debug_flag) { $scheduler->runCommand }
}

sub execute {
	my $self = shift;
	my %config = $self->config;
	my %samples = $self->samples;
	open(CSV_FILE_CSFASTA, "> ".$self->csv_file.".csfasta.csv");

	if (scalar keys %samples != 0) { # Sample objects passed from EGenoSolid
		foreach my $sample_id (keys %samples) {
			my $input_bam_file = $samples{$sample_id}->result_path;
			$self->__submit__($sample_id, $input_bam_file, *CSV_FILE_CSFASTA);
		}
	}

	else { # reading from a file
		if ($self->{csv_file} !~ /.+\.csv$/) {
			$error_log->error("This script requires a *.csv file as an argument.\n");
			exit;
		}
		open(CSV_FILE_BAM, $self->{csv_file});
		while (<CSV_FILE_BAM>) {
			chomp;
			if($_ !~ /^(.*),+(.*)$/) { next; }
			my $sample_id = $1;
			my $input_bam_file = $2;
			$self->__submit__($sample_id, $input_bam_file, *CSV_FILE_CSFASTA);
		}
		close(CSV_FILE_BAM);
	}

	close(CSV_FILE_CSFASTA);
}

1;

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
