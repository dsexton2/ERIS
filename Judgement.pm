#! /usr/bin/perl -w

package Concordance::Judgement;

use strict;
use warnings;
use Inline Ruby => 'require "/users/p-qc/concordance/scripts/JudgeJudy.rb"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{PROJECTNAME} = undef;
	$self->{FILEPATH} = undef;
	$self->{SCRIPTPATH} = undef;
	bless($self);
	return $self;
}

sub project_name {
	my $self = shift;
	if (@_) { $self->{PROJECTNAME} = shift; }
	return $self->{PROJECTNAME};
}

sub file_path {
	my $self = shift;
	if (@_) { $self->{FILEPATH} = shift }
	return $self->{FILEPATH};
}

sub execute {
	my $self = shift;
	my $judgement = new Concordance::Judgement::JudgeJudy($self->project_name);
	$judgement->set_file($self->file_path);
	$debug_log->debug("Judging concordance analysis for project ".$self->project_name." using file ".$self->file_path."\n");
	$judgement->make_judgement;
}

1;

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

=head1 AUTHOR

=cut
