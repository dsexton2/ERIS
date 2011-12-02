#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::Bs2birdseed;
use Concordance::ConvertRawBirdseedGenotypeEncoding;
use Concordance::GeliToBs;
use Concordance::RawBsToGeli;

if (scalar @ARGV != 3) {
	die "Usage: perl RawBirdseedPipeline.pl ".
		"/path/to/config/file ".
		"/path/to/raw_birdseed_dir ".
		"project_name ".
		"\n";
}

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");            
}
my $debug_log = Log::Log4perl->get_logger("debugLogger"); 
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");
my $error_log = Log::Log4perl->get_logger("errorLogger");

my $config_file_path = $ARGV[0];
my $raw_birdseed_dir = $ARGV[1];
my $project_name = $ARGV[2];

if (!-e $config_file_path) { croak $! }
if (!-e $raw_birdseed_dir) { croak $! }

my %config = new Config::General($config_file_path)->getall;

print "Converting Illumina genotype encoding to birdseed encoding ... \n";
my $convert_geno_enc = Concordance::ConvertRawBirdseedGenotypeEncoding->new;
$convert_geno_enc->path($raw_birdseed_dir);
$convert_geno_enc->execute;

my @dependency_list = split(/:/, $convert_geno_enc->dependency_list);
if (@dependency_list != 0) {
	$debug_log->debug("RawBsToGeli dependency list: @dependency_list\n");
	&wait_for_jobs_to_finish("RawBsToGeli", \@dependency_list);
}

print "Converting raw birdseed files to geli files ... \n";
my $rbtg = Concordance::RawBsToGeli->new;
$rbtg->config(\%config);
$rbtg->raw_birdseed_dir($raw_birdseed_dir);
$rbtg->project_name($project_name);
$rbtg->execute;

@dependency_list = split(/:/, $rbtg->dependency_list);
if (@dependency_list != 0) {
	$debug_log->debug("RawBsToGeli dependency list: @dependency_list\n");
	&wait_for_jobs_to_finish("RawBsToGeli", \@dependency_list);
}

print "Converting geli files to bs files ... \n";
my $gtb = Concordance::GeliToBs->new;
$gtb->config(\%config);
$gtb->geli_dir($raw_birdseed_dir);
$gtb->execute;

@dependency_list = split(/:/, $rbtg->dependency_list);
if (@dependency_list != 0) {
	$debug_log->debug("GeliToBs dependency list: @dependency_list\n");
	&wait_for_jobs_to_finish("GeliToBs", \@dependency_list);
}

print "Converting bs files to birdseed files ... \n";
my $bs2birdseed = Concordance::Bs2birdseed->new;
$bs2birdseed->path($raw_birdseed_dir);
$bs2birdseed->execute;

sub wait_for_jobs_to_finish {
	my $description = shift;
	my $dependency_list = shift;

	print "Waiting for $description jobs to finish on msub...\n";

	if (@$dependency_list[0] eq "") { splice(@$dependency_list, 0, 1) }
	while (@$dependency_list) {
		foreach my $i (0..$#$dependency_list) {
			my $qstat_info = `qstat @$dependency_list[$i]`;
			if ($qstat_info !~ m/\bR\b/ and $qstat_info !~ m/\bQ\b/) {
				print "Job ".@$dependency_list[$i]." completed.\n";
				splice (@$dependency_list, $i, 1);
			}
		}
		if (scalar @$dependency_list > 0) { sleep(600) }
	}
}
