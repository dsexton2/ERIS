#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use strict;
use warnings;
use diagnostics;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

if ($#ARGV != 1) { die "usage: perl msub_hapmap.pl /path/to/prefrequency/probelist /path/to/output/probelist\n" }

my $prefrequency_probelist = $ARGV[0];
my $probelist = $ARGV[1];

my $command = "/users/p-qc/dev/Concordance/Frequency/hapmap.pl ".
	$prefrequency_probelist." ".$probelist;
my $job_name = "add_freq_to_probelist";

my $scheduler = new Scheduler($job_name, $command);
$scheduler->setMemory(28000);
$scheduler->setNodeCores(2);
$scheduler->setPriority('normal');
$scheduler->runCommand;
