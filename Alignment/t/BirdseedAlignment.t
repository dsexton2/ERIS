use Concordance::Alignment::BirdseedAlignment;
use Test::More qw( no_plan );

use_ok( 'Concordance::Alignment::BirdseedAlignment' );

my $obj = Concordance::Alignment::BirdseedAlignment->new(
	rsId_col => 1,
	probelist_path =>
"/users/p-qc/concordance/eGeno_probes/hg19/illumina_probelist_20111031_1300",
	rsId_list_path => "/users/p-qc/temp",
	birdseed_path => "/users/p-qc",
);
