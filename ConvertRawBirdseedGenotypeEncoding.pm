package Concordance::ConvertRawBirdseedGenotypeEncoding;

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::Common::Scheduler;
use File::Basename;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");            
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{path} = undef;
	$self->{dependency_list} = undef;
	bless($self);
	return $self;
}

sub path {
	my $self = shift;
	if (@_) { $self->{path} = shift; }
	return $self->{path};
}

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

sub execute {
	my $self = shift;
	my @files=glob($self->path."/*.txt");

	foreach my $file (@files) {
		my $cmd = "perl /users/p-qc/dev_concordance_pipeline/Concordance/convert_raw_birdseed_genotype_encoding.pl $file";
		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($cmd);
		$scheduler->job_name_prefix(basename($file)."_toGELI".$$);
		$scheduler->cores(2);
		$scheduler->memory(2000);
		$scheduler->priority("normal");
		$scheduler->execute;
		$self->dependency_list($scheduler->job_id);
	}
}
