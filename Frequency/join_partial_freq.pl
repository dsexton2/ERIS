use File::Slurp;

my @files = glob("*.freq");

my $outfile = "all_freq.fre";

foreach my $file (@files) {
	my $text = read_file($file);
	write_file( $outfile, {append => 1 }, $text ) ; 
}
