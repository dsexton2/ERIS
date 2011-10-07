#! /hgsc_software/perl/latest/bin 

use warnings;
use diagnostics;

my $inline = $ARGV[0];
my $SNP_array=$ARGV[1];
my @inline_array=split(/#/,$inline);
my $size=@inline_array;
my @infiles;

for($i=1;$i<$size;$i++)
{
        $infiles[$i-1] = $inline_array[$i];
}

if ($#infiles==-1)

	{
		print STDERR "no csfasta present";
		exit;

	}


my $outfile = $inline_array[0];

my $con_result = $outfile.".birdseed.txt";
$outfile = $outfile.".fre";
print STDERR "outfile:\t$outfile\n";

my %color_space=('A0'=>'A','A1'=>'C','A2'=>'G','A3'=>'T','C1'=>'A','C0'=>'C','C3'=>'G','C2'=>'T','G2'=>'A','G3'=>'C','G0'=>'G','G1'=>'T','T3'=>'A','T2'=>'C','T1'=>'G','T0'=>'T','A.'=>'N','G.'=>'N','T.'=>'N','C.'=>'N','N.'=>'N','N3'=>'A','N2'=>'C','N1'=>'G','N0'=>'T');
my @chr_array=("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y","MT");

my $probe_file = "/stornext/snfs5/next-gen/concordance_analysis/dbSNP/dbSNP_probelist";
#my $probe_file = "/users/p-qc/dev/probelisttest";
#my $probe_file = "/users/p-qc/concordance/illumina_probelist";

#my $ss = Ss_read_to_cs->new("TACCAAACTTTAAGA");
#print $ss->execute;

#my $cs = Ss_read_to_cs->new("TACCAAACTTTAAGA")->getCs;
#print "cs: $cs\n";
#
#if (1) { die "bwoop" }

#my $cs = $ss_read_to_cs->getCs("TTTGTCTAAAACAACCCTTTCACTAGGCTCA");
#001122300011010020021123203221
#print "cs: $cs\n";
#$cs = $ss_read_to_cs->getCs("TTTGTCTAAAACAACACTTTCACTAGGCTCA");
#001122300011011120021123203221
#print "cs: $cs\n";
#   12230001101  20021123203 C A 00 11
#die;

#my %bad_pairs = ();

sub sequence_to_colorspace {
	my @sequence_space = split(//, shift);
	my @color_space = ();
	my %sqtocs = ( "AA" => 0, "AC" => 1, "AG" => 2, "AT" => 3,
		"CA" => 1, "CC" => 0, "CG" => 3, "CT" => 2,
		"GA" => 2, "GC" => 3, "GG" => 0, "GT" => 1,
		"TA" => 3, "TC" => 2, "TG" => 1, "TT" => 0,
		'AN'=>'.','GN'=>'.','TN'=>'.','CN'=>'.','NN'=>'.',
		'NA'=>'3','NC'=>'2','NG'=>'1','NT'=>'0' );
	for (my $i = 0; $i < scalar @sequence_space - 2; $i++) {
		if (!exists $sqtocs{$sequence_space[$i].$sequence_space[$i+1]}) {
			push @color_space, ".";	
		}
		else {
			push @color_space, $sqtocs{$sequence_space[$i].$sequence_space[$i+1]};
		}
	}
	return join('',@color_space);

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

	# TODO
	#my $cs_seq5_ref_seq3 = $ss_read_to_cs->getCs($seq5.$ref_allele.$seq3);
	#my $cs_seq5_var_seq3 = $ss_read_to_cs->getCs($seq5.$var_allele.$seq3);
	my $cs_seq5_ref_seq3 = sequence_to_colorspace($seq5.$ref_allele.$seq3);
	my $cs_seq5_var_seq3 = sequence_to_colorspace($seq5.$var_allele.$seq3);
	# now that I have color-space conversions, I can reassign the seq
	# and allele variables with color-space values
	my $cs_seq5 = substr($cs_seq5_ref_seq3, 3, 11);
	my $cs_seq3 = substr($cs_seq5_ref_seq3, 16, 11);
	my $cs_ref_allele = substr($cs_seq5_ref_seq3, 14, 2);
	my $cs_var_allele = substr($cs_seq5_var_seq3, 14, 2);

	my @cs_vals = ($chromosome, $mapLoc, $rsId, $cs_seq5, $cs_seq3,
		$ref_allele, $var_allele, $cs_ref_allele, $cs_var_allele,
		$major_homo, $hetero, $minor_homo);

	#foreach my $cs_val (@cs_vals) { print "$cs_val\t" }

	return @cs_vals;
}

#open(FIN, "/users/p-qc/dev/probelisttest") or die $!;
#my $line = <FIN>;
#probelist_to_affy_cs($line);
#
#close(FIN);
#
#print "\n";
#die;

#open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/AFFY_6-CS-best.egp");
open(FIN, $probe_file);
#open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/AFFY_5-SQ.egp");
my %probes;
my %ref;
my %alt;
my %ref_base;
my %alt_base;

my %AB_freq;
my %BB_freq;

while(my $line = <FIN>)
{
	chomp($line);
	# 3=>5'
	# 4=>3'
	# 0=>chromosome
	# 1=>mapLoc
	# 5=>ref_allele
	# 6=>var_allele
	# 7=>ref_allele cs
	# 8=>var_allele cs

	#@a=split(/\t/);
	@a = probelist_to_affy_cs($line);
	$seq = $a[3]." ".$a[4];
	$probes{$seq} = $a[0]."_".$a[1];
	#$probes{$seq} = $a[0]."_".$a[1]."_".$a[5].$a[6];
	$ref{$seq}=$a[7];
	$alt{$seq}=$a[8];
	$ref_base{$seq}=$a[5];
	$alt_base{$seq}=$a[6];
	$temp = "chr".$a[0]."_".$a[1];
	$AB_freq{$temp} = $a[10];
	$BB_freq{$temp} = $a[11];

}
close(FIN);

#if (scalar keys %bad_pairs != 0) { print STDERR "\nbad sequences: " }
#
#foreach my $bad_pair (sort keys %bad_pairs) {
#	print STDERR $bad_pair." ";
#}
#
#print "\n";
#
#die;
#{
#        chomp;
#        @a=split(/\s+/);
#        $temp="chr".$a[4]."_".$a[5];
#        $AB_freq{$temp} = $a[7];
#        $BB_freq{$temp} = $a[8];
#}

my $SNP_color="";
my %found;
my $SNP_base;
my $count=0;

foreach my $infile(@infiles)
{
open(FIN,"$infile");
print STDERR "reading $infile\n";
while(<FIN>)
{
	chomp;
	if(/^>/ || /^#/)
	{
		next;
	}
	#$count++;
	#if($count > 10000000)
	#{
	#	last;
	#}
	$seq=$_;
	$size = length($seq);

	#my $prev='T';
	#my $cur="";
	#my @a=split(//,$seq);
	#my $base="";
	#print STDERR "$seq\n";
	#for($i=1;$i<$size;$i++)
	#{
	#	$cur=$prev.$a[$i];
	#	$prev=$color_space{$cur};
	#	$base=$base.$prev;
	#}
	#print STDERR "$base\n";

	for($i=1;$i<=$size-24;$i++)
	{
		$match=substr($seq,$i,11)." ".substr($seq,$i+13,11);
		if(exists($probes{$match}))
		{
			$SNP_color = substr($seq, $i+11,2);	
			if($SNP_color eq $ref{$match})
			{
				#print STDERR "$ref_base{$match}0";
				$SNP_base = $ref_base{$match}."0";
			}
			elsif($SNP_color eq $alt{$match})
			{
				#print STDERR "$alt_base{$match}1";
				$SNP_base = $alt_base{$match}."1";
			}
			else
			{
				#print STDERR "S3";
				$SNP_base = "S3";
			}
			#print STDERR " $probes{$match}\n";
			if( !exists($found{$probes{$match}}))
			{
				$found{$probes{$match}} = $SNP_base;
			}
			else
			{
				$found{$probes{$match}} .= "#".$SNP_base;
			}
		} 	
	}
}
close(FIN);
}

open(FOUT,"> $outfile");
for($i=0;$i<25;$i++)
{
	$chr=$chr_array[$i];
	my %chr_split=();
	foreach my $key (keys(%found))
	{
		@a=split(/_/,$key);
		if($a[0] eq $chr)
		{
			$chr_split{$a[1]} = $found{$key};
		}
	}

	foreach my $key(sort(keys(%chr_split)))
	{
		print FOUT "$chr\t$key\t$chr_split{$key}\n";
	}
}
close(FOUT);
#close(FIN);


my %IUPAC =('A'=>'AA','C'=>'CC','G'=>'GG','T'=>'TT','R'=>'AG','Y'=>'CT','S'=>'GC','W'=>'AT','K'=>'GT','M'=>'AC');
@chr_array=("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y","M");

#my %AB_freq;
#my %BB_freq;
#open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/Array_site_info_all_positive.txt");

#open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/Array_site_info_all_positive_Affy50.txt");
#while(<FIN>)
#{
#        chomp;
#        @a=split(/\s+/);
#        $temp="chr".$a[4]."_".$a[5];
#        $AB_freq{$temp} = $a[7];
#        $BB_freq{$temp} = $a[8];
#}
#close(FIN);

open(FIN,$outfile);
open(FOUT,"> $con_result");
my %fre;
my $ref_seq="";
my $alt_seq="";
my $ref_num=0;
my $alt_num=0;
my $noise_num=0;
my $total_num=0;

while(<FIN>)
{
        chomp;
        @a=split(/\t/);
        @b=split(/#/,$a[2]);
        $size=@b;
        $ref_num=0;
        $alt_num=0;
        for($i=0;$i<$size;$i++)
        {
                @c=split(//,$b[$i]);
                if($c[1] eq "0")
                {
                        $ref_num++;
                        $ref_seq=$c[0];
                }
                elsif($c[1] eq "1")
                {
                        $alt_num++;
                        $alt_seq=$c[0];
                }
                else
                {
                        $noise_num++;
                }
        }
        $total_num = $ref_num + $alt_num;
        if($total_num > 4 && $total_num < 16 )
        {
                if($alt_num < 0.1 * $total_num)
                {
                        $genotype = $ref_seq.$ref_seq;
                }
                elsif($alt_num > 0.75 * $total_num)
                {
                        $genotype = $alt_seq.$alt_seq;
                }
                else
                {
                        $genotype = $ref_seq.$alt_seq;
                }
                #print STDERR "$genotype\n";
                $temp = "chr".$a[0]."_".$a[1];
                $temp_geno = $ref_seq.$ref_seq;
                if($genotype ne $temp_geno)
                {
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
my $birdseed_files="/stornext/snfs0/next-gen/SNP_array/".$SNP_array."/*.birdseed";
my @files = glob("$birdseed_files");
if ($#files==-1)
	{
		print "There are no birdseed files";

	}
foreach my $file(@files)
{
$cor_num=0;
$non_num=0;
$corcondance=0;
open(FIN,"$file");

$exact_match=0;
$exact_match_BB=0;
$exact_match_AB=0;
$one_match=0;
$one_match_A=0;
$one_match_B=0;
$one_mismatch_A=0;
$one_mismatch_B=0;
$no_match=0;

while(<FIN>)
{
        chomp;
        if(/^#/)
        {
                next;
        }
        @a=split(/\s+/);
	my $a_size=@a;
        if($a_size < 4)
        {
                next;
        }

	if($a[3] eq "00")
        {
                next;
        }

	if($a[0] =~ /^chr(.*?)$/)
	{
	}
	else
	{
		$a[0] = "chr".$a[0];
	}
	
        $temp = $a[0]."_".$a[1];
        if(!exists($BB_freq{$temp}))
        {
                next;
        }
        if(exists($fre{$temp}))
        {
                @b = split(//,$fre{$temp});
                @c = split(//,$a[3]);
                if($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0])
                {
                        $cor_num++;
                }
                else
                {
                        $non_num++;
                }

                $temp_f=$c[0].$c[1];
                $temp_r=$c[1].$c[0];
                $temp_c=$b[0].$b[1];
                if($temp_f eq $temp_c || $temp_r eq $temp_c)
                {
                        $exact_match++;
                        if($b[0] eq $b[1])
                        {
                                #$exact_match_BB ++;
                                $exact_match_BB += 1-$BB_freq{$temp};
                        }
                        else
                        {
                                #$exact_match_AB++;
                                $exact_match_AB += 1-$AB_freq{$temp};
                        }
                }
                elsif($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0])
                {
                        $one_match++;
                        if($c[0] eq $b[0] || $c[0] eq $b[1] )
                        {
                                $temp_match=$c[0];
                        }
                        else
                        {
                                $temp_match=$c[1];
                        }
                        if($temp_match eq $b[2])
                        {
                                #$one_match_A++;
                                if($b[0] eq $b[1])
                                {
                                        $one_match_A += 1-$BB_freq{$temp};
                                        $one_mismatch_A += 1-$BB_freq{$temp};
                                }
                                else
                                {
                                        $one_match_A += 1-$AB_freq{$temp};
                                        $one_mismatch_A += 1-$AB_freq{$temp};
                                }

                        }
                        else
                        {
                                #$one_match_B++;
                                if( $b[0] eq $b[1])
                                {
                                        $one_match_B += 1-$BB_freq{$temp};
                                        $one_mismatch_B += 1-$BB_freq{$temp};
                                }
                                else
                                {
                                        $one_match_B += 1-$AB_freq{$temp};
                                        $one_mismatch_B += 1-$AB_freq{$temp};
                                }
                        }
                }
                else
                {
                        #$no_match++;
                        if($b[0] eq $b[1] )
                        {
                                $no_match += 1-$BB_freq{$temp};
                        }
                        else
                        {
                                $no_match += 1-$AB_freq{$temp};
                        }
                }
        }
}
close(FIN);

my $tot_num = 0;

$tot_num = $cor_num + $non_num;

if ($tot_num > 0)
{
        $corcondance = $cor_num / ($cor_num + $non_num);
        #$co = ($exact_match*2 + $one_match ) / ($one_match*2 + $exact_match*2 + $no_match*2);
        $co = ($exact_match_AB*2 + $exact_match_BB*2 + $one_match_A + $one_match_B ) / ($one_match_A +$one_match_B +$one_mismatch_A + $one_mismatch_B + $exact_match_AB*2 + $exact_match_BB*2+ $no_match*2);
        $file =~ /^(.*?)($SNP_array)\/(.*?)\.birdseed$/;
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
else
{
        print FOUT "$file\n";
}
}

sub round {
    my($number) = shift;
    return int($number + .5);
}

