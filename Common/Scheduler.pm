package Concordance::Common::Scheduler;

use Cwd;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) { 
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

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

sub command {
	my $self = shift;
	if (@_) { $self->{command} = shift }
	return $self->{command};
}

sub job_name_prefix {
	my $self = shift;
	if (@_) { $self->{job_name_prefix} = shift }
	return $self->{job_name_prefix};
}

sub cores {
	my $self = shift;
	if (@_) { $self->{cores} = shift }
	return $self->{cores};
}

sub memory {
	my $self = shift;
	if (@_) { $self->{memory} = shift }
	return $self->{memory};
}

sub priority {
	my $self = shift;
	if (@_) { $self->{priority} = shift }
	return $self->{priority};
}

sub __build_job_name__ {
	my $self = shift;
	my $job_name = $self->job_name_prefix."_".$$."_".int(rand(5000));
	return $job_name;
}

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

sub execute {
	$self = shift;
	system($self->__build_command__);
}

1;
