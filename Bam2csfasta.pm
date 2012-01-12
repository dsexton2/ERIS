package Concordance::Bam2csfasta;

=head1 NAME

Concordance::Bam2csfasta - converts .bam files to .csfasta files

=head1 SYNOPSIS

 use Concordance::Bam2csfasta;
 my $bam_2_csfasta = Concordance::Bam2csfasta->new;
 $bam_2_csfasta->config(\%config);
 $bam_2_csfasta->samples(\%samples);
 $bam_2_csfasta->convert_bam_to_csfasta;

=head1 DESCRIPTION

This script takes a CSV file with sample ID / .bam path pairs.  It
iterates on each line of this CSV file, calling a JAR to convert the
.bam files into .csfasta files.  It also produces a new CSV file with
sample ID / .csfasta path pairs.

=head2 Methods

=cut

use strict;
use warnings;
use diagnostics;
use Config::General;
use Log::Log4perl;
use Concordance::Common::Scheduler;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

=head3 new

 my $bam2csfasta = Concordance::Bam2csfasta->new;

Returns a new Bam2csfasta instance.

=cut

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{samples} = undef;
	$self->{debug_flag} = 0;
	$self->{dependency_list} = undef;
	bless($self);
	return $self;
}

=head3 config

 $bam2csfasta->config(\%config);
 my %config = %{ $self->config };

Gets and sets the hash reference to the configuration items.

=cut

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
}

=head3 samples

 $bam2csfasta->samples(\%samples);
 my %samples = %{ $self->samples };

Gets and sets the hash reference to the Sample container.

=cut

sub samples {
	my $self = shift;
	if (@_) { $self->{samples} = shift }
	return $self->{samples};
}

=head3 debug_flag

 $bam2csfasta->debug_flag(1);
 if ($self->debug_flag) { print debug_info }

Gets and sets the debug_flag, indicating whether or not to print relevant debug
information, or to refrain from executing certain methods:

=cut

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift }
	return $self->{debug_flag};
}

=head3 dependency_list

 $scheduler->dependency_list($job_id);

Gets and sets the dependency list for a job, which causes a job to delay execution
until the jobs in its dependency list have completed.  When setting with this method, 
job IDs are appended to the class member to form a colon-delimited list, which is 
what msub expects.

=cut

sub dependency_list {
	my $self = shift;
	if (@_) {
		if (!defined($self->{dependency_list})) {
			$self->{dependency_list} = shift;
		}
		else {
			$self->{dependency_list} .= ":".shift
		}
	}
	return $self->{dependency_list};
}

=head3 __submit__

 $self->__submit__(sample_id, input_bam_file, *FH;

This private method is passed information from C<execute> to submit a job to
Moab, which generates a CSFASTA file from the requisite BAM file.

=cut

sub __submit__ {
	my $self = shift;
	my $sample_id = shift;
	my $input_bam_file = shift;

	if ($input_bam_file !~ /.bam$/) {
		print "Bad sample_id/input_bam_file pair: $sample_id\t$input_bam_file\n";
		next;
	}
	(my $output_csfasta_file = $input_bam_file) =~ s/bam$/csfasta/g;
	my $command = "\"".$self->config->{"java"}." -Xmx2G -jar ".$self->config->{"bam_2_csfasta_jar"}.
		" $input_bam_file".
		" >".
		" $output_csfasta_file \"";

	my $scheduler = Concordance::Common::Scheduler->new;
	$scheduler->command($command);
	$scheduler->job_name_prefix($sample_id);
	$scheduler->cores(2);
	$scheduler->memory(2000);
	if (defined($self->config->{'job-priority'})) { $scheduler->priority($self->config->{'job-priority'}) }
	if (!$self->debug_flag) { $scheduler->execute }
	
	$self->dependency_list($scheduler->job_id);
}

=head3 execute

 $bam2csfasta->execute;

Method for use by the calling class to initiate processing after passing the
necessary data via the accessor/mutator methods.  It will iterate on the Sample
container and extract the necessary information for a Moab submission, which is
accomplished by calling an internal method.

=cut

sub execute {
	my $self = shift;
	my %config = %{ $self->config };
	my %samples = %{ $self->samples };
	if (scalar keys %samples != 0) { # Sample objects passed from EGenoSolid
		foreach my $sample (values %samples) {
			$self->__submit__($sample->run_id, $sample->result_path);
		}
	}
	if (defined($self->dependency_list)) {
		my @dependency_list = split(/:/, $self->dependency_list);
		$debug_log->debug("dependency list: @dependency_list\n");
		print "Waiting for Bam2csfsta jobs to finish on msub...\n";
		while (@dependency_list) {
			foreach my $i (0..$#dependency_list) {
				my $qstat_info = `qstat $dependency_list[$i]`;
				if ($qstat_info !~ m/\bR\b/ and $qstat_info !~ m/\bQ\b/) {
					print "Job ".$dependency_list[$i]." completed.\n";
					$debug_log->debug("Job ".$dependency_list[$i]." completed.\n");
					splice (@dependency_list, $i, 1);
				}
			}
			if (scalar @dependency_list > 0) { sleep(600) }
		}
	}
	else {
		print "Warning: dependency_list undefined.  It's possible that no jobs were submitted\n";
		$warn_log->warn("Warning: dependency_list undefined.  It's possible that no jobs were submitted\n");
	}
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
