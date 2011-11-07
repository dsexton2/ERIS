package Concordance::GeliToBs;

use strict;
use warnings;
use Config::General;
use Log::Log4perl;
use Concordance::Common::Scheduler;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{path} = undef;
	$self->{output_likelihoods} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
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
	my %config = %{ $self->config };
	my @files = $self->_get_file_list_(".geli");
	my $cmd = '';

	foreach my $file (@files) {
		# build bs file from geli
		$cmd = "\"".$config{"java"}." -jar ".$config{"geli_to_text_extended_jar"}.
			" OUTPUT_LIKELIHOODS=".$self->output_likelihoods.
			" I=$file".
			" >& ".
			" $file.bs \"";
		$file =~ /.*\/(.*)\.birdseed\.data\.txt\.geli$/;

		my $scheduler = Concordance::Common::Scheduler->new;
		$scheduler->command($cmd);
		$scheduler->job_name_prefix($1."_toBS");
		$scheduler->cores(2);
		$scheduler->memory(2000);
		$scheduler->priority("normal");
		$scheduler->execute;
	}
}

1;
