package Concordance::Birdseed2Csv;

use strict;
use warnings;
use diagnostics;
use Log::Log4perl;
use Concordance::Utils;

if (!Log::Log4perl->initialized()) {
	Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
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
	$self->{samples} = undef;
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
	if (@_) { $self->{samples} = shift }
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
	return $self->{project_name}; #[^\0]+
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
	my $file_name = $1;
	#my $SNP_array_name = $1; # the file name
	my $SNP_array_name = "";

	# find the right Sample object by looking for the sample_id as all
	# or part of the SNP array name, then output run ID, sample ID
	my %samples = %{ $self->samples };
	foreach my $sample (values %samples) {
		my $run_id = $sample->run_id;
		if ($file_name =~ /$run_id/) {
			print FOUT $sample->run_id.",".$sample->sample_id.",";
			$SNP_array_name = $sample->snp_array;
		}
	}

	my $average = 0;
	my %concordance = __build_concordance_hash__($file);
	my $num = scalar keys %concordance;

	foreach my $avg (values %concordance) { $average += $avg }

	my $self_concordance = "N/A";

	if (defined($concordance{$SNP_array_name})) {
		$self_concordance = $concordance{$SNP_array_name};
	}

	if ($num != 0) { $average = $average / $num }
	else { $average = "NaN" }
	print FOUT "$average,$self_concordance";

	my $out_num=0;
	# print out the first $MAX_PAIRS %concordance items, sorting in descending
	# order of concordance value
	if (scalar keys %concordance != 0) {
		foreach my $key (sort { $concordance{$b} <=> $concordance{$a} } (keys(%concordance))) {
			print FOUT ",$key,$concordance{$key}";
			$out_num++;
			if ($out_num >= $MAX_PAIRS) { last; }
		}
	}
	else { print FOUT ",No concordance values for $file" }
	print $FOUT "\n";

}

=head3 execute

 $b2c->execute;

Gathers a list of files based on C<path>, selects the appropriate processing logic based on the C<project_name>, and begins processing, writing the results to C<output_csv_file>.

=cut

sub execute {
	my $slf = shift;
	my $project_method = undef;
	my $MAX_PAIRS = 0;

	$project_method = "__base_output__";
	$MAX_PAIRS = 10;
	
	open(FOUT, ">".$slf->output_csv_file) or die $!;
	my @files = Concordance::Utils->get_file_list($slf->path, "birdseed.txt");
	foreach my $file (@files) {
		$slf->$project_method($file, 10, *FOUT);
	} 
	close(FOUT);
}

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
