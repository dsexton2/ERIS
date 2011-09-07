package Concordance::Sample;

use strict;
use warnings;
use diagnostics;

sub new {
	my $self = {};
	$self->{sample_id} = undef;
	$self->{run_id} = undef;
	$self->{snp_array} = undef;
	$self->{result_path} = undef;
	bless($self);
	return $self;
}

sub sample_id {
	my $self = shift;
	if (@_) { $self->{sample_id} = shift }
	return $self->{sample_id};
}

sub run_id {
	my $self = shift;
	if (@_) { $self->{run_id} = shift }
	return $self->{run_id};
}

sub snp_array {
	my $self = shift;
	if (@_) { $self->{snp_array} = shift }
	return $self->{snp_array};
}

sub result_path {
	my $self = shift;
	if (@_) { $self->{result_path} = shift }
	return $self->{result_path};
}

1;
