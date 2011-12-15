package Concordance::RawBsToGeli;

=head1 NAME

Concordance::RawBsToGeli 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=cut

use strict;
use warnings;

use Carp;
use Concordance::Common::Scheduler;
use Concordance::Utils;
use Config::General;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");            
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head3 new

 my $rbtg = Concordance::RawBsToGeli->new;

Returns a new instance of RawBsToGeli.

=cut

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{raw_birdseed_dir} = undef;
	$self->{project_name} = undef;
	$self->{dependency_list} = undef;
	bless($self);
	return $self;
}

=head3 config

 $rbtg->config(\%config);
 my $config_hashref = $self->config;

Gets or sets the hash containing the configuration items.

=cut

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
}

=head3

 $rbtg->raw_birdseed_dir("/foo/bar");
 my $raw_birdseed_dir = $self->raw_birdseed_dir;

Gets or sets the path to the directory containing the raw birdseed files.

=cut

sub raw_birdseed_dir {
	my $self = shift;
	if (@_) { $self->{raw_birdseed_dir} = shift; }
	return $self->{raw_birdseed_dir};
}

=head3 project_name

 $rbtg->sample_name("foo");
 my $sample_name = $rbtg->sample_name;

Gets and sets the project name; this is required by the JAR.

=cut

sub project_name {
	my $self = shift;
	if (@_) { $self->{project_name} = shift }
	return $self->{project_name};
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

=head3 execute

 $rbtg->execute;

Generically named method to kick off processing.

=cut

sub execute {
	my $self = shift;
	my $config = $self->config;

	my @files = Concordance::Utils->get_file_list($self->raw_birdseed_dir, "birdseed.data.txt");
	if ($#files == -1) { croak "No birdseed.data.txt files in ".$self->raw_birdseed_dir."\n" }

	my $cmd = '';
	foreach my $file (@files) {
	# covert cancer birdseed data files to geli format
		$cmd = "\"".$config->{java}." -jar ".
			$config->{cancer_birdseed_snps_to_geli_jar}.
			" I=$file".
			" S=".$self->project_name.
			" SNP60_DEFINITION=".$config->{snp60_definition_path}.
			" SD=".$config->{sequence_dictionary_path}.
			" R=".$config->{reference_path}.
			" O=$file.geli \"";
		$file =~ /.*\/(.*)\.birdseed\.data\.txt$/;
		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($cmd);
		$scheduler->job_name_prefix($1."_toGELI".$$);
		$scheduler->cores(2);
		$scheduler->memory(2000);
		$scheduler->priority("normal");
		$scheduler->execute;

		$self->dependency_list($scheduler->job_id);
	}
}

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
