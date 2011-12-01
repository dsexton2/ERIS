package Concordance::GeliToBs;

=head1 NAME

Concordance::GeliToBs

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

 my $gtb = Concordance::GeliToBs->new;

=cut

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{geli_dir} = undef;
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

 $rbtg->geli_dir("/foo/bar");
 my $geli_dir = $self->raw_birdseed_dir;

Gets or sets the path to the directory containing the geli files.

=cut

sub geli_dir {
	my $self = shift;
	if (@_) { $self->{geli_dir} = shift; }
	return $self->{geli_dir}; #[^\0]+
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

 $rbtg->execute;

Generically named method to kick off processing.

=cut

sub execute {
	my $self = shift;
	my $config = $self->config;

	my @files = Concordance::Utils->get_file_list($self->geli_dir, "geli");
	if ($#files == -1) { croak "No geli files in ".$self->geli_dir."\n" }

	my $cmd = '';
	foreach my $file (@files) {
		# build bs file from geli
		$cmd = "\"".$config->{"java"}." -jar ".
			$config->{"geli_to_text_extended_jar"}.
			" OUTPUT_LIKELIHOODS=".$config->{output_likelihoods}.
			" I=$file".
			" >& ".
			" $file.bs \"";
		$file =~ /.*\/(.*)\.birdseed\.data\.txt\.geli$/;
		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($cmd);
		$scheduler->job_name_prefix($1."_toBS".$$);
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
