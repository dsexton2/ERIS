#! /usr/bin/perl -w

=head1 NAME

Concordandce::BuildGeliAndBS - converts .birdseed.data.txt to .bs

=head1 SYNOPSIS

 use Concordance::BuildGeliAndBS;
 my $build_Geli_and_BS = Concordance::BuildGeliAndBS->new;
 $build_Geli_and_BS->config(%config);
 $build_Geli_and_BS->path("/foo/bar/");
 $build_Geli_and_BS->build_geli;
 $build_Geli_and_BS->build_bs;

=head1 DESCRIPTION

This script converts all .birdseed.data.txt files in the target directory into .bs, using .geli as an intermediate format.  It does this by calling two JARs, which each accomplish one of the conversions.

=head2 Methods

=over 12

=item C<new>

Returns a new Concordance::BuildGeliAndBS object.

=item C<config>

Gets or sets and gets the General::Config object.

=item C<path>

Gets or sets and gets the path string in which to search for .birdseed.data.txt or .geli files.

=item C<build_geli>

Calls a JAR to convert each .birdseed.data.txt file to a .geli file.  

=item C<build_bs>

Calls a JAR to convert each .geli file into a .bs file.

=back

=head1 LICENSE

This script is the property of Baylor College of Medicine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut

package Concordance::BuildGeliAndBS;

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{PATH} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

sub path {
	my $self = shift;
	if (@_) { $self->{PATH} = shift; }
	return $self->{PATH};
}

sub _get_file_list_ {
	my $self = shift;
	my @files = glob($self->path."/*.birdseed.data.txt");
	my $size = @files;

	if ($size == 0) {
		$error_log->error("no *.birdseed.data.txt files found in ".$self->path."\n");
		exit;
	}
	return @files;
}

sub build_geli {
	my $self = shift;
	my %config = $self->config;
	my @files = $self->_get_file_list_;
	my $cmd = '';

	foreach my $file (@files) {
	# covert cancer birdseed data files to geli format
		$cmd = $config{"java"}." -jar ".$config{"CancerBirdseedSNPsToGeliJAR"}.
		" I=$file".
		" S=".$config{"SAMPLE"}.
		" SNP60_DEFINITION=".$config{"SNP60_DEFINITION"}.
		" SD=".$config{"SEQUENCE_DICTIONARY"}.
		" R=".$config{"REFERENCE"}.
		" O=$file.geli";
		$debug_log->debug("building .geli for $file\n");
		$debug_log->debug("$cmd\n");
		system("$cmd");
	}
}

sub build_bs {
	my $self = shift;
	my %config = $self->config;
	my @files = $self->_get_file_list_;
	my $cmd = '';

	foreach my $file (@files) {
		# build bs file from geli
		$cmd = $config{"java"}." -jar ".$config{"GeliToTextExtendedJAR"}.
			" OUTPUT_LIKELIHOODS=".$config{"OUTPUT_LIKELIHOODS"}.
			" I=$file.geli".
			" >& ".
			" $file.bs";
		$debug_log->debug("building .bs for $file\n");
		$debug_log->debug("$cmd\n");
		system("$cmd");
	}
}
