package Concordance::BsubIlluminaEgeno;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

if(!Log::Log4perl->initialized()) { print "Warning: Log4perl has not been initialized\n" }

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $error_screen = Log::Log4perl->get_logger("errorScreenLogger");

sub new {
	my $self = {};
	$self->{egeno_list} = undef;
	$self->{snp_array} = undef;
	$self->{script_path} = undef;
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

sub egeno_list {
	my $self = shift;
	if (@_) { $self->{egeno_list} = shift; }
	return $self->{egeno_list}; #\w+.txt$
}

sub snp_array {
	my $self = shift;
	if (@_) { $self->{snp_array} = shift; }
	return $self->{snp_array}; #[^\0]+
}

sub script_path {
	my $self = shift;
	if (@_) { $self->{script_path} = shift; }
	return $self->{script_path}; #\w+.pl$
}

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift; }
	return $self->{debug_flag};
}

sub execute {
	my $self = shift;
	my $egeno_list = $self->egeno_list;
	my $SNP_array = $self->snp_array;
	if (!-e $egeno_list) {
		$error_log->error("Egeno_list file DNE: $egeno_list\n");
		$error_screen->error("Egeno_list file DNE: $egeno_list\n");
	}
	open(FIN,"$egeno_list");
	my $i=1;
	my @com_array;
	while(<FIN>)
	{
		chomp;
		my @a=split(/\s+/);
		my $size=@a;
		my $temp=$a[0];
		for (my $j=1;$j<$size;$j++) { $temp .= "#".$a[$j]; }
		my $command = $self->script_path." $temp $SNP_array";
		$com_array[$i] = $command;
		$i++;

		my $scheduler = new Concordance::BsubIlluminaEgeno::Scheduler("$i-eGT-$SNP_array", $command);
		$scheduler->setMemory(2000);
		$scheduler->setNodeCores(2);
		$scheduler->setPriority('normal');
		$debug_log->debug("Submitting job with command: $command\n");
		if (!$self->debug_flag) { $scheduler->runCommand }
	}
	close(FIN);
}
