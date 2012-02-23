#!/hgsc_software/perl/latest/bin/perl

use warnings;
use strict;
use diagnostics;

if ($#ARGV < 2) { die "usage: perl get_common_rsids_from_annot.pl ".
    "/path/to/file/to/match.txt ".
    "/path/to/probelist.txt ".
    "/path/to/output/file.txt ".
    "\"separator\" ".
    "zero_indexed_rsId_column_number\n";
}

my @rsIds; # will contain list of rsIds from file

# build regex based on separator and column number inputs
my $separator = $ARGV[3];
my $rsid_col_number = $ARGV[4];

my $regex = "^";
foreach my $i (0..$rsid_col_number) {
    my $regex_to_append = "[^".$separator."]+";
    if ($i == $rsid_col_number) {
        $regex_to_append = "(".$regex_to_append.")";
    }
    $regex_to_append .= $separator;
    $regex .= $regex_to_append;
}
$regex .= ".*\$";

print "using regex $regex\n";

open(FIN, $ARGV[0]) or die $!;
while (my $line = <FIN>) {
    chomp($line);
    $line =~ m/$regex/;
    push @rsIds, $1;
}
close(FIN);

# now match annotation rsIds against probelist file
# print out lines from probelist file with matching rsID
my %rsIds = map { $_ => 1 } @rsIds;
open(FIN, $ARGV[1]) or die $!;
open(FOUT, ">".$ARGV[2]) or die $!;
while (my $line = <FIN>) {
    chomp($line);
    $line =~ m/^[^\t]+\t[^\t]+\t([^\t]+)\t.*$/;
    # throw the array into a hash for ease of lookup
    if (exists $rsIds{$1}) {
        print FOUT $line."\n";
    }
}
close(FIN);
close(FOUT);
