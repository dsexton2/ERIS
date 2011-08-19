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
	$self->{config} = ();
	$self->{input_path} = undef;
	$self->{output_path} = undef;
	$self->{error_path} = undef;
	bless($self);
	return $self;
}

sub config {
	my $self = shift;
	if (@_) { %{ $self->{config} } = @_; }
	return %{ $self->{config} };
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
	my $self = shift;
	if (@_) { $self->{error_path} = shift }
	return $self->{error_path}; #[^\0]+
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
		print "Processing $_\n";
		my @csv_list = split(/,/, $_);
		my $sample_id = undef;
		my $path = undef;
		my $raw = "";
		if (@csv_list == 2) {
			$sample_id = $csv_list[0];
			$path = $csv_list[1];
			my $list = "";
			my @files = undef;
			if ((@files = glob($path."/input/*.csfasta")) || (@files = glob($path."/*.csfasta"))) {
				#egeno_solid.sh
				$path =~ /.*\/(.*)$/;
				my $se = $1;
				my $full_name = $sample_id."_".$se;
				foreach my $file (@files) {
					if (stat($file)) {  
						# the link works
						$list.=" ".$file;
					}
					else {
						# we've got a bad link
						$error_log->error("Bad link: $file -> ".readlink($file)."\n");
						$error_screen->error("Bad link: $file -> ".readlink($file)."\n");
						# print files to run bam2csfasta
						my @bam_files = undef;
						if ((@bam_files = glob($path."/output/*.bam")) || (@bam_files = glob($path."/*.bam"))) {
							foreach my $bam_file (@bam_files) {
								print FERR $sample_id.",".$bam_file."\n";
								(my $link = $bam_file) =~ s/bam$/csfasta/;
								print STDOUT "Linking $file to $link\n";
								if (!-e $link) { touch($link) }
								unlink($file);
								if (!-e $path."/input") {
									mkdir($path."/input");
									$file =~ s/^(.*)\/(.*)$/$1\/input\/$2/;
								}
								if (!symlink($link, $file)) {
									print STDERR "Failed to link $file to $link for bam $bam_file\n";
								}
							}
						}
						else {
							$error_log->error("Failed to find BAM files in $path\n");
							$error_screen->error("Failed to find BAM files in $path\n");
						}
						next;
					}
				}
				if ($list ne "") { print FOUT $full_name." ".$list."\n" }
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
						print FERR $sample_id.",".$bam_file."\n";
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
					}
				}
				else { print "No .bam files in $path/output\n" }
				# the $file/input DNE; make it, put a link in there to link the csfasta
				#if (mkdir($path."/input")) {
				#	if (my @bam_files = glob($path."/output/*.bam")) {
				#		foreach my $bam_file (@bam_files) {
				#			print FERR $sample_id.",".$bam_file."\n";
				#			(my $link_target = $bam_file) =~ s/bam$/csfasta/;
				#			if (!-e $link_target) { touch($link_target) }
				#			(my $link = $link_target) =~ s/\/output\//\/input\//;
				#			print STDOUT "Linking $link_target to $link\n";
				#			symlink($link, $link_target);
				#		}
				#	}
				#}
				#else { print STDERR "bad $path\n" }
			}
			# check if FERR is not empty; if it isn't, submit to Bam2Csfasta, else delete
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
	close(FERR);
	close FIN;
	close FOUT;
	if (!-z $self->error_path) {
		print STDOUT "Error file contains items, executing Bam2csfasta ...\n";
		my $b2c = Concordance::Bam2csfasta->new;
		$b2c->config($self->config);
		$b2c->csv_file($self->error_path);
		$b2c->execute;
	}
}

1;

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

=head1 AUTHOR

=cut
