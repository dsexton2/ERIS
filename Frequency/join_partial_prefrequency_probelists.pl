use File::Slurp;

my @files = glob("*.prefrequency_probelist.part");

my $outfile = "prefrequency_probelist";

foreach my $file (@files) {
    my $text = read_file($file);
    write_file( $outfile, {append => 1 }, $text ) ; 
}
