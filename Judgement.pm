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
	$self->{project_name} = undef;
	$self->{input_csv_path} = undef;
	$self->{snp_array_dir} = undef;
	$self->{output_csv} = undef;
	$self->{samples} = undef;
	bless($self);
	return $self;
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

sub snp_array_dir {
	my $self = shift;
	if (@_) { $self->{snp_array_dir} =  shift }
	return $self->{snp_array_dir}; #[^\0]+
}

sub output_csv {
	my $self = shift;
	if (@_) { $self->{output_csv} =  shift }
	return $self->{output_csv}; #\w+.csv$
}

sub samples {
	my $self = shift;
	if (@_) { $self->{samples} = shift }
	return $self->{samples};
}

sub execute {
	my $self = shift;
	$self->judge;
}


sub get_rules {
	my $self = shift;
	open(FIN, "/users/p-qc/dev_concordance_pipeline/Concordance/config/judgement_rules") or die $!;
	my $rules_content = do { local $/; <FIN> };
	close(FIN);
	my $project_name = $self->project_name; # so I don't have to do interpolation work-arounds
	if ($rules_content !~ m/$project_name/) {
		print STDOUT "Warning: No rule for $project_name in judgement_rules.  Using default headers...\n";
		$warn_log->warn("Warning: No rule for $project_name in judgement_rules.  Using default headers...\n");
		$project_name = "default";
	}
	my %rules = ();
	if ($rules_content =~ /project=($project_name)\nrunid=(.*)\nsampleid=(.*)\naverage=(.*)\nslf=(.*)\nbestHitID=(.*)\nbestHitValue=(.*)\nheader="(.*)"\n/) {
		$rules{"runid"} = $2;
		$rules{"sampleid"} = $3;
		$rules{"average"} = $4;
		$rules{"slf"} = $5;
		$rules{"bestHitID"} = $6;
		$rules{"bestHitValue"} = $7;
		$rules{"header"} = $8;
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
	my $header = $rules{"header"};
	$header =~ s/\t/,/g;
	print FOUT $header."\n";
	
	my %samples = %{ $self->samples };
	foreach my $sample (values %samples) {
		$sample_snp_pairs{$sample->run_id} = $sample->snp_array;
	}
	open(FINPUT, $self->input_csv_path) or die $!;
	while (my $line = <FINPUT>) {
		chomp($line);
		$newline = "";
		my @line_cols = undef;
		@line_cols = split(/,/, $line);
		# this is really run_id now
		my $runid = $line_cols[$rules{"runid"}];
		my $sampleid = $line_cols[$rules{"sampleid"}];
		my $average = $line_cols[$rules{"average"}];
		my $slf = $line_cols[$rules{"slf"}];
		my $bestHitID = $line_cols[$rules{"bestHitID"}]; # aka snp_array_name
		my $bestHitValue = $line_cols[$rules{"bestHitValue"}];

		# if 0.5 > average > 0.75, we're not checking
		if ($average < 0.5) {
			$newline = "Low Average Concordance,$line";
			$lowConc += 1;
		}
		elsif ($average > 0.75) {
			$newline = "Insensitive Test,$line";
			$insen += 1;
		}
		else {
			my $snp = $sample_snp_pairs{$runid};
			print "comparing $bestHitID to $snp with self concordance of $slf and bestHitValue $bestHitValue\n";
			if ($bestHitID !~ m/$snp/) {
				$newline = "Missing SNP array file ".
					$self->snp_array_dir."/".$samples{$runid}->snp_array.".birdseed ".
					" for run ID ".$runid;
				$missing += 1;
				$line =~ s/$slf//;
				#TODO sampleid, avg, NO SELF, best
				$newline .= ",".$line;
			}
			elsif ($slf > 0.9 and $slf >= $bestHitValue) {
				$newline = "Pass,$line";
				$pass += 1;
			}
			elsif ($slf > 0.9 and $slf < $bestHitValue) {
				$newline = "Pass - Best hit greater than self concordance: $bestHitID,$line";
				$passGreater += 1;
			}
			elsif ($slf >= 0.8 and $slf <= 0.9) {
				$newline = "Marginal Concordance,$line";
				$marginal += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue > 0.9) {
				$newline = "Known Swap - $bestHitID,$line";
				$known += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue < 0.8) {
				$newline = "Unknown Swap,$line";
				$unknown += 1;
			}
			elsif ($slf < 0.8 and $bestHitValue >= 0.8 and $bestHitValue <= 0.9) {
				$newline = "Possible Contamination,$line";
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
