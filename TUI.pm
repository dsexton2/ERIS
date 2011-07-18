package Concordance::TUI;

use warnings;
use strict;
use Config::General;
use Log::Log4perl;
use Term::ReadLine;
use Concordance::BuildGeliAndBS;


sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{CSVFILE} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

sub csv_file {
	my $self = shift;
	if (@_) { $self->{CSVFILE} = shift; }
	return $self->{CSVFILE};
}

sub read_and_validate_input {
	my $prompt = undef;
	my $validation_pattern = undef;
	if (@_) {
		$prompt = shift;
		$validation_pattern = shift;
	}
	my $term = Term::ReadLine->new("");
	my $input = $term->readline($prompt);
	while ($input !~ /$validation_pattern/) {
		print "$input failed validation on $validation_pattern\n";
		$input = $term->readline($prompt);	
	}
	return $input;
}

sub __test_parm__ {
	if (!@_) { return 0; }
	foreach my $path (@_) {
		if (!-e $path) {
			$error_log->error("\n");
			return 0;
		}
	}
	return 1;
}

sub build_geli_and_bs {
	my $build = Concordance::BuildGeliAndBS->new;
	$build->path(read_and_validate_input("*.birdseed.data.txt files path: ", '[^\0]+'));
	$build->path(read_and_validate_input("Sample name: ", '[^\0]+'));
	$build->path(read_and_validate_input("SNP60 definition path: ", '\w+.csv$'));
	$build->path(read_and_validate_input("Sequence dictionary path: ", '\w+.dict$'));
	$build->path(read_and_validate_input("Reference path: ", '\w+.fasta$'));
	$build->path(read_and_validate_input("Output likelihoods: ", 'False|True'));
	#$build->build_geli;
	#$build->build_bs;
}

sub bs_2_birdseed {
	my $bs = Concordance::Bs2birdseed->new;
	$bs->path(read_and_validate_input("*.bs file path: ", '[^\0]+'));
	$bs->path(read_and_validate_input("Project name: ", '[^\0]+'));
	#$bs->convert_bs_to_birdseed;
	#$bs->move_birdseed_to_project_dir;
}

sub egt_ill_prep {
	my $egt = Concordance::EGtIllPrep->new;
	$egt->path(read_and_validate_input("eGT_Ill_prep input csv path: ", '\w+.csv$'));
	$egt->path(read_and_validate_input("gGT_Ill_prep output txt path: ", '\w+.txt$'));
	#$egt->generate_fastq_list;
}

sub bsub_illumina_egeno {
	my $bsub = Concordance::BsubIlluminaEgeno->new;
	$bsub->path(read_and_validate_input("bsub_Illumina_eGeno e_geno_list path: ", '\w+.fastq'));
	$bsub->path(read_and_validate_input("bsub_Illumina_eGeno snp array directory: ", '[^\0]+'));
	#$bsub->submit_to_bsub;
}

sub birdseed_2_csv {
	my $b2c = Concordance::Birdseed2csv->new;
	$b2c->path(read_and_validate_input("birdseed_2_csv *.birdseed.txt directory: ", '[^\0]+'));
	#$b2c->generate_csv;
}

1;
