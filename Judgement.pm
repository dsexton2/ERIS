package Concordance::Judgement;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Concordance::Utils;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

sub new {
	my $self = {};
	$self->{config} = ();
	$self->{project_name} = undef;
	$self->{input_csv_path} = undef;
	$self->{sample_snp_validation_file} = undef;
	$self->{snp_array_dir} = undef;
	$self->{output_csv} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{config} } = @_; }
	return %{ $self->{config} };
}

sub project_name {
	my $self = shift;
	if (@_) { $self->{project_name} = shift; }
	return $self->{project_name}; #[^\0]+
}

sub input_csv_path {
	my $self = shift;
	if (@_) { $self->{input_csv_path} = shift }
	return $self->{input_csv_path}; #\w+.csv$
}

sub sample_snp_validation_file {
	my $self = shift;
	if (@_) { $self->{sample_snp_validation_file} = shift }
	return $self->{sample_snp_validation_file};
}

sub snp_array_dir {
	my $self = shift;
	if (@_) { $self->{snp_array_dir} =  shift }
	return $self->{snp_array_dir};
}

sub output_csv {
	my $self = shift;
	if (@_) { $self->{output_csv} =  shift }
	return $self->{output_csv};
}

sub execute {
	my $self = shift;
	$self->judge;
}


sub get_rules {
	my $self = shift;
	open(FIN, "Concordance/config/judgement_rules") or die $!;
	my $rules_content = do { local $/; <FIN> };
	close(FIN);
	my $project_name = $self->project_name; # so I don't have to do interpolation work-arounds
	my %rules = ();
	if ($rules_content =~ /project=($project_name)\nsampleid=(.*)\naverage=(.*)\nslf=(.*)\nbestHitID=(.*)\nbestHitValue=(.*)\nheader="(.*)"\n/) {
		$rules{"sampleid"} = $2;
		$rules{"average"} = $3;
		$rules{"slf"} = $4;
		$rules{"bestHitID"} = $5;
		$rules{"bestHitValue"} = $6;
		$rules{"header"} = $7;
	}
	return %rules;
}

sub email_output {
}

sub judge {
	# need birdseed2tsv file, sample<=>snparray tsv ... or csvs. whatevs
	my $self = shift;
	my %sample_snp_pairs = ();
	my %rules = $self->get_rules;

	my $lowConc = 0;
	my $insen = 0;
	my $known = 0;
	my $unknown = 0;
	my $contam = 0;
	my $marginal = 0;
	my $pass = 0;
	my $passGreater = 0;
	my $missing = 0;
	my $newline = "";

	open(FOUT, ">".$self->output_csv) or die $!;
	print FOUT $rules{"header"}."\n";
	
	open(VALTSV, $self->sample_snp_validation_file) or die $!;
	while (<VALTSV>) {
		chomp;
		my @sample_snp_cols;
		if ((@sample_snp_cols = split(/\s+/, $_)) || (@sample_snp_cols = split(/,/, $_))) {
			$sample_snp_pairs{$sample_snp_cols[0]} = $sample_snp_cols[1];
		}
	}
	close(VALTSV);
	open(FINPUT, $self->input_csv_path) or die $!;
	while (my $line = <FINPUT>) {
		$newline = "";
		my @line_cols = undef;
		if (@line_cols = split(/\s+/, $line)) {  } else { @line_cols = split(/,/, $line) }
		my $sampleid = $line_cols[$rules{"sampleid"}];
		my $average = $line_cols[$rules{"average"}];
		my $slf = $line_cols[$rules{"slf"}];
		my $bestHitID = $line_cols[$rules{"bestHitID"}]; # aka snp_array_name
		my $bestHitValue = $line_cols[$rules{"bestHitValue"}];

		# if 0.5 > average > 0.75, we're not checking
		if ($average < 0.5) {
			$newline = "Low Average Concordance\t$line";
			$lowConc += 1;
		}
		elsif ($average > 0.75) {
			$newline = "Insensitive Test\t$line";
			$insen += 1;
		}
		else {
			if ($bestHitID ne $sample_snp_pairs{$sampleid}) {
				my @snp_array_files = glob($self->snp_array_dir."/*.*");
				my $matched_in_snp_dir = 0;
				foreach my $snp_array_file (@snp_array_files) {
					my $snp_array_name = $sample_snp_pairs{$sampleid};
					if ($snp_array_file =~ /$snp_array_name/) {
						$matched_in_snp_dir = 1;
					}
				}
				if ($matched_in_snp_dir == 0) {
					$newline = "Missing SNP array: ".$sample_snp_pairs{$sampleid};
					$missing += 1;
					print FOUT $newline."\n";
					next;
				}
			}
			if ($slf > 0.9 and $slf > $bestHitValue) {
				$newline = "Pass\t$line";
				$pass += 1;
			}
			elsif ($slf > 0.9 and $slf < $bestHitValue) {
				$newline = "Pass - Best hit greater than self concordance: $bestHitID\t$line";
				$passGreater += 1;
			}
			elsif ($slf >= 0.8 and $slf <= 0.9) {
				$newline = "Marginal Concordance\t$line";
				$marginal += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue > 0.9) {
				$newline = "Known Swap - $bestHitID\t$line";
				$known += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue < 0.8) {
				$newline = "Unknown Swap\t$line";
				$unknown += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue >= 0.8 and $bestHitValue <= 0.9) {
				$newline = "Possible Contamination\t$line";
				$contam += 1;
			}
		}
		if ($newline ne "") { print FOUT $newline."\n"; }
	}
	close(FINPUT);
	close(FOUT);
	my $message = "Concordance Analysis Summary for ".$self->project_name.": \n\n\tPass:\t$pass\n\tPass (Not Best Hit):\t$passGreater\n\n\tKnown Swaps:\t$known\n\tUnknown Swaps:\t$unknown\n\tContaminated:\t$contam\n\tMarginal Concordance:\t$marginal\n\tInsensitive Test:\t$insen\n\tMissing SNP Arrays:\t$missing";
	print $message;
}

1;

=head1 NAME

Concordance::Judgement - wrapper module for Judgement.rb

=head1 SYNOPSIS

=head1 DESCRIPTION

Refactored from Phil's Ruby Judgement script.

=head2 Methods

=over12

=item C<new>

=item C<project_name>

=item C<input_csv_path>

=item C<execute>

=back

=head1 LICENSE

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
