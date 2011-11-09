package Concordance::Contamination;

=head1 NAME

Concordance::Contamination - calculates contamination values for a Samples set

=head1 SYNOPSIS

 my $contamination = Concordance::Contamination->new;
 $contamination->samples(\%samples);
 $contamination->execute;

=head1 DESCRIPTION

This class does stuff.

=head2 Methods

=cut

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head3 new

 my $contamination = Concordance::Contamination->new;

Returns a new Concordance::Contamination object.

=cut

sub new {
	my $self = {};
	$self->{samples} = undef;
	$self->{snp_array_dir} = undef;
	bless $self;
	return $self;
}

=head3 samples

 $contamination->samples(\%samples);

Gets and sets the Sample data container.

=cut

sub samples {
	my $self = shift;
	if (@_) { $self->{samples} = shift }
	return $self->{samples};
}

=head3 snp_array_dir

 $contamination->snp_array_dir("/path/to/birdseed/files");

Gets and sets the path to the directory containing the SNP array birdseed files.

=cut

sub snp_array_dir {
	my $self = shift;
	if (@_) { $self->{snp_array_dir} = shift }
	return $self->{snp_array_dir};
}

=head3 execute

 $contamination->execute;

Does stuff.

=cut

sub execute {
	my $self = shift;
	my %samples = %{ $self->samples };
	foreach my $sample (values %samples) {
		
	}
}

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
