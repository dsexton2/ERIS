#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;

use Carp;
use Log::Log4perl;

if (@ARGV != 1) {
	croak "usage: convert_raw_birdseed_genotype_encoding.pl ".
	"/path/to/raw_birdseed_file/to/convert ".
	"\n";
}

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");            
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

my $raw_bs_file = $ARGV[0];

if (!-e $raw_bs_file) {
	$error_log->error("No such file: $raw_bs_file\n");
	croak "No such file: $raw_bs_file\n";
}

$debug_log->debug("Processing file: $raw_bs_file\n");

open(FIN, $raw_bs_file) or croak $!;
(my $outfile = $raw_bs_file) =~ s/(\.txt)$/\.birdseed\.data\.txt/;
open(FOUT,">".$outfile) or croak $!;
open(FOUT_ERR, ">".$outfile.".e") or croak $!;

while (my $line = <FIN>) {
	chomp($line);
	if ($line =~ m/^(#|Probe)/) {
		print FOUT $line."\n";
	}
	else {
		my @tab_delimited_cols = split(/\t/, $line);
		if (@tab_delimited_cols != 3) {
			print FOUT_ERR "1\t".(scalar @tab_delimited_cols)."\t$raw_bs_file\n";
			next;
		}
		if ($tab_delimited_cols[1] eq "AA") {
			print FOUT "$tab_delimited_cols[0]\t0\t$tab_delimited_cols[2]\n";
		}
		elsif ($tab_delimited_cols[1] eq "AB") {
			print FOUT "$tab_delimited_cols[0]\t1\t$tab_delimited_cols[2]\n";
		}
		elsif ($tab_delimited_cols[1] eq "BB") {
			print FOUT "$tab_delimited_cols[0]\t2\t$tab_delimited_cols[2]\n";
		}
		else {
			print FOUT_ERR "$tab_delimited_cols[0]\t$tab_delimited_cols[1]\t$raw_bs_file\n";
		}
	}
}

close(FIN) or carp $!;
close(FOUT) or carp $!;
close(FOUT_ERR) or carp $!;
