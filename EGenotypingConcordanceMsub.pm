#! /usr/bin/perl -w

package Concordance::EGenotypingConcordanceMsub;

use strict;
use warnings;

use Log::Log4perl;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{egeno_list} = undef;
	$self->{snp_array} = undef;
	bless($self);
	return $self;
}

sub e_geno_list {
	my $self = shift;
	if (@_) { $self->{egeno_list} = shift }
	return $self->{egeno_list}; #\w+.csv$
}

sub snp_array {
	my $self = shift;
	if (@_) { $self->{snp_array} = shift }
	return $self->{snp_array}; #[^\0]+
}

sub execute {
	my $self = shift;
	open(FIN, $self->e_geno_list);
	my $i=1;
	my @com_array;
	while(<FIN>)
	{
		chomp;
		my @a=split(/\s+/);
		my $temp=join("#",@a);
		#$command = "bsub -e $i.e -o $i.o -J $i\_eGeno\_concor.job \"/stornext/snfs0/next-gen/concordance_analysis/e-Genotyping_concordance.pl $temp $SNP_array \"\;";
		my $command = "\"/stornext/snfs0/next-gen/concordance_analysis/e-Genotyping_concordance.pl $temp ".$self->snp_array." \"\;";
		
		my $scheduler = new Concordance::Bam2csfasta::Scheduler("$i\_eGeno\_concor.job", $command);
		$scheduler->setMemory(2000);
		$scheduler->setNodeCores(2);
		$scheduler->setPriority('normal');
		$debug_log->debug("Submitting job with command: $command\n");
		$scheduler->runCommand;

		$com_array[$i] = $command;
		$i++;
	}
	close(FIN);
}

1;

=head1 NAME

Concordance::EGenotypingConcordanceMsub

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
