#!/usr/bin/perl -w

##!/data/pipeline/code/production/bin/x86_64-linux/perl -w

# EXAMPLE to Run: "perl ./setIlluminaLaneStatus.pl 111017_SN820_0144_AD0DM2ACXX_1_ID03 EZENOTYPING_FINISHED EGENO_AVERAGE_CONCORDANCE 172160 EGENO_SELF_CONCORDANCE 47434" etc and so forth....

#INPUT:
# lane_barcode
# - Sequence name (ie, 111017_SN820_0144_AD0DM2ACXX_1_ID03).

# - EGENO_STATE
# The Following are name that you should accompany with values:
# - SAMPLE_EXTERNAL_ID
# - EGENO_JUDGEMENT
# - EGENO_AVERAGE_CONCORDANCE
# - EGENO_SELF_CONCORDANCE
# - EGENO_BEST_HIT_ID
# - EGENO_BEST_HIT_CONCORDANCE
# - EGENO_2ND_BEST_HIT_ID
# - EGENO_2ND_BEST_HIT_CONCORDANCE
# - EGENO_3RD_BEST_HIT_ID
# - EGENO_3RD_BEST_HIT_CONCORDANCE
# - EGENO_4TH_BEST_HIT_ID
# - EGENO_4TH_BEST_HIT_CONCORDANCE
# - EGENO_5TH_BEST_HIT_ID
# - EGENO_5TH_BEST_HIT_CONCORDANCE
# - EGENO_6TH_BEST_HIT_ID
# - EGENO_6TH_BEST_HIT_CONCORDANCE
# - EGENO_SNPS_TESTED
# - EGENO_SNPS_PASSING_COVERAGE
# - PERCENT_PREPHASING
# - EGENO_SNPS_PASSING_MATCH
# - PERCENT_CONTAMINATION

use strict;
use LWP;

if( @ARGV % 2 ) {
print "usage: $0 lane_barcode status <name/value pairs>\n";
exit;
}

my $ncbiURL ="http://gen2.hgsc.bcm.tmc.edu/ngenlims/setIlluminaLaneStatus.jsp?";
my $paraStr = "lane_barcode=" . $ARGV[0]."&status=".$ARGV[1];

my $i;
my $index=1;
for($i=2; $i<@ARGV;$i +=2){
    $paraStr .= "&key$index=" . $ARGV[$i] ."&value$index=".$ARGV[$i+1];
    $index++;
}

$ncbiURL="$ncbiURL$paraStr";

my $ua = LWP::UserAgent->new;
my $response=$ua->get($ncbiURL);

if(not $response->is_success ) {print "Error: Cannot connect\n"; exit(-1);}

my $textStr= $response->content;
$textStr=~/^\s*(.+)\s*$/;
$textStr=$1;
print "$textStr\n";
