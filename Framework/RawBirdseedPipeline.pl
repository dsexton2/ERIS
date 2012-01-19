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

my %options = ();

GetOptions (
	'config=s', 
	'raw_bs_dir=s',
	'project=s',
	'convert-enc=s',
	'help|?',
	'man'
) or pod2usage(1);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});

if (!-e $options{'config'}) { croak $options{'config'}.": ".$! }
if (!-e $options{'raw_bs_dir'}) { croak $options{'raw_bs_dir'}.": ".$! }

my %config = new Config::General($options{'config'})->getall;

# combine the config hash and the options hash, write them out for debugging purposes
my %run_env = %config;
@run_env{ keys %options } = values %options;
Config::General::SaveConfig("/users/p-qc/log/config/config_".POSIX::strftime("%m%d%Y_%H%M%S", localtime).".cfg", \%run_env);

if ($options{'convert-enc'}) {
	print "Converting Illumina genotype encoding to birdseed encoding ... \n";
	my $convert_geno_enc = Concordance::ConvertRawBirdseedGenotypeEncoding->new;
	$convert_geno_enc->path($options{'raw_bs_dir'});
	$convert_geno_enc->execute;

	if (defined($convert_geno_enc->dependency_list)) {
		my @dependency_list = split(/:/, $convert_geno_enc->dependency_list);
		$debug_log->debug("RawBsToGeli dependency list: @dependency_list\n");
		&wait_for_jobs_to_finish("RawBsToGeli", \@dependency_list);
	}
}

print "Converting raw birdseed files to geli files ... \n";
my $rbtg = Concordance::RawBsToGeli->new;
$rbtg->config(\%config);
$rbtg->raw_bs_dir($options{'raw_bs_dir'});
$rbtg->project_name($options{'project'});
$rbtg->execute;

if (defined($rbtg->dependency_list)) {
	my @dependency_list = split(/:/, $rbtg->dependency_list);
	$debug_log->debug("RawBsToGeli dependency list: @dependency_list\n");
	&wait_for_jobs_to_finish("RawBsToGeli", \@dependency_list);
}

print "Converting geli files to bs files ... \n";
my $gtb = Concordance::GeliToBs->new;
$gtb->config(\%config);
$gtb->geli_dir($options{'raw_bs_dir'});
$gtb->execute;

if (defined($gtb->dependency_list)) {
	my @dependency_list = split(/:/, $gtb->dependency_list);
	$debug_log->debug("GeliToBs dependency list: @dependency_list\n");
	&wait_for_jobs_to_finish("GeliToBs", \@dependency_list);
}

print "Converting bs files to birdseed files ... \n";
my $bs2birdseed = Concordance::Bs2birdseed->new;
$bs2birdseed->path($options{'raw_bs_dir'});
$bs2birdseed->execute;

sub wait_for_jobs_to_finish {
	my $description = shift;
	my $dependency_list = shift;

	print "Waiting for $description jobs to finish on msub...\n";

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
