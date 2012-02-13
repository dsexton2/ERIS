#!/hgsc_software/perl/latest/bin/perl

use warnings;
use strict;
use diagnostics;

use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
	\%options,
	'full-path-to-script=s',
	'script-options=s',
	'cores=i',
	'memory-in-mb=i',
	'priority=s',
	'help|?',
	'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

my $cmd = "perl -I/users/p-qc/dev_concordance_pipeline/ ".$options{'full-path-to-script'}." ".$options{'script-options'};

print $cmd."\n";
exit;

my $scheduler = Concordance::Common::Scheduler->new;
$scheduler->command($cmd);
$scheduler->job_name_prefix("sampleJobPrefix");
$scheduler->cores($options{'cores'});
$scheduler->memory($options{'memory-in-mb'});
$scheduler->priority($options{'priority'});
$scheduler->execute;
