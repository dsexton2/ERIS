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
use Concordance::Change_AA_to_0;
use Concordance::EGenoSolid;
use Concordance::EGenotypingConcordanceMsub;
use Concordance::EGtIllPrep;
use Concordance::GeliToBs;
use Concordance::Judgement;
use Concordance::RawBsToGeli;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

my %pipeline_params = ();

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

sub __get_params__ {
	# reads in the parameters from the metadata, and parses the data in
	# as a hash of hashes, with the following structure:
	# %hash = { class_name => %hash2 { param => validating_regex } }
	my $self = shift;
	my %config = $self->config;
	if (-e $config{"metadata_file"}) {
		open(FIN, $config{"metadata_file"});
		my @lines = <FIN>;
		my $key = undef;
		foreach my $line (@lines) {
			chomp($line);
			if ($line =~ m/^\w/) {
				$key = $line;
				$pipeline_params{$key} = ();
				next;
			}
			$line =~ m/\t(.*)\t(.*)$/;
			$pipeline_params{$key}{$1} = "$2";
		}
		close(FIN);
	}
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
	my $input = undef;
	while ($input = $term->readline($prompt.": ")) {
		chomp($input);
		if ($input !~ /$validation_pattern/) {
			print "$input failed validation on $validation_pattern\n";
			next;
		}
		else {
			$self->__add_to_hash__($prompt, $input);
			last;
		}
	}
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

sub bs_2_birdseed {
	print "\nExecuting .bs=>.birdseed conversion ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::Bs2birdseed");
}

sub egt_ill_prep {
	print "Executing eGT Illumina preparation ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance:EGtIllPrep");
}

sub msub_illumina_egeno {
	print "Executing Illumina job submissions to msub ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::BsubIlluminaEgeno");
}

sub birdseed_2_csv {
	print "Executing .birdseed=>CSV conversion ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::Birdseed2Csv");
}

sub bam_2_csfasta {
	print "Executing .bam=>.csfasta conversion ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::Bam2csfasta", "pass_config");
}

sub change_aa_to_0 {
	print "Executing AA... to 0... conversion ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::Change_AA_to_0");
}

sub egeno_solid {
	print "Executing SOLiD egenotyping ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::EGenoSolid");
}

sub egenotyping_concordance_msub {
	print "";
	my $self = shift;
	$self->set_instance_members("Concordance::EGenotypingConcordanceMsub");
}

sub judgement {
	print "Judging concordance analysis ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::Judgement");
}

sub raw_bs_to_geli {
	print "Converting raw birdseed files to GELI files ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::RawBsToGeli", "pass_config");
}

sub geli_to_bs {
	print "Converting GELI files to BS files ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::GeliToBs", "pass_config");
}

sub set_instance_members {
	my $self = shift;
	my $package = shift;
	my $pass_config_flag = shift;
	my $instance = $package->new;
	(my $class = $package) =~ s/^\w+:://g;
	my %params_and_regexes = %{ $pipeline_params{$class} };
	foreach my $param (keys %params_and_regexes) {
		if (!$self->{CONFIG}{$param}) {
			$instance->$param($self->__read_and_validate_input__($param, $params_and_regexes{$param}));
		}
		else { $instance->$param($self->{CONFIG}{$param}) }
	}
	if ($pass_config_flag) { $instance->config($self->config) }
	$instance->execute;
}

sub __print_usage__ {
	print "\n".
		"[1] Run entire Illumina concordance process.\n".
		"[2] Execute Bam to Csfasta conversion.\n".
		"[3] Execute change AA... to 0... conversion.\n".
		"[4] Convert raw birdseed files to GELI files.\n".
		"[5] Convert GELI files to BS files.\n".
		"[6] Execute BS to Birdseed conversion.\n".
		"[7] Execute eGT Illumina preparation.\n".
		"[8] Execute Illumina eGeno msub scheduler.\n".
		"[9] Execute Birdseed to CSV conversion.\n".
		"[A] Execute SOLiD egenotyping.\n".
		"[B] Judge concordance analysis.\n".
		"[0] Exit.\n".
		"\n";
}

sub execute {
	my $self = shift;
	__print_usage__;
	$self->__get_params__;
	my $term = Term::ReadLine->new("user_input");
	while (my $input = $term->readline("\nEnter (numeric) choice: ")) {
		given ($input) {
			when ($input eq 1) {
				$input = $term->readline("\nDo you need to build birdseed files? [y]es or [n]o: ");
				if ($input eq 'y' || $input eq 'Y') {
					$self->build_geli_and_bs;
					$self->bs_2_birdseed;
				}
				$self->egt_ill_prep;
				$self->msub_illumina_egeno;
				$self->birdseed_2_csv;
				$self->judgement;
			}
			when ($input eq 2) { $self->bam_2_csfasta }
			when ($input eq 3) { $self->change_aa_to_0 }
			when ($input eq 4) { $self->raw_bs_to_geli }
			when ($input eq 5) { $self->geli_to_bs }
			when ($input eq 6) { $self->bs_2_birdseed }
			when ($input eq 7) { $self->egt_ill_prep }
			when ($input eq 8) { $self->msub_illumina_egeno }
			when ($input eq 9) { $self->birdseed_2_csv }
			when ($input eq "A") { $self->egeno_solid }
			when ($input eq "B") { $self->judgement }
			when ($input eq 0) { return }
		}
		__print_usage__;
	}
}

1;

=head1 NAME

Concordance::TUI - user interface to execute the concordance pipeline

=head1 SYNOPSIS

 my $tui = Concordance::TUI->new;
 $tui->config(%config);
 $tui->config_file("config.cfg");
 $tui->execute;

=head1 DESCRIPTION

This module provides a TUI (text user interface) to facilitate operation
of the concordance pipeline, in part or in whole.  It prompts the user
to indicate which operations to perform and for the parameters required
by each operation.  It writes all relevant parameters, i.e.
configuration values, to a run-specific configuration file for use in
debugging.

=head2 Methods

=over 12

=item C<new>

Returns a new Concordance::TUI instance.

=item C<config>

Accessor/mutator method for a General::Config object, containing
run-independent configuration values.

=item C<config_file>

Accessor/mutator method for an instance-specific configuration file, to
which all instance-specific configuration values shall be written.

Example:

 $tui->config_file("/foo/bar.cfg");
 $config_path = $tui->config_file;

=item C<__read_and_validate_input__>

Private utility method to prompt for user input and validate according to a
regex provided.  Returns the validated input

Example:

 $input = __read_and_validate__input("Enter CSV path: ", '\w+.csv');

=item C<__add_to_hash__>

Private method to add key/value pairs to the configuration value hash.

Example:

 $self->__add_to_hash__("key", "value");

=item C<__test_parm__>



=item C<__write_config_file__>

Private method to print sorted instance-specific configuration values to
the file indicated in C<config_file>.

Example:

 $self->__write_config_file__;

=item C<build_geli_and_bs>

Wrapper method to call Concordance::BuildGeliAndBS module, prompting the
user for the necessary parameters.

Example:

 $self->build_geli_and_bs;

=item C<bs_2_birdseed>



=item C<egt_ill_prep>



=item C<msub_illumina_egeno>



=item C<birdseed_2_csv>



=item C<bam_2_csfasta>



=item C<change_aa_to_0>


=item C<__print_usage__>

Prints a usage message to allow the user to select the desired tasks.

Example:

 __print_usage__;

=item C<execute>

Main entry point for the module.

Example:

 $tui->execute;

=back

=head1 LICENSE

This script is the property of Baylor College of Medicine.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
