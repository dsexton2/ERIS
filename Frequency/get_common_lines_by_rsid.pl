if ($#ARGV < 2) { die "usage: perl get_common_rsids_from_annot.pl ".
	"/path/to/file/to/match.txt ".
	"/path/to/probelist.txt ".
	"/path/to/output/file.txt" } 

my @rsIds; # will contain list of rsIds from file

open(FIN, $ARGV[0]) or die $!;
while (my $line = <FIN>) {
	chomp($line);
	$line =~ m/^[^\t]+\t[^\t]+\t([^\t]+)\t.*$/;
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
