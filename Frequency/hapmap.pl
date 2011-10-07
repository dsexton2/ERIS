my $headers = "rs# alleles chrom pos strand assembly# center protLSID assayLSID panelLSID QCcode NA19625 NA19700 NA19701 NA19702 NA19703 NA19704 NA19705 NA19708 NA19712 NA19711 NA19818 NA19819 NA19828 NA19835 NA19834 NA19836 NA19902 NA19901 NA19900 NA19904 NA19919 NA19908 NA19909 NA19914 NA19915 NA19916 NA19917 NA19918 NA19921 NA20129 NA19713 NA19982 NA19983 NA19714 NA19985 NA19984 NA20128 NA20126 NA20127 NA20277 NA20276 NA20279 NA20282 NA20281 NA20284 NA20287 NA20288 NA20290 NA20289 NA20291 NA20292 NA20295 NA20294 NA20297 NA20300 NA20298 NA20301 NA20302 NA20317 NA20319 NA20322 NA20333 NA20332 NA20335 NA20334 NA20337 NA20336 NA20340 NA20341 NA20343 NA20342 NA20344 NA20345 NA20346 NA20347 NA20348 NA20349 NA20350 NA20351 NA20357 NA20356 NA20358 NA20359 NA20360 NA20363 NA20364 NA20412";

my $hapmap_dir = "/stornext/snfs0/next-gen/yw14-scratch/HAPMAP_r28_I_II+III/";
my @hapmap_files = qw(
	genotypes_ASW_r28_nr.b36_fwd.txt
	genotypes_CEU_r28_nr.b36_fwd.txt
	genotypes_CHB_r28_nr.b36_fwd.txt
	genotypes_CHD_r28_nr.b36_fwd.txt
	genotypes_GIH_r28_nr.b36_fwd.txt
	genotypes_JPT_r28_nr.b36_fwd.txt
	genotypes_LWK_r28_nr.b36_fwd.txt
	genotypes_MEX_r28_nr.b36_fwd.txt
	genotypes_MKK_r28_nr.b36_fwd.txt
	genotypes_TSI_r28_nr.b36_fwd.txt
	genotypes_YRI_r28_nr.b36_fwd.txt
);

#my $hapmap_dir = "./";
#my @hapmap_files = qw( hapmap_eg.txt );

my %geno_counts;
# this will be a hash of rsId => @(major, minor, hetero)
my @headers = split(/\s/, $headers);
my %line_vals;

foreach my $hapmap_file (@hapmap_files) {
	print STDERR "Processing $hapmap_dir"."$hapmap_file ...\n";
	open(FIN, $hapmap_dir.$hapmap_file);
	while (my $line = <FIN>) {
		my @data = split(/\s/, $line);
		if ($data[0] eq "rs#") { next } #skip the header row
		foreach $header (@headers) {
			$line_vals{$header} = shift @data;
		}
		$line_vals{"alleles"} =~ m/(\w)\/(\w)/;
		my $major_homo = $1.$1;
		my $minor_homo = $2.$2;
		my $hetero = $1.$2;

		if (!exists $geno_counts{$line_vals{"rs#"}}) {
			$geno_counts{$line_vals{"rs#"}} = egeno_sums->new;
		}

		foreach my $key (keys %line_vals) {
			if ($key =~ m/^NA\d{5}/) {
				if ($line_vals{$key} eq $major_homo) {
					$geno_counts{$line_vals{"rs#"}}->mah(1);
				}
				elsif ($line_vals{$key} eq $minor_homo) {
					$geno_counts{$line_vals{"rs#"}}->mih(1);
				}
				elsif ($line_vals{$key} eq $hetero) {
					$geno_counts{$line_vals{"rs#"}}->het(1);
				}
			}
		}
		#print $line_vals{"rs#"}.": ".$nn_count."\n";
		@data = ();
		%line_vals = ();
	}
	close(FIN);
}

my $all_freq_file = "/stornext/snfs5/next-gen/concordance_analysis/dbSNP/all_freq.fre";
my $final_freq_file = "/stornext/snfs5/next-gen/concordance_analysis/dbSNP/final_freq.fre";

#my $all_freq_file = "all_freq.fre";
#my $final_freq_file = "final_freq.fre";
print STDERR "Generating $final_freq_file ...\n";
open(FIN, $all_freq_file) or die $!;
open(FOUT, ">".$final_freq_file) or die $!;
while (my $line = <FIN>) {
	chomp($line);
	$line =~ m/^[^\t]+\t[^\t]+\t([^\t]+).*$/;
	my $target_rsid = $1;
	#print "target rsid: $target_rsid\n";

	#do freq calculations
	if (!exists $geno_counts{$target_rsid}) { next }
	my $major_count = $geno_counts{$target_rsid}->mah;
	my $minor_count = $geno_counts{$target_rsid}->mih;
	my $hetero_count = $geno_counts{$target_rsid}->het;
	my $total = $major_count + $minor_count + $hetero_count;

	print FOUT $line;
	if ($total != 0) {
		print FOUT ($major_count / $total)."\t".($hetero_count / $total)."\t".($minor_count / $total);
	}
	else {
		# since $total is 0, all results will be 0
		print FOUT "0\t0\t0";
	}
	print FOUT "\n";
}
close(FIN);
close(FOUT);

package egeno_sums;

sub new {
	my $self = {};
	$self->{mah} = 0;
	$self->{mih} = 0;
	$self->{het} = 0;
	bless($self);
	return $self;
}

sub mah {
	my $self = shift;
	if (@_) { $self->{mah} += 1 }
	return $self->{mah};
}

sub mih {
	my $self = shift;
	if (@_) { $self->{mih} += 1 }
	return $self->{mih};
}

sub het {
	my $self = shift;
	if (@_) { $self->{het} += 1 }
	return $self->{het};
}

1;
