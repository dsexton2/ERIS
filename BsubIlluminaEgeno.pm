#! /usr/bin/perl -w

package Concordance::BsubIlluminaEgeno;

use strict;
use warnings;

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
	if ($SNP_array eq '') {
		$error_log->error("You must specify a project directory containing the *.birdseed files!\n");
		exit;
	}
	
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
		
		my $command = "bsub -e $i.e -o $i.o -J $i-eGT-$SNP_array \"".$self->script_path." $temp $SNP_array\"\;";
		$com_array[$i] = $command;
		$i++;
	
		$debug_log->debug("Executing command: $command\n");
		system("$command");
		sleep(2);
	}
	close(FIN);
}
