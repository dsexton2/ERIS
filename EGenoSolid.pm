#! /usr/bin/perl -w

package Concordance::EGenoSolid;

use strict;
use warnings;
use Log::Log4perl;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{input_path} = undef;
	$self->{output_path} = undef;
	bless($self);
	return $self;
}

sub input_path {
	my $self = shift;
	if (@_) { $self->{input_path} = shift }
	return $self->{input_path}; #[^\0]+
}

sub output_path {
	my $self = shift;
	if (@_) { $self->{output_path} = shift }
	return $self->{output_path}; #[^\0]+
}

sub error_path {
	return "/users/p-qc/testenv/bam2csfasta_input";
}

sub __get_file_list__ {
	my $file_extension = undef;
	my $path = undef;
	if (@_) {
		$path = shift;
		$file_extension = shift;
	}
	my @files = glob($path."/*".$file_extension);
	if ($#files == -1) {
		$error_log->error("no ".$file_extension." files found in ".$path."\n");
		exit;
	}
	return @files;
}

sub execute {
	my $self = shift;
	open (FIN, $self->input_path);
	open (FOUT, ">".$self->output_path);
	open (FERR, ">".$self->error_path);
	while (<FIN>) {
		chomp;
		my @csv_list = split(/,/, $_);
		my $sample_id = undef;
		my $path = undef;
		my $raw = "";
		if (@csv_list == 2) {
			$sample_id = $csv_list[0];
			$path = $csv_list[1];
			my $list = "";
			if (my @files = glob($path."/input/*.csfasta")) {
				#egeno_solid.sh
				$path =~ /.*\/(.*)$/;
				my $se = $1;
				my $full_name = $sample_id."_".$se;
				foreach my $file (@files) {
					if (stat($file)) {  
						if (readlink($file) =~ /results/ and $file =~ /csfasta/) {
							$list.=" ".$file;
						}
					}
					else {
						$error_log->error("Bad link: $file -> ".readlink($file)."\n");
						# print files to run bam2csfasta
						if (my @bam_files = glob($path."/output/*.bam")) {
							foreach my $bam_file (@bam_files) {
								print FERR $sample_id.",".$bam_file."\n";
							}
						}
						else { print STDERR "terribad $file\n" }
						next;
					}
				}
				if ($list ne "") { print FOUT $full_name." ".$list."\n" }
			}
			else {
				if (mkdir($path."/input")) {
					if (my @bam_files = glob($path."/output/*.bam")) {
						foreach my $bam_file (@bam_files) {
							print FERR $sample_id.",".$bam_file."\n";
						}
					}
				}
				else { print STDERR "bad $path\n" }
			}
			if (my @files = glob($path."/*.csfasta")) {
				#egeno_solid_merge.sh
				
			}
		}	
		elsif (@csv_list == 3) {
			#egeno_solid_2.sh
			$sample_id = $csv_list[0];
			my $se = $csv_list[1];
			$path = $csv_list[2];
			my $full_name = $sample_id." ".$se;
			foreach my $file (__get_file_list__($path, "*")) {
				if (stat($file) == 0) { print "fail on $file\n" }

				if ($file =~ m/results/ and $file =~ m/csfasta/) {
					$raw .= $file." ";
				}
			}
			$raw =~ s/\s+$//g;
			print FOUT $full_name." ".$path."\n";
		}
		else {
			print "Unrecognized file format\n";
		}
	}
	close FIN;
	close FOUT;
	close FERR;
}

1;

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

=head1 AUTHOR

=cut
