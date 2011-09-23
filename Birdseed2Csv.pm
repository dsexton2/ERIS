package Concordance::Birdseed2Csv;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Concordance::Utils;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

=head1 NAME

Concordance::Birdseed2Csv - writes concordance information for use by C<Concordance::Judgement>

=head1 SYNOPSIS

 my $b2c = Concordance::Birdseed2Csv->new;
 $b2c->path("/foo/bar");
 $b2c->output_csv_file("/foo/bar.csv");
 $b2c->project_name("foo");
 $b2c->samples(%foo);
 $b2c->execute;

=head1 DESCRIPTION

This class examines a directory of birdseed files and, for each sample/sequence pair in the C<samples> container, prints average and self concordance values, followed by project-specific number of SNP array and concordance value pairs.  This output serves as the input to C<Concordance::Judgement>.

=head2 Methods

=head3 new

 my $b2c = Concordance::Birdseed2Csv->new;

Returns a new Concordance::Birdseed2Csv object.

=cut

sub new {
	my $self = {};
	$self->{path} = undef;
	$self->{output_csv_file} = undef;
	$self->{project_name} = undef;
	$self->{samples} = {};
	bless($self);
	return $self;
}

=head3 path

 my $path = $b2c->path;
 $b2c->path($path);

Gets and sets the path to the directory containing the .birdseed.txt files.

=cut

sub path {
	my $self = shift;
	if (@_) { $self->{path} = shift; }
	return $self->{path}; #[^\0]+
}

=head3 output_csv_file

 my $output_csv_file = $b2c->output_csv_file;
 $b2c->output_csv_file($output_csv_file);

Gets and sets the path to the CSV file containing the results.

=cut

sub output_csv_file {
	my $self = shift;
	if (@_) { $self->{output_csv_file} = shift }
	return $self->{output_csv_file}; #\w+.csv$
}

=head3 samples

 my %samples = %{ $b2c->samples };
 $b2c->samples(%samples);

Gets and sets the Sample data structure.

=cut

sub samples {
	my $self = shift;
	if (@_) { %{ $self->{samples} } = @_ }
	return $self->{samples};
}

=head3 project_name

 my $project_name = $b2c->project_name;
 $b2c->project_name($project_name);

Gets and sets the project name, with the program logic branching accordingly.

=cut

sub project_name {
	my $self = shift;
	if (@_) { $self->{project_name} = shift }
	return $self->{project_name};
}

=head3 __build_concordance_hash__

 my $file = "/foo/bar.birdseed.txt";
 my %concordance = __build_concordance__hash($file);

Builds a hash of SNP names to concordance values, processing on data from the file provided as an argument.

=cut

sub __build_concordance_hash__ {
	my %temp = ();
	open(FIN, my $file = shift);
	while(<FIN>) {
		chomp;
		if ($_ =~ /\//) {
			$error_log->error("$file is an angry birdseed file!!\n");
			last;
		} 
		my @line_cols = split(/\s+/);
		$temp{$line_cols[0]}=$line_cols[8];
	}
	close(FIN);
	return %temp;
}


=head3 __base_output__

 my $file = "/foo/bar.birdseed.txt";
 my $MAX_PAIRS = 5;
 open(FOUT, $self->output_csv_file);
 $self->__base_output__($file, $MAX_PAIRS, *FOUT);

Private method to produce default concordance values for C<Concordance::Judgement>.

=cut

sub __base_output__ {
	my $self = shift;
	my $file = shift;
	my $MAX_PAIRS = shift;
	my $FOUT = shift;

	$debug_log->debug("Processing file $file\n");
	$file =~ /^.*\/(.*?)\.birdseed\.txt$/;
	my $name = $1;

	# find the right Sample object by looking for the sample_id as all
	# or part of the filename, then output run ID, sample ID
	foreach my $sample_id (%{ $self->samples }) {
		if ($name =~ /$sample_id/) {
			print FOUT ${ $self->samples }{$sample_id}->run_id.",".$sample_id.",";
		}
	}

	my $average = 0;
	my %concordance = __build_concordance_hash__($file);
	my $num = scalar keys %concordance;

	foreach my $avg (values %concordance) { $average += $avg }

	if ($num != 0) { $average = $average / $num }
	else { $average = "NaN" }
	print FOUT "$average";

	my $out_num=0;
	if (scalar keys %concordance != 0) {
		foreach my $key (sort { $concordance{$b} <=> $concordance{$a} } (keys(%concordance))) {
			print FOUT ",$concordance{$key},$key";
			$out_num++;
			if ($out_num >= $MAX_PAIRS) { last; }
		}
	}
	else { print FOUT ",No concordance values" }
	print $FOUT "\n";

}

