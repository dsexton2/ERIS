#!/hgsc_software/perl/latest/bin/perl

package Concordance::EGtIllPrep;

=head1 NAME

Concordance::EGtIllPrep - prepares Illumina data for concordance analysis

=head1 SYNOPSIS

 my $egt_ill_prep = Concordance::EGtIllPrep->new;

=head1 DESCRIPTION

This module takes a CSV file and SNP array directory.  It then constructs commands
to submit to msub to execute eGenotyping concordance. This is a wrapper module to
another script.

=head2 Methods

=cut

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) { 
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");

=head3 new

 my $egt_ill_prep = Concordance::EGtIllPrep->new;

Returns a new EGtIllPrep instance.

=cut

sub new {
	my $self = {};
	$self->{output_txt_path} = undef;
	$self->{samples} = {};
	bless($self);
	return $self;
}

sub output_txt_path {
	my $self = shift;
	if (@_) { $self->{output_txt_path} = shift; }
	return $self->{output_txt_path}; #\w+.txt$
}

=head3 samples

 $egt_ill_prep->sampes(%samples_param);

Gets and sets the Sample data structure.

=cut

sub samples {
	my $self = shift;
	if (@_) { %{ $self->{samples} } = @_ }
	return $self->{samples};
}

=head3 get_egeno_list_as_hash

 my %egeno_list = $self->get_egeno_list_as_hash;

This method processes on the Sample data structure, returning a list containing
pairs of Illumina run Ids mapped to their corresponding bz2 files.  If any of 
the bz2 files are missing, the user will be alerted and the run Ids will be 
noted for correction and will not be passed along to concordance anlysis for the
current run.

=cut

sub get_egeno_list_as_hash {
	my $self = shift;
	my %samples = %{ $self->samples };
	my %egeno_list;

	foreach my $sample_id (keys %samples) {
		my $name = $sample_id;
		my $path = $samples{$sample_id}->result_path;
		chomp($path);
	
		my @dirs = split(/\//,$path);
		my $instrument = $dirs[6];	
		my @fcra = split(/_/,$dirs[7]);
		
		my $flowcell = $fcra[3];
	
		my $se = "";
		my $analysis_number = 0;
		if ($path =~ /Demultiplexed/) {
			my $barcode = $dirs[12];
			$dirs[13] =~ /(\d+)$/;
			$analysis_number = $1; 
			if ($analysis_number eq '') { $analysis_number = 1; }    
			$se = $flowcell."_".$barcode."_".$analysis_number;
		}
		else {
			if ($dirs[11] =~ /GERALD/) {
				my @grld = split(/\./,$dirs[11]);
				$analysis_number = $grld[1];
			}
			elsif ($dirs[9] =~ /lane(\d+)/) {
				$analysis_number = $1;
			}
			if ($analysis_number eq '') { $analysis_number = 1; }
			$se = $flowcell."_".$analysis_number;
		}
	
		my @bz2_files = glob($path."/*sequence.txt.bz2");

		$egeno_list{$name."_".$se} = join(',', @bz2_files);

		# scalar @files = 2 should be the case
		if (scalar @bz2_files != 2) {
			# delete this key from the hash, print out for later processing
			delete $egeno_list{$name."_".$se};
			$debug_log->debug("Did not find the two required bz2 files for sample ID ".
				$sample_id." in directory ".$samples{$sample_id}->result_path."\n");
			$debug_to_screen->debug("Did not find the two required bz2 files for sample ID ".
				$sample_id." in directory ".$samples{$sample_id}->result_path."\n");
		}
	
	}
	return %egeno_list;
}

sub execute {
	my $self = shift;

	my %egeno_list = $self->get_egeno_list_as_hash;

	open (OUTFILE, "> ".$self->output_txt_path);
	print "egenoList: ".(scalar keys %egeno_list)."\n";
	foreach my $sample_id (keys %egeno_list) {
		my @files = $egeno_list{$sample_id};
		print OUTFILE $sample_id;
		foreach my $file (@files) { print OUTFILE "\t".$file }
		print OUTFILE "\n";
	}
	close (OUTFILE);

}

1;
