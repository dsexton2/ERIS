#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;
use Concordance::Common::Scheduler;
use Concordance::Utils;
use File::Basename;

if (@ARGV != 2) {
    die "usage: msub_wgl_rawbs_conversion.pl /path/to/wgl/rawbs/dir /path/to/probelist\n";
}

my $wgl_rawbs_dir = $ARGV[0];
my $probelist_file = $ARGV[1];

if (!-e $wgl_rawbs_dir) {
    die "DNE: $wgl_rawbs_dir\n";
}
if (!-e $probelist_file) {
    die "DNE: $probelist_file\n";
}

my @wgl_rawbs_files = Concordance::Utils->get_file_list($wgl_rawbs_dir, "txt");
if ($#wgl_rawbs_files == -1) { die "No .txt files found in $wgl_rawbs_dir\n" }

foreach my $wgl_rawbs_file (@wgl_rawbs_files) {
    my $cmd = "perl /users/p-qc/production_concordance_pipeline/Concordance/one_off_scripts/convert_wgl_raw.pl $wgl_rawbs_file $probelist_file";
    my $scheduler = Concordance::Common::Scheduler->new;
    $scheduler->command($cmd);
    $scheduler->job_name_prefix(basename($wgl_rawbs_file)."_wgl_rawbs_convert".$$);
    $scheduler->cores(2);
    $scheduler->memory(2000);
    $scheduler->priority("normal");
    $scheduler->execute;
    sleep(1);
}