=head3 __tcga_output__

 my $file = "/foo/bar.birdseed.txt";
 my $MAX_PAIRS = 5;
 open(FOUT, $self->output_csv_file);
 $self->__tcga_output__($file, $MAX_PAIRS, *FOUT);

Private method to produce TCGA concordance values for C<Concordance::Judgement>.

=cut

sub __tcga_output__ {
	my $self = shift;
	my $file = shift;
	my $MAX_PAIRS = shift;
	my $FOUT = shift;

	$file =~ /^.*\/(.*?)\.birdseed\.txt$/;
	my $out1 = $1;

	print FOUT "$out1";

	my $out = 0;
	my $out_num = 0;
	my $SHO_NUM = $MAX_PAIRS;
	my @out1_array=split(/[\_|\-]/,$out1);
	my $match = "TCGA-".$out1_array[1]."-".$out1_array[2];
	if ($out1_array[3] =~ /^(\d+)\D/) {
		$out = $match."-".$1;
	} else {
		$out = $match."-".$out1_array[3];
	}

	my $one=""; my $one_num=-1;
	my $slf=""; my $couple="";
	my $average=0; my $num=0;
	my %concordance=(); my %all=();
	open(FIN, $file);
	while(<FIN>) {
		chomp;
		if ($_ =~ /\//) {
			print FOUT STDERR "ERROR :: $file is an angry birdseed file!!\n";
			next;
		} 
		my @a=split(/\s+/);
		$concordance{$a[0]}=$a[8];
		$all{$a[0]}=$_;

		$a[0] =~ /^.*?TCGA\-(.*?)\-(.*?)\-(\d+)\D\-(.*?)/;
		my $mat1 = "TCGA-".$1."-".$2;
		my $mat2 = "TCGA-".$1."-".$2."-".$3;

		if($mat1 eq $match) {
			if($mat2 eq $out) {
				$slf=$_;
			} else {
				$couple=$_;
			}
		} else {
			$average += $a[8];
			$num++;
		}

		if($a[8] > $one_num) {
			$one_num=$a[8];
			$one=$_;
		}

	}

	$average = $average / $num;

	if ($slf =~ /^(.*?)_TCGA\-(.*?)$/) { $slf = "TCGA_".$2; }
	if ($couple =~ /^(.*?)_TCGA\-(.*?)$/) { $couple = "TCGA_".$2; }

	my @temp1 = ();
	if ($slf ne "" && $couple ne "") {
		@temp1=split(/\t/,$slf);
		print FOUT ",$temp1[0],$average,$temp1[8]";
		@temp1=split(/\t/,$couple);
		print FOUT ",$temp1[8]";
	} elsif($slf ne "") {
		@temp1=split(/\t/,$slf);
		print FOUT ",$temp1[0],$average,$temp1[8]";
		print FOUT ",";
	} elsif($couple ne "") {
		print FOUT ",,$average,";
		@temp1=split(/\t/,$couple);
		print FOUT ",$temp1[8]";
	} else {
		print FOUT ",,$average,,";
	}

	$out_num=0;
	foreach my $key (sort {$concordance{$b} <=> $concordance{$a}} keys %concordance) {
		### print FOUT "$all{$key}\n";
		$all{$key} =~ /^(.*?)_TCGA\-(.*?)$/;
		my $temp="TCGA_".$2;
		my @temp1=split(/\t/,$temp);
		### print FOUT "TCGA_$2\n";
		print FOUT ",$temp1[0],$temp1[8]";
		$out_num++;

		if($out_num >= $SHO_NUM) { last; }
	}
	print FOUT "\n";
	#print "$out\t$one_num\n";
	
	close(FIN);	
}

=head3 execute

 $b2c->execute;

Gathers a list of files based on C<path>, selects the appropriate processing logic based on the C<project_name>, and begins processing, writing the results to C<output_csv_file>.

=cut

sub execute {
	my $slf = shift;
	my $project_method = undef;
	my $MAX_PAIRS = 0;

	# some projects require different logic, so call the appropriate method
	if ($slf->project_name =~ m/tcga/i) {
		$project_method = "__tcga_output__";
		$MAX_PAIRS = 6;
	}
	else {
		$project_method = "__base_output__";
		$MAX_PAIRS = 10;
	}
	
	open(FOUT, ">".$slf->output_csv_file) or die $!;
	my @files = Concordance::Utils->get_file_list($slf->path, "birdseed.txt");
	foreach my $file (@files) {
		$slf->$project_method($file, 10, *FOUT);
	} 
	close(FOUT);
}

=head1 LICENSE

This script is the property of Baylor College of Medecine.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
