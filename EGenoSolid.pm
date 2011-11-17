package Concordance::EGenoSolid;

=head1 NAME

Concordance::EGenoSolid

=head1 SYNOPSIS

 my $egs = Concordance::EGenoSolid->new;
 $egs->config(%config);
 $egs->samples(\%samples);
 $egs->execute;

=head1 DESCRIPTION

Insert description here.

=head2 Methods

=cut

use strict;
use warnings;
use Log::Log4perl;
use Concordance::Bam2csfasta;
use File::Touch;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $error_screen = Log::Log4perl->get_logger("errorScreenLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $debug_screen = Log::Log4perl->get_logger("debugScreenLogger");

=head3 new

 my $egeno_solid_prep = Concordance::EGenoSolid->new;

Returns a new EGenoSolid instance.

=cut

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{samples} = undef;
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

=head3 config

 my $egeno_solid_prep->config(\%config);
 my %config = %{ $self->config };

Gets and sets the hash containing configuration items.

=cut

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
}

sub samples {
	my $self = shift;
	if (@_) { $self->{samples} = shift }
	return $self->{samples} ;
}

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift }
	return $self->{debug_flag};
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

sub check_perms {
	# first check to make sure we have all the necessary file permissions
	# for the directories in which we may need to create links etc
	my $self = shift;
	my %samples = %{ $self->samples };
	my $all_clear = 1;
	foreach my $sample (values %samples) {
		my $path = $sample->result_path;
		if ($path =~ /\/output\//) {
			$path =~ s/(.*)(output\/.*)/$1/;
		}
		else {
			# it's a bam file not in the output dir; try to remove the .bam from the path
			$path =~ s/(.*)\/[^\/]*.bam$/$1/g;
		}
		if (!-w $path) {
			# make a note of each path for which perms need to be corrected
			$error_log->error("No write perms on dir $path for run ID ".$sample->run_id."\n");
			$error_screen->error("No write perms on dir $path for run ID ".$sample->run_id."\n");
			$all_clear = 0;
		}
	}
	return $all_clear;
}

sub execute {
	my $self = shift;
	my %samples = %{ $self->samples };
	my %error_samples = ();
	if (!$self->check_perms) {print "Fix perms issues\n"; exit; }
	foreach my $sample (values %samples) {
		print "Processing ".$sample->run_id."\n";
		my $path = $sample->result_path;
		my $raw = "";
		if ($path =~ /\/output\//) {
			$path =~ s/(.*)(output\/.*)/$1/;
		}
		else {
			# it's a bam file not in the output dir; try to remove the .bam from the path
			$path =~ s/(.*)\/[^\/]*.bam$/$1/g;
		}
		my @list;
		my @files = undef;
		my $se = $sample->run_id;
		if ((@files = glob($path."/input/*.csfasta")) || (@files = glob($path."/*.csfasta"))) {
			my $bad_link = 0;
			foreach my $file (@files) {
				if ($bad_link and (scalar @files > 1)) { last }
				if (stat($file)) {  
					# the link works
					push @list, $file;
				}
				else {
					$bad_link = 1;
					# we've got a bad link
					$error_log->error("Bad link: $file -> ".readlink($file)."\n");
					$error_screen->error("Bad link: $file -> ".readlink($file)."\n");
					# print files to run bam2csfasta
					my @bam_files = undef;
					if ((@bam_files = glob($path."/output/*.bam")) || (@bam_files = glob($path."/*.bam"))) {
						foreach my $bam_file (@bam_files) {
							$error_samples{$sample->run_id} = $sample;
							$error_samples{$sample->run_id}->result_path($bam_file);
							(my $link = $bam_file) =~ s/bam$/csfasta/;
							print STDOUT "Linking $file to $link\n";
							if (!-e $link) { touch($link) }
							unlink($file);
							# terrible kludge - if there are two CSFASTA softlinks, of which
							# at least one is broken, remove both links, create a new link based
							# off of the BAM and pointing at the CSFASTA that will result from
							# the subsequent BAM to CSFASTA conversion
							if (scalar @files > 1) {
								foreach my $badlink (@files) {
									unlink($badlink);
								}
							}
							if (!-e $path."/input") {
								mkdir($path."/input");
								$file =~ s/^(.*)\/(.*)$/$1\/input\/$2/;
							}
							if (!symlink($link, $file)) {
								print STDERR "Failed to link $file to $link for bam $bam_file\n";
							}
							else { push @list, $file }
						}
					}
					else {
						$error_log->error("Failed to find BAM files in $path\n");
						$error_screen->error("Failed to find BAM files in $path\n");
					}
					next;
				}
			}
			if (@list) {
				$sample->result_path(join(',', @list));
			}
		}
		else {
			# no csfasta files
			# if input/ DNE, try to create /input
			# hopefully, /input exists or was created above
			# going to try to set up links form /input to output/csfasta,
			# which is where csfasta will reside after bam2csfasta conversion
			my @bam_files = undef;
			if ((@bam_files = glob($path."/output/*.bam")) || (@bam_files = glob($path."/*.bam"))) {
				foreach my $bam_file (@bam_files) {
					$error_samples{$sample->run_id} = $sample;
					$error_samples{$sample->run_id}->result_path($bam_file);
					(my $link = $bam_file) =~ s/bam$/csfasta/;
					my $file = $bam_file.".csfasta";
					$file =~ s/output\///;
					$file =~ s/^(.*)\/(.*)$/$1\/input\/$2/;
					print STDOUT "Linking $file to $link\n";
					if (!-e $link) { touch($link) }
					if (!-e $path."/input") {
						mkdir($path."/input");
					}
					if (!symlink($link, $file)) {
						print STDERR "Failed to link $file to $link for bam $bam_file\n";
					}
					else { push @list, $file }
				}
			}
			else { print "No .bam files in $path/output\n" }
			if (@list) {
				$sample->result_path(join(',', @list));
			}
		}
	}
	# check if FERR is not empty; if it isn't, submit to Bam2Csfasta, else delete
	if (scalar keys %error_samples != 0) {
		$debug_log->debug("Executing Bam2csfasta ...\n");
		$debug_screen->debug("Executing Bam2csfasta ...\n");
		my $b2c = Concordance::Bam2csfasta->new;
		$b2c->config($self->config);
		$b2c->samples(\%error_samples);
		if (!$self->debug_flag) { $b2c->execute }
		# TODO add Sample objects with fixed result_path(s) back into main Sample container
	}
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams L<mailto:mcadams@bcm.edu>

=cut
