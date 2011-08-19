package Concordance::Judgement;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Inline Ruby => 'require "/users/p-qc/concordance/scripts/JudgeJudy.rb"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{project_name} = undef;
	$self->{input_csv_path} = undef;
	bless($self);
	return $self;
}

sub project_name {
	my $self = shift;
	if (@_) { $self->{project_name} = shift; }
	return $self->{project_name}; #[^\0]+
}

sub input_csv_path {
	my $self = shift;
	if (@_) { $self->{input_csv_path} = shift }
	return $self->{input_csv_path}; #\w+.csv$
}

sub execute {
	my $self = shift;
	print "Executing with parms ".$self->project_name." and ".$self->input_csv_path."\n";
	my $judgement = new Concordance::Judgement::JudgeJudy($self->project_name);
	$judgement->set_file($self->input_csv_path);
	$debug_log->debug("Judging concordance analysis for project ".$self->project_name." using file ".$self->input_csv_path."\n");
	$judgement->make_judgement;
}

1;

=head1 NAME

Concordance::Judgement - wrapper module for Judgement.rb

=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 Methods

=over12

=item C<new>

=item C<project_name>

=item C<input_csv_path>

=item C<execute>

=back

=head1 LICENSE

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
