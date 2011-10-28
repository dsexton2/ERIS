#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use strict;
use warnings;
use diagnostics;
use Concordance::Common::Scheduler;

if ($#ARGV != 0) { die "Usage: perl msub_build_partial_freq.pl /path/to/xml/file.xml\n" }

my $command = "/users/p-qc/dev_concordance_pipeline/Concordance/Frequency/build_partial_freq.pl ".$ARGV[0];
(my $job_name = $ARGV[0]) =~ s/.*\/([^\/]+)\.xml/$1/;

my $scheduler = Concordance::Common::Scheduler->new;
$scheduler->command($command);
$scheduler->job_name_prefix($job_name);
$scheduler->cores(2);
$scheduler->memory(28000);
$scheduler->priority("normal");
$scheduler->execute;
