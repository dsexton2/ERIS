package Concordance::Common::Scheduler;

=head1 NAME

Concordance::Common::Scheduler - submit jobs to msub

=head1 SYNOPSIS

 use Concordance::Common::Scheduler;
 my $scheduler = Concordance::Common::Scheduler->new;
 $scheduler->command("command -to -execute /goes/here");
 $scheduler->job_name_prefix("sampleJobPrefix");
 $scheduler->cores(2);
 $scheduler->memory(2000);
 $scheduler->priority("normal");
 $scheduler->execute;

=head1 DESCRIPTION

This module facilitates job submission via msub.  This is a nearly direct translation (albeit slimmer) of a Ruby class by Nirav Shah.

=head2 Methods

=cut

use Cwd;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) { 
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head3 new

 my $scheduler = Concordance::Common::Scheduler->new`;

Returns a new Scheduler instance object.

=cut

sub new {
	my $self = {};
	$self->{command} = "";
	$self->{job_name_prefix} = "";
	$self->{cores} = 0;
	$self->{memory} = 0;
	$self->{priority} = "normal";
	bless $self;
	return $self;
}

=head3 command

 $scheduler->command("someCommand -options fields -etc");

Gets and sets the command to be submitted.

=cut

sub command {
	my $self = shift;
	if (@_) { $self->{command} = shift }
	return $self->{command};
}

=head3 job_name_prefix

 $scheduler->job_name_prefix("examplePrefix");

Gets and sets the job name prefix, which will be used compose the job name and names of the files to which STDERR and STDOUT are directed.

=cut

sub job_name_prefix {
	my $self = shift;
	if (@_) { $self->{job_name_prefix} = shift }
	return $self->{job_name_prefix};
}

=head3 cores

 $scheduler->cores(2);

Gets and sets the number of cores to utilize.

=cut

sub cores {
	my $self = shift;
	if (@_) { $self->{cores} = shift }
	return $self->{cores};
}

=head3 memory

 $scheduler->memory(2000);

Gets and sets the amount of memory (in MB) to utilize.

=cut

sub memory {
	my $self = shift;
	if (@_) { $self->{memory} = shift }
	return $self->{memory};
}

=head3 priority

 $scheduler->priority("normal");

Gets and sets the job priority status; default is 'normal'.

=cut

sub priority {
	my $self = shift;
	if (@_) { $self->{priority} = shift }
	return $self->{priority};
}

=head3 __build_job_name__

 $self->__build_job_name__;

Private method to compose the job name using the job prefix, the PID, and a random number.

=cut

sub __build_job_name__ {
	my $self = shift;
	my $job_name = $self->job_name_prefix."_".$$."_".int(rand(5000));
	return $job_name;
}

=head3 __build_command__

 $self->__build_command__;

Private method to build the command to submit via msub.

=cut

sub __build_command__ {
	my $self = shift;
	my $cmd = "echo ".$self->command." | ".
		"msub -N ".$self->__build_job_name__." ".
		"-o ".$self->job_name_prefix.".o ".
		"-e ".$self->job_name_prefix.".e ".
		"-q ".$self->priority." ".
		"-d ".getcwd()." ".
		"-l nodes=1:ppn=".$self->cores.",mem=".$self->memory."mb";
	$debug_log->debug($cmd);
	print $cmd."\n";
	return $cmd;
}

=head3 execute

 $scheduler->execute;

Public method to submit the built command via msub.

=cut

sub execute {
	$self = shift;
	system($self->__build_command__);
}

=head1 LICENSE

GPLv3

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
