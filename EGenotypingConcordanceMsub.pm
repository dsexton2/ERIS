#!/hgsc_software/perl/latest/bin/perl

package Concordance::EGenotypingConcordanceMsub;

use strict;
use warnings;

use Log::Log4perl;
use Concordance::Common::Scheduler;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head1 NAME

Concordance::EGenotypingConcordanceMsub

=head1 SYNOPSIS

 use Concordance::EGenotypingConcordanceMsub;
 my $ecm = Concordance::EGenotypingConcordanceMsub->new;
 $ecm->snp_array_dir("/foo/bar");
 $ecm->probe_list("/foo/bar");
 $ecm->sequencing_type("foo_sequencing_type");
 $ecm->samples(\%samples);
 $ecm->config(\%config);
 $ecm->execute;

=head1 DESCRIPTION

This module takes a CSV file and SNP array directory.  It then constructs commands
to submit to msub to execute eGenotyping concordance. This is a wrapper module to
another script.

=head2 Methods

=head3 new

 my $egeno_msub = Concordance::EGenotypingMsub->new;

Creates a new Concordance::EGenotyping instance.

=cut

sub new {
	my $self = {};
	$self->{snp_array_dir} = undef;
	$self->{probe_list} = undef;
	$self->{sequencing_type} = undef;
	$self->{dependency_list} = undef;
	$self->{samples} = undef;
	$self->{config} = undef;
	bless($self);
	return $self;
}

=head3 snp_array_dir

 $egeno_msub->snp_array_dir("snp_directory_name");

Gets and sets the directory name in which the birdseed files (SNP arrays) are located.

=cut

sub snp_array_dir {
	my $self = shift;
	if (@_) { $self->{snp_array_dir} = shift }
	return $self->{snp_array_dir}; #[^\0]+
}

=head3 probe_list

 $egeno_msub->probe_list("/path/to/probelist");

Gets and sets the path to the probe list.

=cut

sub probe_list {
	my $self = shift;
	if (@_) { $self->{probe_list} = shift }
	return $self->{probe_list}; #[^\0]+
}

=head3 sequencing_type

 $egeno_msub->sequencing_type("solid");

Gets and sets the sequencing type, e.g. solid or illumina. 

=cut

sub sequencing_type {
	my $self = shift;
	if (@_) { $self->{sequencing_type} = shift }
	return $self->{sequencing_type}; #[^\0]+
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

=head3 samples

 $scheduler->samples(\%samples);

Gets and sets a hash reference to the Samples container.

=cut

sub samples {
	my $self = shift;
	if (@_) { $self->{samples} = shift }
	return $self->{samples};
}

=head3 config

 $scheduler->config(\%config);

Gets and sets the hash reference to the configuration hash.

=cut

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
}

=head3 execute

 $egeno_msub->execute;

Iterates on the eGenotyping list provided, and submits the concordance analysis jobs to msub.

=cut

sub execute {
	my $self = shift;
	my %samples = %{ $self->samples };

	foreach my $sample (values %samples) {
		my $command = "\"".
		$self->config->{"egeno_concordance_script"}." ".
		$sample->run_id." ".
		$sample->result_path." ".
		$self->snp_array_dir." ".
		$self->probe_list." ".
		$self->sequencing_type." ".
		$sample->snp_array." ".
		"\"";

		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($command);
		$scheduler->job_name_prefix($sample->run_id."_".$$."_".int(rand(5000))."_eGeno_concor.job");
		$scheduler->cores(2);
		$scheduler->memory(20000);
		if (defined($self->config->{'job-priority'})) { $scheduler->priority($self->config->{'job-priority'}) }
		$scheduler->execute;

		$self->dependency_list($scheduler->job_id);

		sleep(5); # msub doesn't like too many submissions at once
	}
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
