#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::EGenoSolid;
use Concordance::EGenotypingConcordanceMsub;
use Concordance::EGtIllPrep;
use Concordance::Judgement;
use Concordance::Utils;
use Concordance::Common::Scheduler;
use Config::General;
use File::Touch;
use Getopt::Long;
use Pod::Usage;
use POSIX;

pod2usage(-exitstatus => 0) if (@ARGV == 0);

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");
my $error_log = Log::Log4perl->get_logger("errorLogger");

my %options = ();

GetOptions (
	\%options,
	'run-id-list=s',
	'prep-result-path=s',
	'snp-array-dir=s',
	'probelist-path=s',
	'project-name=s',
	'config-path=s',
	'seq-type=s',
	'results-email=s',
	'no-lims',
	'help|?',
	'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});

# validate the input
if (!-e $options{'run-id-list'}) {
	print "run-id-list DNE: ".$options{'run-id-list'}."\n";
	exit(0);
}
if (!-e $options{'snp-array-dir'}) {
	print "snp-array-dir DNE: ".$options{'snp-array-dir'}."\n";
	exit(0);
}
if (!-e $options{'probelist-path'}) {
	print "probelist-path DNE: ".$options{'probelist-path'}."\n";
	exit(0);
}
if (!-e $options{'config-path'}) {
	print "config-path DNE: ".$options{'config-path'}."\n";
	exit(0);
}
$options{'seq-type'} = lc $options{'seq-type'};
if ($options{'seq-type'} ne "solid" and $options{'seq-type'} ne "illumina") {
	print "Bad value for seq-type: ".$options{'seq-type'}.".  Possible values are 'solid' or 'illumina'.\n";
	exit(0);
}

# touching the $options{'prep-result-path'} ensures that we can write to it and that it exists
eval { touch($options{'prep-result-path'}) };
if ($@) { croak $@ }

# Run LIMS webservice query
my %samples;
if ($options{'no-lims'}) {
	# hack to deal with old Illumina data lacking run IDs
	%samples = Concordance::Utils->populate_samples_from_csv($options{'run-id-list'});
}
else {
	%samples = Concordance::Utils->populate_sample_info_hash(
		Concordance::Utils->load_runIds_from_file($options{'run-id-list'}));
}

# Load configuration file
my %config = new Config::General($options{'config-path'})->getall;

# combine the config hash and the options hash, write them out for debugging purposes
my %run_env = %config;
@run_env{ keys %options } = values %options;
@run_env{keys %samples } = values %samples;
Config::General::SaveConfig("/users/p-qc/log/config/config_".POSIX::strftime("%m%d%Y_%H%M%S", localtime).".cfg", \%run_env);

my $samples_ref;

if ($options{'seq-type'} eq "illumina") {
print "Running EGtIllPrep...\n";
	# Illumina eGenotyping concordance preparation
	my $egtIllPrep = Concordance::EGtIllPrep->new;
	$egtIllPrep->samples(\%samples);
	$egtIllPrep->output_txt_path($options{'prep-result-path'});
	$egtIllPrep->execute;
	$samples_ref = $egtIllPrep->samples;
}
else {
	# SOLiD eGenotyping concordance preparation
	# this may call Bam2csfasta if errors are present
	my $egs = Concordance::EGenoSolid->new;
	$egs->config(\%config);
	$egs->samples(\%samples);
	$egs->execute;
	$samples_ref = $egs->samples;
}

# Submit concordance analysis jobs to MOAB
print "Running EGenotypingConcordanceMsub...\n";
my $ecm = Concordance::EGenotypingConcordanceMsub->new;
$ecm->config(\%config);
$ecm->snp_array_dir($options{'snp-array-dir'});
$ecm->probe_list($options{'probelist-path'});
$ecm->sequencing_type($options{'seq-type'});
$ecm->samples($samples_ref);
$ecm->execute;

# get the job IDs of the jobs submitted; we'll want to wait until these complete
# to kick of Birdseed2Csv
# wait until all jobs submitted are complete to proceed; absolutely terrible
# hack to get this done, I am ashamed; but this was less work/easier to figure
# out than turning Birdseed2Csv and Judgement into things I could submit via
# msub with a dependency list (which is likely the correct solution)
if (defined($ecm->dependency_list)) {
	my @dependency_list = split(/:/, $ecm->dependency_list);
	$debug_log->debug("dependency list: @dependency_list\n");
	print "Waiting for e-Genotyping concordance analysis jobs to finish on msub...\n";
	while (@dependency_list) {
		foreach my $i (0..$#dependency_list) {
			my $qstat_info = `qstat $dependency_list[$i]`;
			if ($qstat_info !~ m/\bR\b/ and $qstat_info !~ m/\bQ\b/) {
				print "Job ".$dependency_list[$i]." completed.\n";
				splice (@dependency_list, $i, 1);
			}
		}
		if (scalar @dependency_list > 0) { sleep(600) }
	}
}
else {
	print "Empty dependency list for EGenotypingConcordanceMsub; it's possible no jobs were submitted.\n"; 
}

# Generate concordance results
print "Running Judgement...\n";
my $judgement = Concordance::Judgement->new;
$judgement->project_name($options{project_name});
$judgement->output_csv($$."_judgement.csv");
$judgement->samples($samples_ref);
$judgement->birdseed_txt_dir(".");
# make sure the @ in the email address is escaped, otherwise the system call is unhappy
$options{'results-email'} =~ s/@/\\@/g;
$judgement->results_email_address($options{'results-email'});
$judgement->execute;

=head1 NAME

ConcordanceAnalysisPipeline - perform concordance analysis on SOLiD or Illumina data

=head1 SYNOPSIS

ConcordanceAnalysisPipeline.pl [options] [file ...]

Options:
-config			path to the configuration path
-raw_bs_dir		path to the directory containing the raw birdseed files
-project		the name of the project for these birdseed files
-convert-enc	option to convert genotype encoding
-help			brief help message
-man			full documentation

=head1 OPTIONS

=over 8

=item B<-run-id-list>

The path to the file containing the run IDs, one per line.

=item B<-prep-result-path>

The path to the file containing the concordance prep results.

=item B<--snp-array-dir>

The path to the directory containing the SNP array (.birdseed)files.

=item B<--probelist-path>

The path to the probelist file.

=item B<-project-name>

The name of the project, used for the Judgement report.

=item B<--config-path>

The path to the file containing the concordance pipeline configuration items.

=item B<--seq-type>

Specify whether this is SOLiD or Illumina data.

=item B<--results-email>

Specifiy the [list of] email address, or alias, to send the Judgement results CSV.

=item B<--no-lims>

This flag indicates whether to query LIMS using the run ID list, or load all data directly from the file.  The data will be loaded from the file provided for B<-run-id-list>.  It expects a CSV with the following columns (N.B. - no header values are required): run_id, snp_array, sample_id, result_path.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<ConcordanceAnalysisPipeline> will provide concordance analysis on SOLiD or Illumina data for a given list of run IDs.

=cut
