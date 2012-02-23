use strict;
use warnings;
use diagnostics;
use Concordance::EGenoSolid;
use Concordance::EGenotypingConcordanceMsub;
use Concordance::Utils;
use File::Copy;
use File::Touch;
use Config::General;

# Contamination simulation using reads from large csfasta to contaminate small
# csfasta at 0.1% (318,000), 0.5% (1,590,000), 1% (3,180,000), 5% (15,900,000),
# 10% (31,800,000) to test contamination script. Make sure this is put in a new
# csfasta. 

if (scalar @ARGV != 4) {
    die "USAGE: perl contamination_test.pl run_id_contamination_target ".
    "/path/to/contamination/source/file ".
    "/path/to/snp/array/dir ".
    "/path/to/probelist/file ".
    "\n";
}

my $run_id_contamination_target = $ARGV[0];
my $contamination_source_file = $ARGV[1];
my $snp_array_dir = $ARGV[2];
my $probe_list_path = $ARGV[3];

my %config = new Config::General("/users/p-qc/dev_concordance_pipeline/tertiary_pipeline.cfg")->getall;
my $working_dir = "/users/p-qc/testdata_pipeline/spike_in/";
my @test_thresholds = qw(318000 1590000 3180000 15900000 31800000);
my @csfasta_files;


if (!-e $contamination_source_file) { die "$contamination_source_file DNE\n" }

my %sample_contamination_target = Concordance::Utils->populate_sample_info_hash($run_id_contamination_target);
if (scalar keys %sample_contamination_target == 0) {
    print "LIMS query returned nothing for run ID $run_id_contamination_target\n"; 
    exit;
}

# EGenoSolid prep to get the CSFASTA path
my $egs = Concordance::EGenoSolid->new;
$egs->config(\%config);
$egs->samples(\%sample_contamination_target);
$egs->execute;
%sample_contamination_target = %{ ($egs->samples) };

# make several new CSFASTA files, based on directions above
# test1: 0.1% (318,000)
foreach my $test_threshold (@test_thresholds) {
    print "Setting up test for test threshold $test_threshold ...\n";
    my $contaminated_csfasta_file = $working_dir."test_".$test_threshold.".csfasta";
    eval { open(FIN, $contamination_source_file) };
    if ($@) {
        print "Failed to open ".$contamination_source_file." for reading: $@\n";
        next;
    }
    print "Copying ".$sample_contamination_target{$run_id_contamination_target}->result_path." to ".$contaminated_csfasta_file. " ...\n";
    eval { copy($sample_contamination_target{$run_id_contamination_target}->result_path, $contaminated_csfasta_file) };
    if ($@) {
        print "Failed to copy ".$sample_contamination_target{$run_id_contamination_target}->result_path." to ".$contaminated_csfasta_file.": $@\n";
        next;
    }
    eval { open(FOUT, ">>".$contaminated_csfasta_file) };
    if ($@) {
        print "Failed to open ".$contaminated_csfasta_file." for writing: $@\n";
        next;
    }
    while ($test_threshold > 0) {
        my $line = <FIN>;
        print FOUT $line; 
        $test_threshold--;
    }
    close(FIN) or warn $!;
    close(FOUT) or warn $!;
    push @csfasta_files, $contaminated_csfasta_file;
}

# submit to Moab jobs to generate contamination calculation for each of the CSFASTA files
@test_thresholds = qw(318000 1590000 3180000 15900000 31800000);

my $ecm = Concordance::EGenotypingConcordanceMsub->new;
$ecm->snp_array_dir($snp_array_dir);
$ecm->probe_list($probe_list_path);
$ecm->sequencing_type("solid");
$ecm->config(\%config);
foreach my $csfasta_file (@csfasta_files) {
    $sample_contamination_target{$run_id_contamination_target}->run_id((shift @test_thresholds));
    $sample_contamination_target{$run_id_contamination_target}->result_path($csfasta_file);
    $ecm->samples(\%sample_contamination_target);
    $ecm->execute;
}
