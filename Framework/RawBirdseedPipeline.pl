#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::Bs2birdseed;
use Concordance::ConvertRawBirdseedGenotypeEncoding;
use Concordance::GeliToBs;
use Concordance::RawBsToGeli;
use Getopt::Long;
use Pod::Usage;

pod2usage(-exitstatus => 0) if (@ARGV == 0);

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");            
}
my $debug_log = Log::Log4perl->get_logger("debugLogger"); 
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");
my $error_log = Log::Log4perl->get_logger("errorLogger");

my $help, my $man;
my $config_file_path = '';
my $raw_birdseed_dir = '';
my $project_name = '';
my $convert_geno_enc_flag = '';

GetOptions
	(
		'help|?' => \$help,
		man => \$man,
		'config=s' => \$config_file_path, 
		'raw_bs_dir=s' => \$raw_birdseed_dir,
		'project=s' => \$project_name,
		'convert-enc' => \$convert_geno_enc_flag
	) or pod2usage(1);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

pod2usage(-exitstatus => 0, -verbose => 1) if (!$config_file_path or !$raw_birdseed_dir or !$project_name);

if (!-e $config_file_path) { croak $config_file_path.": ".$! }
if (!-e $raw_birdseed_dir) { croak $raw_birdseed_dir.": ".$! }

my %config = new Config::General($config_file_path)->getall;

my @dependency_list;

if ($convert_geno_enc_flag) {
	print "Converting Illumina genotype encoding to birdseed encoding ... \n";
	my $convert_geno_enc = Concordance::ConvertRawBirdseedGenotypeEncoding->new;
	$convert_geno_enc->path($raw_birdseed_dir);
	$convert_geno_enc->execute;

	my @dependency_list = split(/:/, $convert_geno_enc->dependency_list);
	if (@dependency_list != 0) {
		$debug_log->debug("RawBsToGeli dependency list: @dependency_list\n");
		&wait_for_jobs_to_finish("RawBsToGeli", \@dependency_list);
	}
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

=head1 NAME

RawBirdseedPipeline - prepare raw birdseed files for concordance analysis

=head1 SYNOPSIS

RawBirdseedPipeline.pl [options] [file ...]

Options:
-config			path to the configuration path
-raw_bs_dir		path to the directory containing the raw birdseed files
-project		the name of the project for these birdseed files
-convert-enc	option to convert genotype encoding
-help			brief help message
-man			full documentation

=head1 OPTIONS

=over 8

=item B<-config>

The path to the configuration file.

=item B<-raw_bs_dir>

The path to the directory containing the raw birdseed files to be processed.

=item B<-project>

The name of the project to which these birdseed files belong.

=item B<-convert-enc>

Convert the genotype encoding prior to processing the raw birdseed files.

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<RawBirdseedPipeline> will process a directory of raw birdseed files to prepare
them for use by the concordance analysis pipeline.

=cut
