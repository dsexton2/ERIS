package Concordance::Utils;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Concordance::Sample;
use Carp;

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $error_screen = Log::Log4perl->get_logger("errorScreenLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

=head1 NAME

Concordance::Utils - common functions

=head1 SYNOPSIS

 my @file_list = Concordance::Utils->get_file_list($path, $ext);
 my %samples = Concordance::Utils->populate_sample_info_hash($run_list);

=head1 DESCRIPTION

=head2 Methods

=head3 get_file_list

 my $path = "/foo/bar";
 my $ext = "foo";
 my @file_list = Concordance::Utils->get_file_list($path, $ext);

For a given path and file extension, returns all files of that type from the directory as an array.

=cut

sub get_file_list {
	# returns a list of all files of type $file_extension from directory $path
	shift;
	my $path = undef;
	my $file_extension = undef; # not prepended with period
	if (@_) { $path = shift }
	if (@_) { $file_extension = shift }
	my @files = glob($path."/*.".$file_extension);
	if ($#files == -1) {
		$error_log->error("No ".$file_extension." files found in ".$path."\n");
	}
	return @files;
}

=head3 populate_sample_info_hash

 my $run_id_list = "foo,bar,rab,oof";
 my %samples = Concordance::Utils->populate_sample_info_hash($run_id_list);

For a given comma-delimited list of run IDs, executes a query against LIMS via curl, returning the associated sample ID, SNP array, and result path, storing each into a Sample object, and returning a hash of sample ID => Sample.

=cut

sub populate_sample_info_hash {
	shift;
	# run_id_list - this should be a comma-delimited list of run IDs
	# returns a hash populated as hash{sample_id} => Concordance::Sample
	my $run_id_list = "";
	if (@_) { $run_id_list = shift } 

	my $post_data = "runnamelist=$run_id_list";
	my $url = "http://gen2.hgsc.bcm.tmc.edu/gen2lims-reporting/jaxrs/reportservice/runinfo";
	my $result = `curl -d "$post_data" -X POST $url`;

	my %samples = ();
	while ($result =~ m/([^,]+),([^,]+),([^,]+),(.*)\n/) {
		my $run_id = $1;
		my $sample_id = $2;
		my $orig_sample_id = $2;
		my $result_path = $3;
		my $snp_array = $4;
		if ($run_id ne "run_name") {
			$samples{$run_id} = Concordance::Sample->new;
			$samples{$run_id}->run_id($run_id);
			$samples{$run_id}->snp_array($snp_array);
			$samples{$run_id}->sample_id($sample_id);
			$samples{$run_id}->result_path($result_path);
		}
	    $result =~ s/$run_id,$orig_sample_id,$result_path,$snp_array\n//; # remove the line; finished processing it
	}
	return %{ (validate_samples_container(\%samples)) };
}

sub populate_samples_from_csv {
	shift;
	my $input_csv_file = shift;
	if (!-e $input_csv_file) { croak $! }

	my %samples = ();

	open(FIN, $input_csv_file) or croak $!;
	while (<FIN>) {
		chomp;
		my @data_by_cols = split(/,/);
		$samples{$data_by_cols[0]} = Concordance::Sample->new;
		$samples{$data_by_cols[0]}->run_id($data_by_cols[0]);
		$samples{$data_by_cols[0]}->snp_array($data_by_cols[1]);
		$samples{$data_by_cols[0]}->sample_id($data_by_cols[2]);
		$samples{$data_by_cols[0]}->result_path($data_by_cols[3]);
	}
	close(FIN) or carp $!;

	return %{ (validate_samples_container(\%samples)) };

}

=head3 validate_samples_container

 $validate_samples_container(\%samples);

A private method that checks the sample_id, snp_array, and result_path fields to see of the LIMS web query returns any of them as null.  If that is the case, log the information and remove that sample from the container.

=cut

sub validate_samples_container {
	my %samples = %{ (shift) };

	foreach my $sample (values %samples) {
		if ($sample->sample_id eq "null" or $sample->sample_id eq "") {
			print_to_error_log_and_screen("Bad sample_id ".$sample->sample_id." for run ID ".
				$sample->run_id.", removing from Samples container ...");
			delete $samples{$sample->run_id};
			next;
		}
		if ($sample->snp_array eq "null" or $sample->snp_array eq "") {
			print_to_error_log_and_screen("Bad snp_array ".$sample->snp_array." for run ID ".
				$sample->run_id.", removing from Samples container ...");
			delete $samples{$sample->run_id};
			next;
		}
		if ($sample->result_path eq "null" or $sample->result_path eq "") {
			print_to_error_log_and_screen("Bad result_path ".$sample->result_path." for run ID ".
				$sample->run_id.", removing from Samples container ...");
			delete $samples{$sample->run_id};
			next;
		}	
	}
	return \%samples;
}

=head3 load_runIds_from_file

=cut

sub load_runIds_from_file {
	shift;
	my $runId_file = shift;
	my $runId_list = "";
	if (!-e $runId_file) { croak "$runId_file DNE: $!" }
	open(FIN, $runId_file) or croak $!;
	while (my $line = <FIN>) {
		if ($runId_list ne "") { $runId_list .= "," }
		chomp($line);
		$runId_list .= $line;
	}
	close(FIN) or carp $!;
	return $runId_list;
}

sub print_to_error_log_and_screen {
	my $message = shift;
	$error_screen->error($message."\n");
	print STDERR $message."\n";
}

=head1 LICENSE

GPLv3.

-head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
