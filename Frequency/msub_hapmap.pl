#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use strict;
use warnings;
use diagnostics;
use Concordance::Common::Scheduler;

if ($#ARGV != 1) { die "usage: perl msub_hapmap.pl /path/to/prefrequency/probelist /path/to/output/probelist\n" }

my $prefrequency_probelist = $ARGV[0];
my $probelist = $ARGV[1];

my $command = "/users/p-qc/production_concordance_pipeline/Concordance/Frequency/hapmap.pl ".
    $prefrequency_probelist." ".$probelist;
my $job_name = "add_freq_to_probelist";

my $scheduler = Concordance::Common::Scheduler->new;
$scheduler->command($command);
$scheduler->job_name_prefix($job_name);
$scheduler->cores(2);
$scheduler->memory(28000);
$scheduler->priority("normal");
$scheduler->execute;
