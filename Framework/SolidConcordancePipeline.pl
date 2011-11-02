#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

# ARGV[0] - run_id_list for LIMS webservice query
# ARGV[1] - output_txt_path for EGenoSolid results
# ARGV[2] - SNP array directory
# ARGV[3] - path to probelist
# ARGV[4] - project name, which determines Judgement CSV headers

if (scalar @ARGV != 6) {
	die "Usage: perl IlluminaConcordancePipeline.pl ".
		"path/to/run_id_list ".
		"path/to/EGenoSolid/results ".
		"/path/to/SNP/array/directory ".
		"/path/to/probelist ".
		"project_name_to_determine_judgement_headers ".
		"/path/to/config/file".
		"\n";
}

use Carp;
use Concordance::Birdseed2Csv;
use Concordance::EGenotypingConcordanceMsub;
use Concordance::EGenoSolid;
use Concordance::Judgement;
use Concordance::Utils;
use Concordance::Common::Scheduler;
use Config::General;

# 1. Run LIMS webservice query
# 2. EGenoSolid - SOLiD eGenotyping concordance preparation
# 3. Bam2csfasta - generate any missing csfasta files from step two. (optional)
# 4. EGenotypingConcordanceMsub - Submit concordance analysis jobs to MOAB
# 5. Birdseed2Csv - Prepare concordance results for Judgement
# 6. Judgement - Generate concordance results

my $run_id_list_path = $ARGV[0];
my $egenoSolid_result_path = $ARGV[1];
my $SNP_array_directory_path = $ARGV[2];
my $probelist_path = $ARGV[3];
my $project_name = $ARGV[4];
my $config_file_path = $ARGV[5];

# validate the input
if (!-e $run_id_list_path) { croak $! }
if (!-e $SNP_array_directory_path) { croak $! }
if (!-e $probelist_path) { croak $! }
if (!-e $config_file_path) { croak $! }

open(FIN, $run_id_list_path) or croak $!;
my $run_id_list = do { local $/; <FIN> };
close(FIN) or carp $!;
$run_id_list =~ s/\n/,/g;
$run_id_list =~ s/(.*),/$1/;

# Run LIMS webservice query
my %samples = Concordance::Utils->populate_sample_info_hash($run_id_list);

# Load configuration file
my %config = new Config::General($config_file_path)->getall;

# SOLiD eGenotyping concordance preparation
# this may call Bam2csfasta if errors are present
my $egs = Concordance::EGenoSolid->new;
$egs->config(\%config);
$egs->output_path($egenoSolid_result_path);
$egs->error_path($$."_".int(rand(1000))."_egenoSolid_errors.csv");
$egs->samples(\%samples);
$egs->execute;

# Submit concordance analysis jobs to MOAB
print "Running EGenotypingConcordanceMsub...\n";
my $ecm = Concordance::EGenotypingConcordanceMsub->new;
$ecm->egeno_list($egenoSolid_result_path);
$ecm->snp_array($SNP_array_directory_path);
$ecm->probe_list($probelist_path);
$ecm->sequencing_type("solid");
$ecm->execute;

# get the job IDs of the jobs submitted; we'll want to wait until these complete
# to kick of Birdseed2Csv
my @dependency_list = split(/:/, $ecm->dependency_list);
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

my $birdseed_out_csv = $$."_".int(rand(1000))."_birdseed2csv_out.csv";

# Prepare concordance results for judgement
print "Running Birdseed2Csv...\n";
my $b2c = Concordance::Birdseed2Csv->new;
$b2c->path(".");
$b2c->output_csv_file($birdseed_out_csv);
$b2c->project_name($project_name);
$b2c->samples(\%samples);

# Generate concordance results
print "Running Judgement...\n";
my $judgement = Concordance::Judgement->new;
$judgement->project_name($project_name);
$judgement->input_csv_path($birdseed_out_csv);
$judgement->snp_array_dir($SNP_array_directory_path);
$judgement->output_csv($$."_judgement.csv");
$judgement->samples(\%samples);
