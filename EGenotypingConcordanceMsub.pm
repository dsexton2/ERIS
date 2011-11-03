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
 $ecm->egeno_list("/foo/bar.txt");
 $ecm->snp_array("foo");
 $ecm->probe_list("/foo/bar");
 $ecm->sequencing_type("foo_sequencing_type");
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
	$self->{egeno_list} = undef;
	$self->{snp_array} = undef;
	$self->{probe_list} = undef;
	$self->{sequencing_type} = undef;
	$self->{dependency_list} = undef;
	bless($self);
	return $self;
}

=head3 egeno_list

 $egeno_msub->egeno_list("/path/to/egenolist.txt");

Gets and sets the path to the eGenotyping list, which contains line items of analysis IDs and the path(s) to their associated CSFASTA files (space-delimited).

=cut

sub egeno_list {
	my $self = shift;
	if (@_) { $self->{egeno_list} = shift }
	return $self->{egeno_list}; #\w+.txt$
}

=head3 snp_array

 $egeno_msub->snp_array("snp_directory_name");

Gets and sets the directory name in which the birdseed files (SNP arrays) are located.

=cut

sub snp_array {
	my $self = shift;
	if (@_) { $self->{snp_array} = shift }
	return $self->{snp_array}; #[^\0]+
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
	if (@_) { $self->{dependency_list} .= ":".shift }
	return $self->{dependency_list};
}

=head3 execute

 $egeno_msub->execute;

Iterates on the eGenotyping list provided, and submits the concordance analysis jobs to msub.

=cut

sub execute {
	my $self = shift;
	open(FIN, $self->egeno_list);
	my $job_counter = 1;
	while(my $line = <FIN>)
	{
		chomp($line);
		my @line_vals = split(/\s+/, $line);
		my $analysis_id = shift @line_vals;
		my $csfasta_files = join(',', @line_vals);

		my $command = "\"/users/p-qc/dev_concordance_pipeline/Concordance/Egenotyping/e-Genotyping_concordance.pl $analysis_id $csfasta_files ".$self->snp_array." ".$self->probe_list." ".$self->sequencing_type." \"";

		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($command);
		$scheduler->job_name_prefix($job_counter++."_".$$."_".int(rand(5000))."_eGeno_concor.job");
		$scheduler->cores(2);
		$scheduler->memory(20000);
		$scheduler->priority("normal");
		$scheduler->execute;

		$self->dependency_list($scheduler->job_id);
	}
	close(FIN);
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
