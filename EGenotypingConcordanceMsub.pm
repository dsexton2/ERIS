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

sub egeno_list {
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
	open(FIN, $self->egeno_list);
	my $i=1;
	my @com_array;
	while(<FIN>)
	{
		chomp;
		my @a=split(/\s+/);
		my $temp=join("#",@a);

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

 use Concordance::EGenotypingConcordanceMsub;
 my $ecm = Concordance::EGenotypingConcordanceMsub->new;
 $ecm->egeno_list("foo.csv");
 $ecm->snp_array("/foo/bar");
 $ecm->execute;

=head1 DESCRIPTION

This module takes a CSV file and SNP array directory.  It then constructs commands
to submit to msub to execute eGenotyping concordance. This is a wrapper module to
another script.

=head2 Methods

=over 12

=item C<new>

The constructor which returns a new Concordance::EGenotypingConcordanceMsub object.

=item C<egeno_list>

Accessor/mutator for the CSV list of sample IDs and associated CSFASTA paths.

=item C<snp_array>

Accessor/mutator for the directory containing the SNP arrays (.birdseed files).

=item C<execute>

Constructs commands to submit to msub.

=back

=head1 LICENSE

This Perl module is the property of Baylor College of Medicine HGSC.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
