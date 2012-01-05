package Concordance::BsubIlluminaEgeno;

=head1 NAME

Concordance::BsubIlluminaEgeno

=head1 SYNOPSIS

 my $bie = Concordance::BsubIlluminaEgeno->new;
 $bie->egeno_list("/path/to/list");
 $bie->snp_array("/path/to/snp/array/dir");
 $bie->script_path("/path/to/perl/script");
 $bie->debug_flag(0);
 $bie->execute;

=head1 DESCRIPTION

This module submits jobs to moab to prepare Illumina data for concordance analysis.

=head2 Methods

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::Common::Scheduler;
use Log::Log4perl;

if(!Log::Log4perl->initialized()) { print "Warning: Log4perl has not been initialized\n" }

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head3 new

 my $bie = Concordance::BsubIlluminaEgeno->new;

Returns a new instance of this module.

=cut

sub new {
	my $self = {};
	$self->{egeno_list} = undef;
	$self->{snp_array} = undef;
	$self->{script_path} = undef;
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

=head3 egeno_list

 $bie->egeno_list("/path/to/egeno/list");
 my $list = $self->egeno_list;

Accessor/mutator for the list of run IDs and their associated result files.

=cut

sub egeno_list {
	my $self = shift;
	if (@_) { $self->{egeno_list} = shift }
	return $self->{egeno_list};
}

=head3 snp_array

 $bie->snp_array("/path/to/snp/array/dir");
 my $snp_array_dir = $self->snp_array_dir;

Accessor/mutator for the SNP array directory.

=cut

sub snp_array {
	my $self = shift;
	if (@_) { $self->{snp_array} = shift }
	return $self->{snp_array};
}

=head3 script_path

 $bie->script_path("/path/to/script");
 my $script_path = $self->script_path;

Accessor/mutator for the path to the perl script used to prepare the Illumina data for concordance analysis.

=cut

sub script_path {
	my $self = shift;
	if (@_) { $self->{script_path} = shift }
	return $self->{script_path};
}

=head3 debug_flag

 $bie->debug_flag(1);
 my $debug_flag = $self->debug_flag;

Accessor/mutator for the debug flag, which controls whether certain commands (such as job submission) are executed.  Useful for debugging/testing.  This is turned off by default.

=cut

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift }
	return $self->{debug_flag};
}

=head3 execute

 $bie->execute;

This processes the C<egeno_list> and submits the jobs, which execute using the C<script_path>.

=cut

sub execute {
	my $self = shift;

	if (!-e $self->egeno_list) {
		$error_log->error("Egeno_list file DNE: ".$self->egeno_list."\n");
		croak "Egeno_list file DNE: ".$self->egeno_list."\n";
	}

	open(FIN, $self->egeno_list) or croak $!;
	while(<FIN>) {
		chomp;
		my $command = $self->script_path." ".join('#', (split(/\s+/)));

		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($command);
		$scheduler->job_name_prefix($$."_".rand(5000)."-eGT-".$self->SNP_array);
		$scheduler->cores(2);
		$scheduler->memory(2000);
		$scheduler->priority("normal");
		if (!$self->debug_flag) { $scheduler->execute }
	}
	close(FIN) or carp $!;
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
