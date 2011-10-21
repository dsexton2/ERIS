#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use XML::TreePuller;

if ($#ARGV != 0) { die "Usage: perl build_partial_freq.pl /path/to/xml/file.xml\n" }
if (!-e $ARGV[0]) { die "Input file ".$ARGV[0]." DNE!\n" }

(my $result_file = $ARGV[0]) =~ s/(.*)\.xml/$1.prefrequency_probelist.part/;
(my $error_file = $ARGV[0]) =~ s/(.*)\.xml/$1.prefrequency_probelist.part.error/;

my %field_values;
my @field_order = qw(chromosome chr_loc rsId Seq5 Seq3 ref_allele var_allele);

$pull = XML::TreePuller->new(location => $ARGV[0]);
$pull->reader;
$pull->iterate_at('/ExchangeSet/Rs', 'subtree');

open(FOUT, ">".$result_file) or die $!;
open(FOUT_ERROR, ">".$error_file) or die $!;

while ($element = $pull->next) {
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

	# need to loop through the Ss nodes, looking for an Ss/Sequence/Observed
	# with the ref_allele/var_allele pair from the hgvs node, then take the
	# last 15 chars of seq5 and the first 15 of seq3. If we can't find
	# that, look for a reverse-complement ref_allele/var_allele pair and take
	# the first 15 chars of seq5 and the last 15 chars of seq3

	# check and see if the allele pairs are the same as or the reverse ...
	# in either case, take the flanking sequences as normal
	foreach my $Ss ($element->get_elements('Ss')) {
		if ($Ss->get_elements("Sequence/Observed")->text eq $field_values{"var_allele"}."/".$field_values{"ref_allele"} ||
			$Ss->get_elements("Sequence/Observed")->text eq $field_values{"ref_allele"}."/".$field_values{"var_allele"} ) {
			$Ss->get_elements("Sequence/Seq5")->text =~ m/^.*(\w{15})$/; 
			$field_values{"Seq5"} = uc $1;
			$Ss->get_elements("Sequence/Seq3")->text =~ m/^(\w{15}).*$/;
			$field_values{"Seq3"} = uc $1;
			last;
		}
	}

	# the alleles are either complemented or both reversed and complemented ...
	# so either complement or reverse and complement the flanking sequences, and switch
	# the assignmentt, to reflect the fact that the read went the opposite way
	if (!exists($field_values{"Seq5"}) and !exists($field_values{"Seq3"})) {
		(my $complement_alleles = $field_values{"ref_allele"}."/".$field_values{"var_allele"}) =~ tr/ACTGactg/TGACtgac/;
		foreach my $Ss ($element->get_elements('Ss')) {
			if ($Ss->get_elements("Sequence/Observed")->text eq $complement_alleles) {
				$Ss->get_elements("Sequence/Seq5")->text =~ m/^.*(\w{15})$/; 
				($field_values{"Seq5"} = uc $1) =~ tr/ACTG/TGAC/;

				$Ss->get_elements("Sequence/Seq3")->text =~ m/^(\w{15}).*$/;
				($field_values{"Seq3"} = uc $1) =~ tr/ACTG/TGAC/;
				last;
			}
			elsif ($Ss->get_elements("Sequence/Observed")->text eq reverse $complement_alleles) {
				$Ss->get_elements("Sequence/Seq5")->text =~ m/^.*(\w{15})$/; 
				($field_values{"Seq3"} = uc reverse $1) =~ tr/ACTG/TGAC/;

				$Ss->get_elements("Sequence/Seq3")->text =~ m/^(\w{15}).*$/;
				($field_values{"Seq5"} = uc reverse $1) =~ tr/ACTG/TGAC/;
				last;
			}
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

close(FOUT);
close(FOUT_ERROR);
