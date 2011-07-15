#! /usr/bin/perl -w

package Concordance::BsubIlluminaEgeno;

use strict;
use warnings;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{EGENOLIST} = undef;
	$self->{SNPARRAY} = undef;
	$self->{SCRIPTPATH} = undef;
	bless($self);
	return $self;
}

sub e_geno_list {
	my $self = shift;
	if (@_) { $self->{EGENOLIST} = shift; }
	return $self->{EGENOLIST};
}

sub snp_array {
	my $self = shift;
	if (@_) { $self->{SNPARRAY} = shift; }
	return $self->{SNPARRAY};
}

sub script_path {
	my $self = shift;
	if (@_) { $self->{SCRIPTPATH} = shift; }
	return $self->{SCRIPTPATH};
}

sub submit_to_bsub {
	my $self = shift;
	my $e_geno_list = $self->e_geno_list;
	my $SNP_array = $self->snp_array;
	open(FIN,"$e_geno_list");
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
		$scheduler->runCommand;
	}
	close(FIN);
}
