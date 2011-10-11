#!/stornext/snfs1/next-gen/software/perl-5.10.1/bin/perl

use XML::TreePuller;

if ($#ARGV != 0) { die "Usage: perl treepuller.pl /path/to/xml/file.xml\n" }
if (!-e $ARGV[0]) { die "Input file ".$ARGV[0]." DNE!\n" }

(my $result_file = $ARGV[0]) =~ s/(.*)\.xml/$1.prefrequency_probelist.part/;

$pull = XML::TreePuller->new(location => $ARGV[0]);
$pull->reader; #return the XML::LibXML::Reader object

my %field_values;
my @field_order = qw(chromosome asnFrom rsId Seq5 Seq3 ref_allele var_allele);

$pull->iterate_at('/ExchangeSet/Rs', 'subtree');

open(FOUT, ">".$result_file);

while ($element = $pull->next) {
	$field_values{"rsId"} = "rs".$element->attribute("rsId");
	$element->get_elements("Sequence/Observed")->text =~ m/(\w)\/(\w)/;
	$field_values{"ref_allele"} = $1;
	$field_values{"var_allele"} = $2;
	foreach my $Ss ($element->get_elements('Ss')) {
		if ($Ss->attribute('orient') eq "forward") {
			foreach my $Seq5 ($element->get_elements("Sequence/Seq5")) {
				$Seq5->text =~ m/^.*(\w{15})$/;
				$field_values{"Seq5"} = uc $1;
			}
			foreach my $Seq3 ($element->get_elements("Sequence/Seq3")) {
				$Seq3->text =~ m/^(\w{15}).*$/;
				$field_values{"Seq3"} = uc $1;
			}
			last;
		}
	}
	foreach my $Assembly ($element->get_elements("Assembly")) {
		if ($Assembly->attribute("dbSnpBuild") eq "134"
			and $Assembly->attribute("genomeBuild") eq "37_2"
			and $Assembly->attribute("groupLabel") eq "GRCh37.p2") {
			if ((my $Component = $Assembly->get_elements("Component"))->attribute("orientation") eq "fwd") {
				$field_values{"chromosome"} = $Component->attribute("chromosome");
				$field_values{"asnFrom"} = $Component->get_elements("MapLoc")->attribute("asnFrom");
			}
			if ((my $Component = $Assembly->get_elements("Component"))->attribute("orientation") == undef) {
				if ($Component->attribute("chromosome") != undef) {
					if ($Component->get_elements("MapLoc")->attribute("orient") eq "forward") {
						$field_values{"chromosome"} = $Component->attribute("chromosome");
						$field_values{"asnFrom"} = $Component->get_elements("MapLoc")->attribute("asnFrom");
					}
				}
			}
			last;
		}
	}

	my $output = "";
	foreach $field (@field_order) {
		if (!exists($field_values{$field})) {
			$output = "";
			last;
		}
		$output .= $field_values{$field}."\t";
		#print FOUT $field_values{$field}."\t";
	}
	if ($output ne "") { print FOUT $output."\n" }
	%field_values = ();
}

close(FOUT);
