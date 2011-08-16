package Concordance::GeliToBs;

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
	my @files = $self->_get_file_list_(".geli");
	my $cmd = '';

	foreach my $file (@files) {
		# build bs file from geli
		$cmd = $config{"java"}." -jar ".$config{"geli_to_text_extended_jar"}.
			" OUTPUT_LIKELIHOODS=".$self->output_likelihoods.
			" I=$file".
			" >& ".
			" $file.bs";
		$file =~ /.*\/(.*)\.birdseed\.data\.txt\.geli$/;
		my $scheduler = new Concordance::GeliToBs::Scheduler($1."_toBS", $cmd);
		$scheduler->setMemory(2000);
		$scheduler->setNodeCores(2);
		$scheduler->setPriority('normal');
		$debug_log->debug("Submitting job for conversion to BS with command: $cmd\n");
		$scheduler->runCommand;
	}
}
