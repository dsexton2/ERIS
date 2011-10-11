#!/hgsc_software/perl/latest/bin/perl

use warnings;
use diagnostics;

if ($#ARGV != 3) { die "usage: perl e-Genotyping_concordance.pl analysis_id /comma-delimited/paths/to/csfasta SNP_array /path/to/probelist\n" }

my $analysis_id = $ARGV[0];
my @csfasta_files = split(/,/, $ARGV[1]);
my $SNP_array=$ARGV[2];
my $probe_file = $ARGV[3];

my $con_result = $analysis_id.".birdseed.txt";
my $frequency_file = $analysis_id.".fre";

my %probes;
my %ref;
my %alt;
my %ref_base;
my %alt_base;
my %AB_freq;
my %BB_freq;

my %color_space = (
	'A0' => 'A', 'A1' => 'C', 'A2' => 'G', 'A3' => 'T', 
	'C1' => 'A', 'C0' => 'C', 'C3' => 'G', 'C2' => 'T', 
	'G2' => 'A', 'G3' => 'C', 'G0' => 'G', 'G1' => 'T', 
	'T3' => 'A', 'T2' => 'C', 'T1' => 'G', 'T0' => 'T', 
	'A.' => 'N', 'G.' => 'N', 'T.' => 'N', 'C.' => 'N', 
	'N.' => 'N', 'N3' => 'A', 'N2' => 'C', 'N1' => 'G', 
	'N0' => 'T'
);
my %sqtocs = ( 
	'AA' => '0', 'AC' => '1', 'AG' => '2', 'AT' => '3',
	'CA' => '1', 'CC' => '0', 'CG' => '3', 'CT' => '2',
	'GA' => '2', 'GC' => '3', 'GG' => '0', 'GT' => '1',
	'TA' => '3', 'TC' => '2', 'TG' => '1', 'TT' => '0',
	'AN' => '.', 'GN' => '.', 'TN' => '.', 'CN' => '.',
	'NN' => '.',  'NA' => '3', 'NC' => '2', 'NG' => '1',
	'NT' => '0'
);
my @chr_array = (
	'1', '2', '3', '4', '5', '6', '7', '8', '9', 
	'10', '11', '12', '13', '14', '15', '16', '17', 
	'18', '19', '20', '21', '22', 'X', 'Y', 'MT'
);

sub sequence_to_colorspace {
	my @sequence_space = split(//, shift);
	my @color_space = ();
		for (my $i = 0; $i < scalar @sequence_space - 2; $i++) {
		if (!exists $sqtocs{$sequence_space[$i].$sequence_space[$i+1]}) {
			push @color_space, ".";	
		}
		else {
			push @color_space, $sqtocs{$sequence_space[$i].$sequence_space[$i+1]};
		}
	}
	return join('', @color_space);

}

sub probelist_to_affy_cs {
	my @vals = split(/\t/, shift);

	my $chromosome = $vals[0];
	my $mapLoc = $vals[1];
	my $rsId = $vals[2];
	my $seq5 = $vals[3];
	my $seq3 = $vals[4];
	my $ref_allele = $vals[5];
	my $var_allele = $vals[6];
	my $major_homo = $vals[7];
	my $hetero = $vals[8];
	my $minor_homo = $vals[9];

	my $cs_seq5_ref_seq3 = sequence_to_colorspace($seq5.$ref_allele.$seq3);
	my $cs_seq5_var_seq3 = sequence_to_colorspace($seq5.$var_allele.$seq3);

	my $cs_seq5 = substr($cs_seq5_ref_seq3, 3, 11);
	my $cs_seq3 = substr($cs_seq5_ref_seq3, 16, 11);
	my $cs_ref_allele = substr($cs_seq5_ref_seq3, 14, 2);
	my $cs_var_allele = substr($cs_seq5_var_seq3, 14, 2);

	my @cs_vals = ($chromosome, $mapLoc, $rsId, $cs_seq5, $cs_seq3,
		$ref_allele, $var_allele, $cs_ref_allele, $cs_var_allele,
		$major_homo, $hetero, $minor_homo);
	return @cs_vals;
}

open(FIN, $probe_file);

while(my $line = <FIN>) {
	chomp($line);
	# 3=>5'
	# 4=>3'
	# 0=>chromosome
	# 1=>mapLoc
	# 5=>ref_allele
	# 6=>var_allele
	# 7=>ref_allele cs
	# 8=>var_allele cs

	@a = probelist_to_affy_cs($line);
	$seq = $a[3]." ".$a[4];
	$probes{$seq} = $a[0]."_".$a[1];
	$ref{$seq}=$a[7];
	$alt{$seq}=$a[8];
	$ref_base{$seq}=$a[5];
	$alt_base{$seq}=$a[6];
	$temp = "chr".$a[0]."_".$a[1];
	$AB_freq{$temp} = $a[10];
	$BB_freq{$temp} = $a[11];
}
close(FIN);

my $SNP_color="";
my %found;
my $SNP_base;

foreach my $csfasta_file(@csfasta_files) {
	open(FIN, $csfasta_file) or die $!;
	print STDERR "Processing $csfasta_file\n";
	while (my $seq = <FIN>) {
		next unless ($seq !~ /^>/ and $seq !~ /^#/);

		chomp($seq);
		$size = length($seq);
	
		for($i=1;$i<=$size-24;$i++) {
			$match = substr($seq, $i, 11)." ".substr($seq, $i+13, 11);
			if(exists($probes{$match})) {
				$SNP_color = substr($seq, $i+11,2);	
				if($SNP_color eq $ref{$match}) {
					$SNP_base = $ref_base{$match}."0";
				}
				elsif($SNP_color eq $alt{$match}) {
					$SNP_base = $alt_base{$match}."1";
				}
				else {
					$SNP_base = "S3";
				}
			
				(!exists($found{$probes{$match}})) ? 
					$found{$probes{$match}} = $SNP_base : 
					$found{$probes{$match}} .= "#".$SNP_base;
			} 	
		}
	}
	close(FIN);
}

print STDERR "Writing frequency data to $frequency_file\n";
open(FOUT, ">".$frequency_file) or die $!;
foreach my $i (0..24) {
	my %chr_split = ();
	foreach my $key (keys %found) {
		@a = split(/_/,$key);
		if ($a[0] eq $chr_array[$i]) {
			$chr_split{$a[1]} = $found{$key};
		}
	}

	foreach my $key (sort keys %chr_split) {
		print FOUT $chr_array[$i]."\t".$key."\t".$chr_split{$key}."\n";
	}
}
close(FOUT);

my %fre;
my $ref_seq="";
my $alt_seq="";
my $ref_num=0;
my $alt_num=0;
my $noise_num=0;
my $total_num=0;

open(FOUT,">".$con_result) or die $!;
open(FIN, $frequency_file) or die $!;

while(<FIN>) {
	chomp;
	@a=split(/\t/);
	@b=split(/#/,$a[2]);
	$size=@b;
	$ref_num=0;
	$alt_num=0;
	for($i=0;$i<$size;$i++) {
		@c=split(//,$b[$i]);
		if($c[1] eq "0") {
				$ref_num++;
				$ref_seq=$c[0];
		}
		elsif($c[1] eq "1") {
				$alt_num++;
				$alt_seq=$c[0];
		}
		else {
				$noise_num++;
		}
	}
	$total_num = $ref_num + $alt_num;
	if($total_num > 4 && $total_num < 16 ) {
		if($alt_num < 0.1 * $total_num) {
				$genotype = $ref_seq.$ref_seq;
		}
		elsif($alt_num > 0.75 * $total_num) {
				$genotype = $alt_seq.$alt_seq;
		}
		else {
				$genotype = $ref_seq.$alt_seq;
		}
		$temp = "chr".$a[0]."_".$a[1];
		$temp_geno = $ref_seq.$ref_seq;
		if($genotype ne $temp_geno) {
		$genotype = $genotype.$ref_seq;
		$fre{$temp} = $genotype;
		}
	}
}

close(FIN);
print STDERR "Done with Frequency hashing\n";

my $cor_num=0;
my $non_num=0;
my $corcondance=0;
my $exact_match=0;
my $exact_match_BB=0;
my $exact_match_AB=0;
my $one_match=0;
my $one_match_A=0;
my $one_match_B=0;
my $one_mismatch_A=0;
my $one_mismatch_B=0;
my $no_match=0;
my @birdseed_files = glob("/stornext/snfs0/next-gen/SNP_array/".$SNP_array."/*.birdseed");

if ($#birdseed_files == -1) { print "There are no birdseed files in $SNP_array\n" }

foreach my $birdseed_file(@birdseed_files) {
	$cor_num=0;
	$non_num=0;
	$corcondance=0;
	
	$exact_match=0;
	$exact_match_BB=0;
	$exact_match_AB=0;
	$one_match=0;
	$one_match_A=0;
	$one_match_B=0;
	$one_mismatch_A=0;
	$one_mismatch_B=0;
	$no_match=0;
	
	open(FIN, $birdseed_file);

	while(my $line = <FIN>) {
		next unless ($line !~ /^#/);
	
		chomp($line);
		@a = split(/\s+/, $line);
		($a[0] = "chr".$a[0]) unless ($a[0] =~ /^chr(.*?)$/);
		$temp = $a[0]."_".$a[1];

		next unless ($#a >= 3 and $a[3] ne "00" and exists($BB_freq{$temp}));

		if(exists($fre{$temp})) {
			@b = split(//, $fre{$temp});
			@c = split(//, $a[3]);
			if($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0]) {
					$cor_num++;
			}
			else { $non_num++ }

			$temp_f=$c[0].$c[1];
			$temp_r=$c[1].$c[0];
			$temp_c=$b[0].$b[1];
			if($temp_f eq $temp_c || $temp_r eq $temp_c) {
				$exact_match++;
				if($b[0] eq $b[1]) {
					#$exact_match_BB ++;
					$exact_match_BB += 1-$BB_freq{$temp};
				}
				else {
					#$exact_match_AB++;
					$exact_match_AB += 1-$AB_freq{$temp};
				}
			}
			elsif($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0]) {
				$one_match++;
				if($c[0] eq $b[0] || $c[0] eq $b[1] ) {
						$temp_match=$c[0];
				}
				else {
						$temp_match=$c[1];
				}
				if($temp_match eq $b[2]) {
					#$one_match_A++;
					if($b[0] eq $b[1]) {
							$one_match_A += 1-$BB_freq{$temp};
							$one_mismatch_A += 1-$BB_freq{$temp};
					}
					else {
							$one_match_A += 1-$AB_freq{$temp};
							$one_mismatch_A += 1-$AB_freq{$temp};
					}
	
				}
				else {
					#$one_match_B++;
					if( $b[0] eq $b[1]) {
							$one_match_B += 1-$BB_freq{$temp};
							$one_mismatch_B += 1-$BB_freq{$temp};
					}
					else {
							$one_match_B += 1-$AB_freq{$temp};
							$one_mismatch_B += 1-$AB_freq{$temp};
					}
				}
			}
			else {
				#$no_match++;
				if($b[0] eq $b[1] ) {
					$no_match += 1-$BB_freq{$temp};
				}
				else {
					$no_match += 1-$AB_freq{$temp};
				}
			}
		}
	}
	close(FIN);

	my $tot_num = 0;
	
	$tot_num = $cor_num + $non_num;
	
	if ($tot_num > 0) {
			$corcondance = $cor_num / ($cor_num + $non_num);
			#$co = ($exact_match*2 + $one_match ) / ($one_match*2 + $exact_match*2 + $no_match*2);
			$co = ($exact_match_AB*2 + $exact_match_BB*2 + $one_match_A + $one_match_B ) / ($one_match_A +$one_match_B +$one_mismatch_A + $one_mismatch_B + $exact_match_AB*2 + $exact_match_BB*2+ $no_match*2);
			$birdseed_file =~ /^(.*?)($SNP_array)\/(.*?)\.birdseed$/;
			$exact_match = $exact_match_AB + $exact_match_BB;
			$one_match = $one_match_A + $one_match_B;
			$exact_match = round($exact_match * 10000.0) * 0.0001;
			$one_match = round($one_match * 10000.0) * 0.0001;
			$one_match_A = round($one_match_A * 10000.0) * 0.0001;
			$one_match_B = round($one_match_B * 10000.0) * 0.0001;
			$exact_match_AB = round($exact_match_AB * 10000.0) * 0.0001;
			$exact_match_BB = round($exact_match_BB * 10000.0) * 0.0001;
			$no_match = round($no_match * 10000.0) * 0.0001;
			$co = round($co * 10000.0) * 0.0001;
			print FOUT "$3\t$exact_match\t$exact_match_AB\t$exact_match_BB\t$one_match\t$one_match_A\t$one_match_B\t$no_match\t$co\n";
	}
	else {
			print FOUT "$birdseed_file\n";
	}
}

sub round {
	my($number) = shift;
	return int($number + .5);
}

