package Concordance::TUI;

use warnings;
use strict;
use Config::General;
use Log::Log4perl;
use Term::ReadLine;


sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{CSVFILE} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

sub csv_file {
	my $self = shift;
	if (@_) { $self->{CSVFILE} = shift; }
	return $self->{CSVFILE};
}

sub read_and_validate_input {
	my $term = Term::ReadLine->new("saa");
	my $prompt = "Enter your arithmetic expression: ";
        my $OUT = $term->OUT || \*STDOUT;
}

1;
