#!/usr/bin/perl -w

=head1 NAME

bam2csfasta

=head1 SYNOPSIS

perl bam2csfasta.pl foo.csv

=head1 DESCRIPTION

This script takes a CSV file with sample ID / .bam path pairs.  It
iterates on each line of this CSV file, calling a JAR to convert the
.bam files into .csfasta files.  It also produces a new CSV file with
sample ID / .csfasta path pairs.

=head1 LICENSE

This script is the property of Baylor College of Medecine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

my %config = new Config::General("tertiary_pipeline.cfg")->getall;

Log::Log4perl->init("log4perl.cfg");
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

if ($#ARGV == -1 || $ARGV[0] !~ /.+\.csv$/) {
	$error_log->error("This script requires a *.csv file as an argument.\n");
	exit;
}

open(CSV_FILE_BAM, $ARGV[0]);
open(CSV_FILE_CSFASTA, "> $ARGV[0].csfasta.csv");

while (<CSV_FILE_BAM>) {
	chomp;
	if($_ !~ /^(.*),+(.*)$/) { next; }
	my $sample_id = $1;
	my $input_bam_file = $2;
	if ($input_bam_file !~ /.bam$/) {
		print "Bad sample_id/input_bam_file pair: $sample_id\t$input_bam_file\n";
		next;
	}
	$input_bam_file =~ s/\.sorted\.dups\.rg//g;
	(my $output_csfasta_file = $input_bam_file) =~ s/bam$/csfasta/g;
	my $command = $config{"java"}." -Xmx2G -jar ".$config{"bam2csfastaJAR"}.
		" $input_bam_file".
		" >".
		" $output_csfasta_file";
	$debug_log->debug("Executing command: $command\n");
	print CSV_FILE_CSFASTA "$sample_id,$output_csfasta_file\n";
	#system($command);
}

close(CSV_FILE_BAM);
close(CSV_FILE_CSFASTA);
