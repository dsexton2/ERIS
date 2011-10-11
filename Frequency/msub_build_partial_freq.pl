#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use strict;
use warnings;
use diagnostics;
use Inline Ruby => 'require "/stornext/snfs5/next-gen/Illumina/ipipe/lib/Scheduler.rb"';

if ($#ARGV != 0) { die "Usage: perl msub_build_partial_freq.pl /path/to/xml/file.xml\n" }

my $command = "/users/p-qc/dev/Concordance/Frequency/build_partial_freq.pl ".$ARGV[0];
(my $job_name = $ARGV[0]) =~ s/.*\/([^\/]+)\.xml/$1/;

my $scheduler = new Scheduler($job_name, $command);
$scheduler->setMemory(28000);
$scheduler->setNodeCores(2);
$scheduler->setPriority('normal');
$scheduler->runCommand;
