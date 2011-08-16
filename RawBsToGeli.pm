package Concordance::BuildGeliAndBS;

use strict;
use warnings;
use Config::General;
use Log::Log4perl;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{path} = undef;
	$self->{sample_name} = undef;
	$self->{snp60_definition} = undef;
	$self->{sequence_dictionary_path} = undef;
	$self->{reference_path} = undef;
	$self->{output_likelihoods} = undef;
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
	if (@_) { $self->{path} = shift; }
	return $self->{path}; #[^\0]+
}

sub sample_name {
	my $self = shift;
	if (@_) { $self->{sample_name} = shift }
	return $self->{sample_name}; #[^\0]+
}

sub snp60_definition_path {
	my $self = shift;
	if (@_) { $self->{snp60_definition_path} = shift }
	return $self->{snp60_definition_path}; #\w+.csv$
}

sub sequence_dictionary_path {
	my $self = shift;
	if (@_) { $self->{sequence_dictionary_path} = shift }
	return $self->{sequence_dictionary_path}; #\w+.dict$
}

sub reference_path {
	my $self = shift;
	if (@_) { $self->{reference_path} = shift }
	return $self->{reference_path}; #\w+.fasta$
}

sub output_likelihoods {
	my $self = shift;
	if (@_) { $self->{output_likelihoods} = shift }
	return $self->{output_likelihoods}; #False|True
}

sub _get_file_list_ {
	my $self = shift;
	my $file_extension = "";
	if (@_) { $file_extension = shift; }
	my @files = glob($self->path."/*".$file_extension);
	my $size = @files; 
	if ($size == 0) {
		$error_log->error("no ".$file_extension." files found in ".$self->path."\n");
		exit;
	}
	return @files;
}

sub execute {
	my $self = shift;
	my %config = $self->config;
	my @files = $self->_get_file_list_(".birdseed.data.txt");
	my $cmd = '';

	foreach my $file (@files) {
	# covert cancer birdseed data files to geli format
		$cmd = $config{"java"}." -jar ".$config{"cancer_birdseed_snps_to_geli_jar"}.
		" I=$file".
		" S=".$self->sample_name.
		" SNP60_DEFINITION=".$self->snp60_definition_path.
		" SD=".$self->sequence_dictionary_path.
		" R=".$self->reference_path.
		" O=$file.geli";
		$file =~ /.*\/(.*)\.birdseed\.data\.txt$/;
		my $scheduler = new Concordance::BsubIlluminaEgeno::Scheduler($1."_toGELI", $cmd);
		$scheduler->setMemory(2000);
		$scheduler->setNodeCores(2);
		$scheduler->setPriority('normal');
		$debug_log->debug("Submitting job for conversion to GELI with command: $cmd\n");
		$scheduler->runCommand;
	}
}

1;

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
