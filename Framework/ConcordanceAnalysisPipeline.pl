#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

# ARGV[0] - run_id_list for LIMS webservice query
# ARGV[1] - output_txt_path for EGtIllPrep results
# ARGV[2] - SNP array directory
# ARGV[3] - path to probelist
# ARGV[4] - project name, which determines Judgement CSV headers
# ARGV[5] - path to configuration file

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

pod2usage(-exitstatus => 0) if (@ARGV == 0);

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");
my $error_log = Log::Log4perl->get_logger("errorLogger");

# 1. Run LIMS webservice query
# 2. EGtIllPrep - Illumina eGenotyping concordance preparation
# 3. EGenotypingConcordanceMsub - Submit concordance analysis jobs to MOAB
# 4. Birdseed2Csv - Prepare concordance results for Judgement
# 5. Judgement - Generate concordance results

my $run_id_list_path = '';
my $prep_result_path = '';
my $SNP_array_directory_path = '';
my $probelist_path = '';
my $project_name = '';
my $config_file_path = '';
my $sequencing_type = '';
my $no_lims = '';
my $help, my $man;

GetOptions
		(
			'run-id-list=s' => \$run_id_list_path,
			'prep-result-path=s' => \$prep_result_path,
			'snp-array-dir=s' => \$SNP_array_directory_path,
			'probelist-path=s' => \$probelist_path,
			'project-name=s' => \$project_name,
			'config-path=s' => \$config_file_path,
			'seq-type=s' => \$sequencing_type,
			'no-lims' => \$no_lims,
			'help|?' => \$help,
			'man' => \$man
		) or pod2usage(-verbose => 1);

pod2usage(-exitstatus => 0, -verbose => 1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# if any 'mandatory' options are missing, exit with usage
if (!$run_id_list_path or !$SNP_array_directory_path
	or !$probelist_path or !$project_name or !$config_file_path or !$sequencing_type) {
pod2usage(-exitstatus => 0, -verbose => 1);
}

# validate the input
if (!-e $run_id_list_path) {
	print "run-id-list DNE: $run_id_list_path\n";
	exit(0);
}
if (!-e $SNP_array_directory_path) {
	print "snp-array-dir DNE: $SNP_array_directory_path\n";
	exit(0);
}
if (!-e $probelist_path) {
	print "probelist-path DNE: $probelist_path\n";
	exit(0);
}
if (!-e $config_file_path) {
	print "config-path DNE: $config_file_path";
	exit(0);
}
$sequencing_type = lc $sequencing_type;
if ($sequencing_type ne "solid" and $sequencing_type ne "illumina") {
	print "Bad value for seq-type: $sequencing_type.  Possible values are 'solid' or 'illumina'.\n";
	exit(0);
}

# touching the $prep_result_path ensures that we can write to it and that it exists
eval { touch($prep_result_path) };
if ($@) { croak $@ }

# Run LIMS webservice query
my %samples;
if (!$no_lims) {
	open(FIN, $run_id_list_path) or croak $!;
	my $run_id_list = do { local $/; <FIN> };
	close(FIN) or carp $!;
	$run_id_list =~ s/\n/,/g;
	$run_id_list =~ s/(.*),/$1/;
	%samples = Concordance::Utils->populate_sample_info_hash($run_id_list);
}
else {
	# hack to deal with old Illumina data lacking run IDs
	%samples = Concordance::Utils->populate_samples_from_csv($run_id_list_path);
}

# Load configuration file
my %config = new Config::General($config_file_path)->getall;

my $samples_ref;

if ($sequencing_type eq "illumina") {
print "Running EGtIllPrep...\n";
	# Illumina eGenotyping concordance preparation
	my $egtIllPrep = Concordance::EGtIllPrep->new;
	$egtIllPrep->samples(\%samples);
	$egtIllPrep->output_txt_path($prep_result_path);
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
$ecm->snp_array_dir($SNP_array_directory_path);
$ecm->probe_list($probelist_path);
$ecm->sequencing_type($sequencing_type);
$ecm->samples($samples_ref);
$ecm->execute;

# get the job IDs of the jobs submitted; we'll want to wait until these complete
# to kick of Birdseed2Csv
my @dependency_list = split(/:/, $ecm->dependency_list);
$debug_log->debug("dependency list: @dependency_list\n");
if ($dependency_list[0] eq "") { splice(@dependency_list, 0, 1) }

# wait until all jobs submitted are complete to proceed; absolutely terrible
# hack to get this done, I am ashamed; but this was less work/easier to figure
# out than turning Birdseed2Csv and Judgement into things I could submit via
# msub with a dependency list (which is likely the correct solution)
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

# Generate concordance results
print "Running Judgement...\n";
my $judgement = Concordance::Judgement->new;
$judgement->project_name($project_name);
$judgement->output_csv($$."_judgement.csv");
$judgement->samples($samples_ref);
$judgement->judge;

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

=item B<--no-lims>

This flag indicates whether to query LIMS using the run ID list, or load all data directly from the file.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<ConcordanceAnalysisPipeline> will provide concordance analysis on SOLiD or Illumina data for a given list of run IDs.

=cut
