use strict;
use warnings;
use Concordance::Common::Scheduler;
use File::Basename;

if (@ARGV != 1) { die "Usage: perl -I/path/to/Concordance/software bfast_remap.pl /path/to/files/to/remap\n" }

my $remap_dir = $ARGV[0];
if (!-e $remap_dir) { die "Bad path: $remap_dir\n" }

my @fastq_files = glob($remap_dir."/*.fastq");
my %unique_names;
foreach my $fastq_file (@fastq_files) {
    next unless $fastq_file =~ m/_\d\.filt\.fastq/;
    $fastq_file =~ s/_\d\.filt.fastq//;
    if (!exists($unique_names{$fastq_file})) {
        $unique_names{$fastq_file} = 1;
    }
}

if (!-e $remap_dir."/output/") { mkdir $remap_dir."/output/" or die $! }

foreach my $unique_name (keys %unique_names) {
    &msub_with_dependencies($unique_name);
}

sub msub_with_dependencies {
    my $fastq_file_base = shift;
    my $merged_fastq_file = $fastq_file_base.".merged.fastq";
    my $match_file = "./output/".$merged_fastq_file.".match";
    my $align_file = $match_file.".aln";
    my $sam_file = $align_file.".sam";
    my $bam_file = $sam_file.".bam";
    my $sorted_bam_file = $bam_file.".sorted.bam";
    my $dups_bam_file = $sorted_bam_file.".dups.bam";
    my $gatk_bam_file = $dups_bam_file.".gatk.bam";
    my $txt_file = $gatk_bam_file.".txt";

    my $cmd = "";
    my $dependency_id = "";

    # First we will need to merged *_1.filt.fastq and *_2.filt.fastq files into a single *.filt.fastq file
    $cmd = "ruby /stornext/snfs5/next-gen/solid/utilities/helpers/split_TGP.rb $fastq_file_base";
    $dependency_id = &submit_job($cmd, "", $fastq_file_base, "fastq_merge");

    # After fastq files are created then we will need to run bfast match with this command:
    $cmd = "/stornext/snfs5/next-gen/software/bfast/versions/bfast-0.6.4d/bfast/bfast match -A 1 -t -n 8 -f /stornext/snfs0/next-gen/solid/bf.references/h/hg37d5/hs37d5.fa -r $merged_fastq_file > $match_file";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "bfast_match");

    # The output from match will go into bfast localalign:
    $cmd = "/stornext/snfs5/next-gen/software/bfast/versions/bfast-0.6.4d/bfast/bfast localalign -A 1 -t -n 8 -f /stornext/snfs0/next-gen/solid/bf.references/h/hg37d5/hs37d5.fa -m $match_file > $align_file";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "bfast_align");

    # the output from local align will then go into bfast postprocess 
    $cmd = "/stornext/snfs5/next-gen/software/bfast/versions/bfast-0.6.4d/bfast/bfast postprocess -f /stornext/snfs0/next-gen/solid/bf.references/h/hg37d5/hs37d5.fa -i $align_file -a 3 -O 1 > $sam_file";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "bfast_postprocess");
    
    # the output from post process will then go into samtools:
    $cmd = "/stornext/snfs5/next-gen/software/jdk1.6.0_01/bin/java -Xmx22000M -jar /stornext/snfs5/next-gen/software/picard-tools/current/SamFormatConverter.jar TMP_DIR=/space1/tmp/ INPUT=$sam_file OUTPUT=$bam_file VALIDATION_STRINGENCY=STRICT";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "sam_format_converter");

    # The output from SamFormatConverter will go into SortSam
    $cmd = "/stornext/snfs5/next-gen/software/jdk1.6.0_01/bin/java -Xmx22000M -jar /stornext/snfs5/next-gen/software/picard-tools/current/SortSam.jar TMP_DIR=/space1/tmp/ INPUT=$bam_file OUTPUT=$sorted_bam_file SORT_ORDER=coordinate VALIDATION_STRINGENCY=STRICT";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "sort_sam");

    # the output from SortSam will go into MarkDuplicates
    $cmd = "/stornext/snfs5/next-gen/software/jdk1.6.0_01/bin/java -Xmx22000M -jar /stornext/snfs5/next-gen/software/picard-tools/current/MarkDuplicates.jar TMP_DIR=/space1/tmp/ INPUT=$sorted_bam_file OUTPUT=$dups_bam_file METRICS_FILE='./metric_file.picard' VERBOSITY=ERROR VALIDATION_STRINGENCY=STRICT";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "mark_duplicates");

    # The output from this will go into gatk
    $cmd = "perl /stornext/snfs0/next-gen/project_SNP_calling/software/recalibration_GATK_pipeline.pl $dups_bam_file $gatk_bam_file hg19+";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "recal_gatk_pipeline");

    # The output from this will go into read validator
    $cmd = "/stornext/snfs5/next-gen/software/jdk1.6.0_01/bin/java -Xmx22000M -jar /stornext/snfs5/next-gen/solid/hgsc.solid.pipeline/hgsc.bfast.pipe/java/raw.bam.reads.validator/raw.bam.reads.validator.jar $gatk_bam_file $merged_fastq_file $txt_file";
    $dependency_id = &submit_job($cmd, $dependency_id, $fastq_file_base, "reads_validator");
}

sub submit_job {
    (my $command, my $dependency_id, my $fastq_file_base, my $job_description) = @_;
    #  moab_resources: "nodes=1:ppn=8,mem=28000mb"
    my $scheduler = Concordance::Common::Scheduler->new;
    $scheduler->command($command);
    $scheduler->job_name_prefix($fastq_file_base."_".$$."_".int(rand(5000))."_".$job_description.".job");
    $scheduler->cores(8);
    $scheduler->memory(28000);
    $scheduler->priority("normal");
    $scheduler->dependency_list($dependency_id);
    $scheduler->execute;

    sleep(1);
    return $scheduler->job_id;
}
