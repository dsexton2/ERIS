#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use strict;
use warnings;
use diagnostics;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

my $command = "/users/p-qc/dev/Concordance/Frequency/hapmap.pl ";
my $job_name = "add_freq_to_probelist";

my $scheduler = new Scheduler($job_name, $command);
$scheduler->setMemory(28000);
$scheduler->setNodeCores(2);
$scheduler->setPriority('normal');
$scheduler->runCommand;
