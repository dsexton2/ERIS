package Concordance::TUI;

use warnings;
use strict;
use diagnostics;
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
use Concordance::Utils;

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

=cut


my $error_log = Log::Log4perl->get_logger("errorLogger");
my $error_screen = Log::Log4perl->get_logger("errorScreenLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

my %pipeline_params = ();
my %samples = ();

=head3 new

 my $tui = Concordance::TUI->new;

Instantiates a new TUI object.

=cut

sub new {
	my $self = {};
	$self->{CONFIG} = ();
	$self->{CONFIGFILE} = undef;
	bless($self);
	return $self;
}

=head3 config

 $tui->config(%config_param);

Gets and sets the configuration hash, which contains general configuration values read from a file.

=cut

sub config {
	my $self = shift;
	if (@_) { %{ $self->{CONFIG} } = @_; }
	return %{ $self->{CONFIG} };
}

=head3 config_file

 $tui->config_file("/log/config/config_01011900_0100.cfg");

Gets ands sets the path to the file to which all configuration items are to be written for this run.

=cut

sub config_file {
	my $self = shift;
	if (@_) { $self->{CONFIGFILE} = shift; }
	return $self->{CONFIGFILE};
}

=head3 __get_params__

 $self->__get_params__;

Private method to read from a file a list of parameters and validating regexes
for each module.

=cut

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

=head3 __read_and_validate_input__

 $self->__read_and_validate_input__("user prompt", "regex");

Private method to prompt the user for input, then to validate that input for the
given validating regex.

=cut

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

=head3 __add_to_hash__

 $self->__add_to_hash__("key", "value");

Private method to add instance-specific configuration items to the configuration hash.

=cut

sub __add_to_hash__ {
	if (@_) {
		my $self = shift;
		my $key = shift;
		my $value = shift;
		$self->{CONFIG}{$key} = $value;
		$self->__write_config_file__;
	}
}

=head3 __write_config_file__

 $self->__write_config_file__;

Writes both general and instance-specific configuration values to the filed
indicated by the C<config_file> class member.

=cut

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
	$self->set_instance_members("Concordance::EGtIllPrep");
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
	$self->set_instance_members("Concordance::Bam2csfasta");
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
	$self->set_instance_members("Concordance::RawBsToGeli");
}

sub geli_to_bs {
	print "Converting GELI files to BS files ...\n";
	my $self = shift;
	$self->set_instance_members("Concordance::GeliToBs");
}

=head3 set_instance_members

 $self->set_instance_members("Package::Name");

Private method to prompt for user input for a given class, then to instantiate
an object of the class and assign the values to it.  If the instance accepts
either the Samples container or the configuration object, pass those too.

=cut

sub set_instance_members {
	my $self = shift;
	my $package = shift;
	my $instance = $package->new;
	(my $class = $package) =~ s/^\w+:://g;
	my %params_and_regexes = %{ $pipeline_params{$class} };
	foreach my $param (keys %params_and_regexes) {
		if (!$self->{CONFIG}{$param}) {
			$instance->$param($self->__read_and_validate_input__($param, $params_and_regexes{$param}));
		}
		else { $instance->$param($self->{CONFIG}{$param}) }
	}
	if ($instance->can("config")) { $instance->config($self->config) }
	if ($instance->can("samples")) { $instance->samples(%samples) }
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
		"[C] Execute SOLiD eGeno msub scheduler.\n".
		"[0] Exit.\n".
		"\n";
}

=head3 get_sample_data

 $self->get_sample_data("/path/to/runid/list");

For a list of run Ids, a container of Sample objects is created form the LIMS
webservice.

=cut

sub get_sample_data {
	my $self = shift;
	my $run_id_list_file = undef;
	if (@_) { $run_id_list_file = shift }
	if (!-e $run_id_list_file) {
		$error_log->error("Run ID file DNE: $run_id_list_file\n");
		die("Run ID file DNE: $run_id_list_file\n");
	}
	open(FIN, $run_id_list_file) or die $!;
	my $run_id_list = do { local $/; <FIN> };
	close(FIN);
	# run ids are likely copied from a spreadsheet, so one per line
	$run_id_list =~ s/\n/,/g;
	$run_id_list =~ s/(.*),/$1/;
	%samples = Concordance::Utils->populate_sample_info_hash($run_id_list);
	if (scalar keys %samples == 0) {
		$error_log->error("Failed to populate sample hash with run ids from $run_id_list_file\n");
		die "Failed to populate sample hash with run ids from $run_id_list_file";
	}
}

=head3 execute

 $tui->execute;

Prompts the user for the component to execute, and kicks off the process by
which input is gathered and instance objects are executed.

=cut

sub execute {
	my $self = shift;
	if (my $input = Term::ReadLine->new("run_ids")->readline("\nEnter RunIDs file path? [y/n]\n")) {
		if ($input eq "y" or $input eq "Y") {
			my $run_id_file = Term::ReadLine->new("run_id_file")->readline("\nEnter RunID file path: ");
			$self->get_sample_data($run_id_file);
		}
	}
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
			when ($input eq "C") { $self->egenotyping_concordance_msub }
			when ($input eq 0) { return }
		}
		__print_usage__;
	}
}

1;


=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
