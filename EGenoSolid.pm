package Concordance::EGenoSolid;

use strict;
use warnings;
use Log::Log4perl;
use Concordance::Bam2csfasta;
use File::Touch;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $error_screen = Log::Log4perl->get_logger("errorScreenLogger");

sub new {
	my $self = {};
	$self->{config} = undef;
	$self->{output_path} = undef;
	$self->{error_path} = undef;
	$self->{samples} = undef;
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { $self->{config} = shift }
	return $self->{config};
}

sub output_path {
	my $self = shift;
	if (@_) { $self->{output_path} = shift }
	return $self->{output_path}; #[^\0]+
}

sub error_path {
	my $self = shift;
	if (@_) { $self->{error_path} = shift }
	return $self->{error_path}; #[^\0]+
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
	if (!$self->check_perms) {print "Fix perms issues\n"; exit; }
	open (FOUT, ">".$self->output_path);
	open (FERR, ">".$self->error_path);
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
		my $list = "";
		my @files = undef;
		my $se = $sample->run_id;
		if ((@files = glob($path."/input/*.csfasta")) || (@files = glob($path."/*.csfasta"))) {
			#egeno_solid.sh
			#$path =~ /.*\/(.*)$/;
			#my $se = $1;
			my $bad_link = 0;
			foreach my $file (@files) {
				if ($bad_link and (scalar @files > 1)) { last }
				if (stat($file)) {  
					# the link works
					$list.=" ".$file;
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
							print FERR $sample->run_id.",".$bam_file."\n";
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
							else { $list.=" ".$file }
						}
					}
					else {
						$error_log->error("Failed to find BAM files in $path\n");
						$error_screen->error("Failed to find BAM files in $path\n");
					}
					next;
				}
			}
			if ($list ne "") { print FOUT $sample->run_id." ".$list."\n" }
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
					print FERR $sample->run_id.",".$bam_file."\n";
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
					else { $list.=" ".$file }
				}
			}
			else { print "No .bam files in $path/output\n" }
			if ($list ne "") { print FOUT $sample->run_id." ".$list."\n" }
		}
	}
	close(FERR);
	close FOUT;
	# check if FERR is not empty; if it isn't, submit to Bam2Csfasta, else delete
	if (!-z $self->error_path) {
		print STDOUT "Error file contains items, executing Bam2csfasta ...\n";
		my $b2c = Concordance::Bam2csfasta->new;
		$b2c->config($self->config);
		$b2c->csv_file($self->error_path);
		$b2c->samples($self->samples);
		if (!$self->debug_flag) { $b2c->execute }
	}
}

1;

=head1 NAME

Concordance::EGenoSolid

=head1 SYNOPSIS

 my $egs = Concordance::EGenoSolid->new;
 $egs->config(%config);
 $egs->output_path("/users/p-qc/dev/egs_out.txt");
 $egs->error_path("/users/p-qc/testenv/bam2csfasta_input");
 $egs->execute;

=head1 DESCRIPTION



=head2 Methods

=over 12

=item C<new>

=item C<config>

=item C<output_path>

=item C<error_path>

=back

=head1 LICENSE

This Perl module is the property of Baylor Colloge of Medicine HGSC.

=head1 AUTHOR

Updated by John McAdams L<mailto:mcadams@bcm.edu>

=cut
