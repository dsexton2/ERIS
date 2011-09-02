package Concordance::Utils;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Concordance::Sample;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

sub get_params {
	# reads in the parameters from the metadata, and parses the data in
	# as a hash of hashes, with the following structure:
	# %hash = { class_name => %hash2 { param => validating_regex } }
	my $self = shift;
	my %config = undef;
	my %pipeline_params = undef;
	if (@_) { %config = shift }
	if (@_) { %pipeline_params = shift }
	if (-e $config{"metadata_file"}) {
		open(FIN, $config{"metadata_file"});
		my @lines = <FIN>;
		my $key = undef;
		foreach my $line (@lines) {
			chomp($line);
			if ($line =~ m/^\w/) {
				$key = $line;
				$pipeline_params{$key} = ();
				next;
			}
			$line =~ m/\t(.*)\t(.*)$/;
			$pipeline_params{$key}{$1} = "$2";
		}
		close(FIN);
	}
	return %pipeline_params;
}

sub read_and_validate_input {
	my $self = shift;
	my $prompt = undef;
	my $validation_pattern = undef;
	if (@_) {
		$prompt = shift;
		$validation_pattern = shift;
	}
	my $term = Term::ReadLine->new("");
	my $input = $term->readline($prompt.": ");
	chomp($input);
	while ($input !~ /$validation_pattern/) {
		print "$input failed validation on $validation_pattern\n";
		$input = $term->readline($prompt);	
	}
	$self->add_to_hash($prompt, $input);
	return $input;
}

sub add_to_hash {
	if (@_) {
		my $self = shift;
		my $key = shift;
		my $value = shift;
		$self->{CONFIG}{$key} = $value;
		$self->write_config_file;
	}
}

sub write_config_file {
	my $self = shift;
	open(CONFIG_OUT, ">".$self->config_file) || die "Couldn't open file for writing configuration items: ".$self->config_file."\n";
	my %config = $self->config;
	foreach my $key (sort (keys %config)) {
		print CONFIG_OUT $key." = ".$config{$key}."\n";
	}
	close CONFIG_OUT;
}

sub check_perms {
	# ensure that user@host has write permissions for path
	
}

sub get_file_list {
	# returns a list of all files of type $file_extension from directory $path
	shift;
	my $path = undef;
	my $file_extension = undef; # not prepended with period
	if (@_) { $path = shift }
	if (@_) { $file_extension = shift }
	my @files = glob($path."/*.".$file_extension);
	if ($#files == -1) {
		#$error_log->error("No ".$file_extension." files found in ".$path."\n");
		exit;
	}
	return @files;
}

sub validate_param {
	my $validation_regex = undef;
	my $path = undef;
	if ($#_ <= 1) {  }
	if (@_) { $validation_regex = shift }
	if (@_) { $path = shift }
	if ($path !~ /$validation_regex/) { }
	if (-e $path) { 
		if (!-r $path) { $error_log->error("\n") }
		if (!-w $path) { $error_log->error("\n") }
	}
	else { $warn_log->warn("$path DNE\n") }
}

sub populate_sample_info_hash {
	# this should be a comma-delimited list of run IDs; 
	my $run_id_list = undef;
	if (@_) { $run_id_list = $_[$#_] }

	my $post_data = "runnamelist=$run_id_list";
	my $url = "http://test-gen2.hgsc.bcm.tmc.edu/gen2lims-reporting/jaxrs/reportservice/runinfo";
	my $result = `curl -d "$post_data" -X POST $url`;
	my %samples = ();

	while ($result =~ m/([^,]+),([^,]+),(.*)\n/) {
	    if ($1 ne "run_name") {
	        $samples{$2} = Concordance::Sample->new;        
	        $samples{$2}->run_id($1);
	        $samples{$2}->sample_id($2);                                                                     
	        $samples{$2}->result_file($3);                                                                   
	    }   
	    $result =~ s/$1,$2,$3\n//;                                                                           
	}
	return %samples;
}

#stubs

#

1;
