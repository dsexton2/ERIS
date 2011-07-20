#!/usr/bin/perl -w

package Concordance::EGtIllPrep;

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{INPUT_CSV_PATH} = undef;
	$self->{OUTPUT_TXT_PATH} = undef;
	bless($self);
	return $self;
}

sub input_csv_path {
	my $self = shift;
	if (@_) { $self->{INPUT_CSV_PATH} = shift; }
	return $self->{INPUT_CSV_PATH};
}

sub output_txt_path {
	my $self = shift;
	if (@_) { $self->{OUTPUT_TXT_PATH} = shift; }
	return $self->{OUTPUT_TXT_PATH};
}

sub generate_fastq_list {
	my $self = shift;
	my $inFile = $self->input_csv_path;
	open(inFP,"<$inFile");
	open (OUTFILE, "> ".$self->output_txt_path);
	while (<inFP>) {
		chomp($_);
		my $current_line = $_;
	
		my @data = split(/[,\s]/,$current_line);
		my $NAME = $data[0];
		my $PATH = $data[1];
		print OUTFILE "$data[0]";  
		chomp($PATH);
	
		my @dirs = split(/\//,$PATH);
		my $instrument = $dirs[6];	
		#my @fcra = ();
		#foreach my $split_dir (@dirs) {
		#	if ($split_dir =~ /\w+_/) {
		#		@fcra = split(/_/, $split_dir);
		#		last;
		#	}
		#}
		my @fcra = split(/_/,$dirs[7]);
		
		my $flowcell = $fcra[3];
	
		my $SE = '';
		my $analysis_number = 0;
		if ($PATH =~ /Demultiplexed/) {
			my $barcode = $dirs[12];
			$dirs[13] =~ /(\d+)$/;
			$analysis_number = $1; 
			if ($analysis_number eq '') { $analysis_number = 1; }    
			$SE = "${flowcell}_${barcode}_${analysis_number}";
		} else {
			if ($dirs[11] =~ /GERALD/) {
				my @grld = split(/\./,$dirs[11]);
				$analysis_number = $grld[1];
			} elsif ($dirs[9] =~ /lane(\d+)/) {
				$analysis_number = $1;
			}
			if ($analysis_number eq '') { $analysis_number = 1; }
			$SE = "${flowcell}_${analysis_number}";
		}
	
		my @files = `ls $PATH/*sequence.txt.bz2`;
	
		if ($files[0] ne '') {
			print OUTFILE "${NAME}_${SE}";
			foreach my $fastq (@files) {
				chomp($fastq);
				print OUTFILE "\t$fastq";
			}
			print OUTFILE "\n";
		} else {
			$error_log->error("$PATH/*sequence.txt.bz2 not found for ${NAME}_${SE}\n");
		}
	}
}

1;

=head1 NAME

Concordance::EGtIllPrep - generate list of .fastq sequence files

=head1 SYNOPSIS

 my $EGtIllPrep = Concordance::EGtIllPrep->new;
 $EGtIllPrep->input_csv_path("/foo/bar.csv");
 $EGtIllPrep->output_txt_path("/foo/bar.txt");
 $EGtIllPrep->generate_fastq_list;

=head1 DESCRIPTION

=head2 Methods

=over 12

=item C<new>

Returns a new Concordance::EGtIllPrep object.

=item C<input_csv_path>

Gets and sets the path of the CSV file 

=item C<output_txt_path>

=item C<generate_fastq_list>

=back

=head1 LICENSE

This script is the property of Baylor College of Medicine.

=head1 AUTHOR

Updated by John McAdams - L<mailto:mcadams@bcm.edu>

=cut
