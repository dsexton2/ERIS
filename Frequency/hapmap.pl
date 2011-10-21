#!/hgsc_software/perl/latest/bin/perl

use strict;

if ($#ARGV != 1) { die "usage: perl hapmap.pl /path/to/prefrequency/probelist /path/to/output/probelist\n" }

my $prefrequency_probelist = $ARGV[0];
my $probelist = $ARGV[1];
my %geno_counts; # this will be a hash of rsId => egeno_sums objects
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
my $hapmap_dir = "/stornext/snfs0/next-gen/yw14-scratch/HAPMAP_r28_I_II+III/";

# open the probelist, for each rsId make a new hash item which points to an
# egeno_sums object; assign the current line to the instance
open(FIN_PROBELIST, $prefrequency_probelist) or die $!;
while (my $line = <FIN_PROBELIST>) {
	chomp($line);
	my @line_vals_by_col = split(/\t/, $line);
	
	my $target_rsid = $line_vals_by_col[2];
	if (!exists $geno_counts{$target_rsid}) {
		$geno_counts{$target_rsid} = egeno_sums->new;
		$geno_counts{$target_rsid}->probelist_line($line);
	}
}
close(FIN_PROBELIST);
print STDERR "hash size after reading probelist: ".(scalar keys %geno_counts)."\n";

foreach my $hapmap_file (@hapmap_files) {
	print STDERR "Processing $hapmap_dir"."$hapmap_file ...\n";
	open(FIN, $hapmap_dir.$hapmap_file);
	while (my $line = <FIN>) {
		my @data = split(/\s/, $line);
		if ($data[0] eq "rs#") { next } #skip the header row
		# $data[0] = rsId
		# $data[1] = alleles
		# $data[x] =~ m/\w\w/ = genotyping call
		# use the HAPMAP headers to put the values of each line into a hash
		if (!exists($geno_counts{$data[0]})) {
			print STDERR "could not match rsId against probelist: ".$data[0].
				" in hapmap file ".$hapmap_file."\n";
			next;
		}

		# get the alleles from the probelist
		my @probe_data = split(/\t/, $geno_counts{$data[0]}->probelist_line);
		my $probe_alleles = $probe_data[5].$probe_data[6];
		# figure out if the HAPMAP alleles and genotypes have been translated
		my $matched_allele = match_alleles($probe_alleles, $data[1]);

		if ($matched_allele !~ m/(\w)(\w)$/) {
			print STDERR "Failed to match $probe_alleles with ".$data[1].
				" for rsId ".$data[0]."\n";
			next;
		}
		# based on translation (if any), figure out what to look for in the genotypes
		my $major_homo = $1.$1;
		my $minor_homo = $2.$2;
		my $hetero = $1.$2;

		# iterate on the genotypes, and record them in the egeno_sums instance
		foreach my $column (@data) {
			if ($column =~ m/\w\w/) {
				if ($column eq $major_homo) {
					$geno_counts{$data[0]}->major_homo(1);
				}
				elsif ($column eq $minor_homo) {
					$geno_counts{$data[0]}->minor_homo(1);
				}
				elsif ($column eq $hetero) {
					$geno_counts{$data[0]}->hetero(1);
				}
			}
		}
		# clear for next line
		@data = ();
	}
	close(FIN);
}

print STDERR "Generating $probelist ...\n";
open(FOUT, ">".$probelist) or die $!;
foreach my $target_rsId (keys %geno_counts) {
	#do frequency calculations
	my $major_count = $geno_counts{$target_rsId}->major_homo;
	my $minor_count = $geno_counts{$target_rsId}->minor_homo;
	my $hetero_count = $geno_counts{$target_rsId}->hetero;
	my $total = $major_count + $minor_count + $hetero_count;

	print FOUT $geno_counts{$target_rsId}->probelist_line;
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

# figure out if the probe alleles and HAPMAP alleles are the same or differ by
# translation; we'll use this to figure out how to count the genotypes
sub match_alleles {
	my $probe_allele = shift;
	my $hapmap_allele = shift;

	(my $complement_probe_allele = $probe_allele) =~ tr/AGCT/TCGA/;
	# hapmap allele comes in like A/G
	$hapmap_allele =~ s/\///;

	if ($probe_allele eq $hapmap_allele) {
		# if it's a one-to-one correspondence, e.g. A/G A/G, return ref=A,var=G
		return $probe_allele;
	}
	elsif (reverse($probe_allele) eq $hapmap_allele) {
		# if the alleles are reversed, e.g. A/G G/A, return ref=A,var=G
		return $probe_allele;
	}
	elsif ($complement_probe_allele eq $hapmap_allele) {
		# if the allele is the complement, e.g. A/G T/C, return ref=G,var=A
		return $complement_probe_allele;
	}
	elsif (reverse($complement_probe_allele) eq $hapmap_allele) {
		# if the allele is the reverse complement, e.g. A/G C/T, return ref=G,var=A
		return $complement_probe_allele;
	}
	else { return "bad alleles" }
}

package egeno_sums;

sub new {
	my $self = {};
	$self->{probelist_line} = "";
	$self->{major_homo} = 0;
	$self->{minor_homo} = 0;
	$self->{hetero} = 0;
	bless($self);
	return $self;
}

sub probelist_line {
	my $self = shift;
	if (@_) { $self->{probelist_line} = shift }
	return $self->{probelist_line};
}

sub major_homo {
	my $self = shift;
	if (@_) { $self->{major_homo} += 1 }
	return $self->{major_homo};
}

sub minor_homo {
	my $self = shift;
	if (@_) { $self->{minor_homo} += 1 }
	return $self->{minor_homo};
}

sub hetero {
	my $self = shift;
	if (@_) { $self->{hetero} += 1 }
	return $self->{hetero};
}

1;
