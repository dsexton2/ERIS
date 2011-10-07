#! /hgsc_software/perl/latest/bin 

my $e_geno_list=$ARGV[0];
my $SNP_array=$ARGV[1];

open(FIN,"$e_geno_list");
my $i=1;
my @com_array;
while(<FIN>)
{
	chomp;
	my @a=split(/\s+/);
	$temp=join("#",@a);
	$command = "bsub -e $i.e -o $i.o -J $i\_eGeno\_concor.job \"/users/p-qc/dev/e-Genotyping_concordance.pl $temp $SNP_array \"\;";
	$com_array[$i] = $command;
	$i++;
	print STDERR "$command\n";
	system("$command");
	sleep(2);
}
close(FIN);
