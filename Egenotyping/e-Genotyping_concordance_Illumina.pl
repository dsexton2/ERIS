#! /usr/bin/perl -w

my $inline = $ARGV[0];
my $SNP_array=$ARGV[1];
my @inline_array=split(/\#/,$inline);
my $size=@inline_array;
my @infiles;
for($i=1;$i<$size;$i++)
{
        $infiles[$i-1] = $inline_array[$i];
}

my $outfile = $inline_array[0];

my $con_result = $outfile.".birdseed.txt";
$outfile = $outfile.".fre";
print STDERR "$outfile\n";

my %color_space=('A0'=>'A','A1'=>'C','A2'=>'G','A3'=>'T','C1'=>'A','C0'=>'C','C3'=>'G','C2'=>'T','G2'=>'A','G3'=>'C','G0'=>'G','G1'=>'T','T3'=>'A','T2'=>'C','T1'=>'G','T0'=>'T','A.'=>'N','G.'=>'N','T.'=>'N','C.'=>'N','N.'=>'N','N3'=>'A','N2'=>'C','N1'=>'G','N0'=>'T');
my @chr_array=("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y","MT");
open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/AFFY_6-SQ-best.egp");
my %probes;
my %ref_base;
my %alt_base;
while(<FIN>)
{
	#	1	100006955	rs4908018	TTTGTCTAAAACAAC	CTTTCACTAGGCTCA	C	A
	# a[0] = chromosome
	# a[1] = position
	# a[2] = rsId
	# a[3] = 5'
	# a[4] = 3'
	# a[5] = ref allele
	# a[6] = var allele
        chomp;
        @a=split(/\t/);
        $seq = $a[3]." ".$a[4];
        $probes{$seq} = $a[0]."_".$a[1];
        $ref_base{$seq}=$a[5];
        $alt_base{$seq}=$a[6];
}
close(FIN);

my $SNP_color="";
my %found;
my $SNP_base;
my $read=0;

foreach my $infile(@infiles)
{
if($infile=~/\.bz2$/)
{
	open(FIN,"bzip2 -dc $infile | ") || die "can't open $infile\n";
}
else
{
	open(FIN,"$infile") || die "can't open $infile\n";
}

while(<FIN>)
{
        chomp;
        if(/^\@/)
        {
                $read=1;
                next;
        }
        if(/^\+/)
        {
                $read=0;
                next;
        }
        if($read==0)
        {
                next;
        }
        $seq=$_;
        $size = length($seq);

        for($i=0;$i<=$size-31;$i++)
        {
                $match=substr($seq,$i,15)." ".substr($seq,$i+16,15);
                if(exists($probes{$match}))
                {
                        $SNP_color = substr($seq, $i+15,1);
                        if($SNP_color eq $ref_base{$match})
                        {
                                #print STDERR "$ref_base{$match}0";
                                $SNP_base = $ref_base{$match}."0";
                        }
                        elsif($SNP_color eq $alt_base{$match})
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


my %IUPAC =('A'=>'AA','C'=>'CC','G'=>'GG','T'=>'TT','R'=>'AG','Y'=>'CT','S'=>'GC','W'=>'AT','K'=>'GT','M'=>'AC');
@chr_array=("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y","M");

my %AB_freq;
my %BB_freq;
open(FIN,"/stornext/snfs0/next-gen/yw14-scratch/Array_site_info_all_positive.txt");
while(<FIN>)
{
        chomp;
        @a=split(/\s+/);
        $temp="chr".$a[4]."_".$a[5];
        $AB_freq{$temp} = $a[7];
        $BB_freq{$temp} = $a[8];
}
close(FIN);

open(FIN,"$outfile");
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
	if($a[3] eq "00")
        {
                next;
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

if ($cor_num + $non_num > 0)
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

