package Concordance::TUI;

use warnings;
use strict;
use feature 'switch';
use Config::General;
use Log::Log4perl;
use Term::ReadLine;
use Concordance::Bam2csfasta;
use Concordance::Birdseed2Csv;
use Concordance::Bs2birdseed;
use Concordance::BsubIlluminaEgeno;
use Concordance::BuildGeliAndBS;
use Concordance::Change_AA_to_0;
use Concordance::EGtIllPrep;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{CONFIGFILE} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

sub config_file {
	my $self = shift;
	if (@_) { $self->{CONFIGFILE} = shift; }
	return $self->{CONFIGFILE};
}

sub __read_and_validate_input__ {
	my $self = shift;
	my $prompt = undef;
	my $validation_pattern = undef;
	if (@_) {
		$prompt = shift;
		$validation_pattern = shift;
	}
	my $term = Term::ReadLine->new("");
	my $input = $term->readline($prompt.": ");
	chomp($input);
	while ($input !~ /$validation_pattern/) {
		print "$input failed validation on $validation_pattern\n";
		$input = $term->readline($prompt);	
	}
	$self->__add_to_hash__($prompt, $input);
	return $input;
}

sub __add_to_hash__ {
	if (@_) {
		my $self = shift;
		my $key = shift;
		my $value = shift;
		$self->{CONFIG}{$key} = $value;
		$self->__write_config_file__;
	}
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

sub __write_config_file__ {
	my $self = shift;
	open(CONFIG_OUT, ">".$self->config_file) || die "Couldn't open file for writing configuration items: ".$self->config_file."\n";
	my %config = $self->config;
	foreach my $key (sort (keys %config)) {
		print CONFIG_OUT $key." = ".$config{$key}."\n";
	}
	close CONFIG_OUT;
}

sub build_geli_and_bs {
	print "\nExecuting .birdseed.data.txt=>.geli=>.bs conversion...\n";
	my $self = shift;
	my $build = Concordance::BuildGeliAndBS->new;
	$build->path($self->__read_and_validate_input__("birdseed_data_txt_dir", '[^\0]+'));
	$self->__read_and_validate_input__("sample_name", '[^\0]+');
	$self->__read_and_validate_input__("snp60_definition_path", '\w+.csv$');
	$self->__read_and_validate_input__("sequence_dictionary_path", '\w+.dict$');
	$self->__read_and_validate_input__("reference_path", '\w+.fasta$');
	$self->__read_and_validate_input__("output_likelihoods", 'False|True');
	#$build->build_geli;
	#$build->build_bs;
}

sub bs_2_birdseed {
	print "\nExecuting .bs=>.birdseed conversion ...\n";
	my $self = shift;
	my $bs = Concordance::Bs2birdseed->new;
	$bs->path($self->__read_and_validate_input__("bs_file_dir", '[^\0]+'));
	$bs->project_name($self->__read_and_validate_input__("project_name", '[^\0]+'));
	#$bs->convert_bs_to_birdseed;
	#$bs->move_birdseed_to_project_dir;
}

sub egt_ill_prep {
	print "Executing eGT Illumina preparation ...\n";
	my $self = shift;
	my $egt = Concordance::EGtIllPrep->new;
	$egt->input_csv_path($self->__read_and_validate_input__("egt_ill_prep_input_csv_path", '\w+.csv$'));
	$egt->output_txt_path($self->__read_and_validate_input__("egt_ill_prep_output_txt_path", '\w+.txt$'));
	#$egt->generate_fastq_list;
}

sub msub_illumina_egeno {
	print "Executing Illumina job submissions to msub ...\n";
	my $self = shift;
	my $bsub = Concordance::BsubIlluminaEgeno->new;
	$bsub->e_geno_list($self->__read_and_validate_input__("egeno_list_path", '\w+.fastq'));
	$bsub->snp_array($self->__read_and_validate_input__("snp_array_dir", '[^\0]+'));
	#$bsub->submit_to_bsub;
}

sub birdseed_2_csv {
	print "Executing .birdseed=>CSV conversion ...\n";
	my $self = shift;
	my $b2c = Concordance::Birdseed2Csv->new;
	$b2c->path($self->__read_and_validate_input__("birdseed_txt_dir", '[^\0]+'));
	#$b2c->generate_csv;
}

sub bam_2_csfasta {
	print "Executing .bam=>.csfasta conversion ...\n";
	my $self = shift;
	my $bam = Concordance::Bam2csfasta->new;
	$bam->config($self->config);
	$bam->csv_file($self->__read_and_validate_input__("bam_csv_file", '\w+.csv'));
	#$bam->convert_bam_to_csfasta;
}

sub change_aa_to_0 {
	print "Executing AA... to 0... conversion ...\n";
	my $self = shift;
	my $change = Concordance::Change_AA_to_0->new;
	$change->path($self->__read_and_validate_input__("changeaato0_txt_dir", '[^\0]+'));
	#$change->change_aa_to_0;
}

sub __print_usage__ {
	print "\n".
		"[1] Run entire Illumina concordance process.\n".
		"[2] Execute Bam to Csfasta conversion.\n".
		"[3] Execute change AA... to 0... conversion.\n".
		"[4] Execute build GELI to BS conversion.\n".
		"[5] Execute BS to Birdseed conversion.\n".
		"[6] Execute eGT Illumina preparation.\n".
		"[7] Execute Illumina eGeno msub scheduler.\n".
		"[8] Execute Birdseed to CSV conversion.\n".
		"[0] Exit.\n".
		"\n";
}

sub execute {
	my $self = shift;
	__print_usage__;
	my $term = Term::ReadLine->new("user_input");
	while (my $input = $term->readline("\nEnter (numeric) choice: ")) {
		given ($input) {
			when ($input == 1) {
				$self->build_geli_and_bs;
				$self->bs_2_birdseed;
				$self->egt_ill_prep;
				$self->msub_illumina_egeno;
				$self->birdseed_2_csv;
			}
			when ($input == 2) { $self->bam_2_csfasta; }
			when ($input == 3) { $self->change_aa_to_0; }
			when ($input == 4) { $self->build_geli_and_bs; }
			when ($input == 5) { $self->bs_2_birdseed; }
			when ($input == 6) { $self->egt_ill_prep; }
			when ($input == 7) { $self->msub_illumina_egeno; }
			when ($input == 8) { $self->birdseed_2_csv; }
			when ($input == 0) { return; }
		}
		__print_usage__;
	}
}

1;
