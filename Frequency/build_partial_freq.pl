#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use XML::TreePuller;

if ($#ARGV != 0) { die "Usage: perl build_partial_freq.pl /path/to/xml/file.xml\n" }
if (!-e $ARGV[0]) { die "Input file ".$ARGV[0]." DNE!\n" }

(my $result_file = $ARGV[0]) =~ s/(.*)\.xml/$1.prefrequency_probelist.part/;
(my $error_file = $ARGV[0]) =~ s/(.*)\.xml/$1.prefrequency_probelist.part.error/;

my %field_values;
my @field_order = qw(chromosome chr_loc rsId Seq5 Seq3 ref_allele var_allele);

my %orientation_values;

# read in sequence orientation information
open(FIN, "/stornext/snfs5/next-gen/concordance_analysis/dbSNP/hg19/b134_SNPChrPosOnRef_37_2.bcp") or die $!;
while (<FIN>) {
	chomp;
	my @columns = split(/\t/, $_);
	my $rsId = "rs".$columns[0];
	$orientation_values{$rsId}{"chromosome"} = $columns[1];
	$orientation_values{$rsId}{"position"} = $columns[2];
	$orientation_values{$rsId}{"isReverse"} = $columns[3];
}
close(FIN);

print STDOUT "read ".(scalar keys %orientation_values)." items from b134_SNPChrPosOnRef_37_2.bcp\n";

$pull = XML::TreePuller->new(location => $ARGV[0]);
$pull->reader;
$pull->iterate_at('/ExchangeSet/Rs', 'subtree');

open(FOUT, ">".$result_file) or die $!;
open(FOUT_ERROR, ">".$error_file) or die $!;

my $count = 0;

while ($element = $pull->next) {
	$count++;
	$field_values{"rsId"} = "rs".$element->attribute("rsId");
	my $hgvs_text = "";

	# get data from the NC hgvs node ... if there isn't, we'll junk the line at the end
	foreach my $hgvs ($element->get_elements("hgvs")) {
		# e.g., NC_000006.11:g.169952778T>C
		$hgvs_text = $hgvs->text;
		if ($hgvs->text =~ m/NC_\d+\.\d+:\w\.(\d+)(\w)>(\w)/) {
			$field_values{"chr_loc"} = $1;
			$field_values{"ref_allele"} = $2;
			$field_values{"var_allele"} = $3;
			last;
		}
	}

	# grab the sequence from the exemplarSs node; if the lookup against the hash
	# built from b134_SNPChrPosOnRef_37_2.bcp has isReverse of 0, get flanking
	# sequences as normal; if one, reverse complement and switch assignments
	foreach my $Sequence ($element->get_elements("Sequence")) {
		if (!defined($Sequence->attribute("exemplarSs"))) { next }
		(my $seq5 = $Sequence->get_elements("Seq5")->text) =~ s/^.*(\w{15})$/$1/;
		(my $seq3 = $Sequence->get_elements("Seq3")->text) =~ s/^(\w{15}).*$/$1/;
		if (!$orientation_values{$field_values{"rsId"}}->{isReverse}) {
			$field_values{"Seq5"} = uc $seq5;
			$field_values{"Seq3"} = uc $seq3;
		}
		else {
			($field_values{"Seq3"} = uc reverse $seq5) =~ tr/ACTG/TGAC/;
			($field_values{"Seq5"} = uc reverse $seq3) =~ tr/ACTG/TGAC/;
		}
	}

	# now get the chromosome position from an appropriate Assembly node ...
	foreach my $Assembly ($element->get_elements("Assembly")) {
		if ($Assembly->attribute("dbSnpBuild") eq "134"
			and $Assembly->attribute("genomeBuild") eq "37_2"
			and $Assembly->attribute("groupLabel") eq "GRCh37.p2") {
			if ((my $Component = $Assembly->get_elements("Component"))->attribute("orientation") eq "fwd") {
				$field_values{"chromosome"} = $Component->attribute("chromosome");
			}
			if ((my $Component = $Assembly->get_elements("Component"))->attribute("orientation") == undef) {
				if ($Component->attribute("chromosome") != undef) {
					if ($Component->get_elements("MapLoc")->attribute("orient") eq "forward") {
						$field_values{"chromosome"} = $Component->attribute("chromosome");
					}
				}
			}
			last;
		}
	}

	# print the data, junking the line if any of the fields are blank or if there
	# wasn't an hgvs NC node
	my $output = "";
	foreach $field (@field_order) {
		if (!exists($field_values{$field})) {
			$output = "";
			last;
		}
		$output .= $field_values{$field}."\t";
	}
	if ($output ne "") { print FOUT $output."\n" }
	else { print FOUT_ERROR $field_values{"rsId"}."\t".$hgvs_text."\n" }
	
	# clear out for the next iteration of the loop
	%field_values = ();
}

print STDOUT "total xml Rs count: $count\n";

close(FOUT);
close(FOUT_ERROR);
