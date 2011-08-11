package Concordance::eGenotypingConcordance;

use warnings;
use strict;
use diagnostics;
use Config::General;
use Data::Dumper;
use Log::Log4perl;
use Concordance::Utils;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

my %probes;
my %ref;
my %alt;
my %ref_base;
my %alt_base;

sub new {
	my $self = {};
	$self->{csfasta_path_list} = ();
	$self->{snp_array_dir} = undef;
	$self->{output_file} = undef;
	$self->{con_result_file} = undef;
	$self->{debug_flag} = 0;
	bless($self);
	return $self;
}

sub csfasta_path_list {
	my $self = shift;
	if (@_) { @{ $self->{csfasta_path_list} } = shift }
	return $self->{csfasta_path_list};
}

sub snp_array_dir {
	my $self = shift;
	if (@_) { $self->{snp_array_dir} = shift }
	return $self->{snp_array_dir};
}

sub output_file {
	my $self = shift;
	if (@_) { $self->{output_file} = shift }
	return $self->{output_file};
}

sub con_result_file {
	my $self = shift;
	if (@_) { $self->{con_result_file} = shift }
	return $self->{con_result_file};
}

sub asiap_file {
	#my $self = shift;
	#if (@_) { $self->{asiap_file} = shift }
	#return $self->{asiap_file};
	return "/stornext/snfs0/next-gen/yw14-scratch/Array_site_info_all_positive.txt";
}

sub probe_file {
	#my $self = shift;
	#if (@_) { $self->{probe_file} = shift }
	#return $self->{probe_file};
	return "/stornext/snfs0/next-gen/yw14-scratch/AFFY_6-CS-best.egp";
}

sub debug_flag {
	my $self = shift;
	if (@_) { $self->{debug_flag} = shift }
	return $self->{debug_flag};
}

sub debug_file {
	#my $self = shift;
	#if (@_) { $self->{debug_file} = shift }
	#return $self->{debug_file};
	return "/users/p-qc/concordance/debug/".$self->output_file."_DEBUG";
}

sub birdseed_dir {
	my $self = shift;
	if (@_) { $self->{birdseed_dir} = shift }
	return $self->{birdseed_dir};
}

my %color_space=('A0'=>'A','A1'=>'C','A2'=>'G','A3'=>'T','C1'=>'A','C0'=>'C','C3'=>'G','C2'=>'T','G2'=>'A','G3'=>'C','G0'=>'G','G1'=>'T','T3'=>'A','T2'=>'C','T1'=>'G','T0'=>'T','A.'=>'N','G.'=>'N','T.'=>'N','C.'=>'N','N.'=>'N','N3'=>'A','N2'=>'C','N1'=>'G','N0'=>'T');
my @chr_array=("1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16","17","18","19","20","21","22","X","Y","MT");

sub populate_ref_and_alt_hashes {
	# routine to populate [alt|ref[_base]] hashes
	my $self = shift;
	$debug_log->debug("Populating [alt[_base]|ref[_base]] hashes ...\n");
	open(PROBE_FILE_IN, $self->probe_file) ||
		die $error_log->error("Failed to open file :".$self->probe_file."\n");
	while(<PROBE_FILE_IN>) {
		chomp;
		my @a=split(/\t/);
		my $seq = $a[3]." ".$a[4];
		$probes{$seq} = $a[0]."_".$a[1];
		$ref{$seq}=$a[7];
		$alt{$seq}=$a[8];
		$ref_base{$seq}=$a[5];
		$alt_base{$seq}=$a[6];
	}
	close(PROBE_FILE_IN);
	$debug_log->debug("Finished populating [alt[_base]|ref[_base]] hashes.\n");
	# ensure hashes have been populated
	if (scalar keys %probes == 0) { $warn_log->warn("%probes contains no items\n") }
	if (scalar keys %ref == 0) { $warn_log->warn("%ref contains no items\n") }
	if (scalar keys %alt == 0) { $warn_log->warn("%alt contains no items\n") }
	if (scalar keys %ref_base == 0) { $warn_log->warn("%ref_base contains no items\n") }
	if (scalar keys %alt_base == 0) { $warn_log->warn("%alt_base contains no items\n") }
	if ($self->debug_flag) {
		open(DEBUG, "> ".$self->debug_file."_populate_ref_and_alt_hashes");
		my $d = Data::Dumper->new([\%probes, \%ref, \%alt, \%ref_base, \%alt_base], [qw(probes ref alt ref_base alt_base)]);
		print DEBUG $d->Dump;
		close(DEBUG);
	}
}

my $SNP_color="";
my %found;
my $SNP_base;
my $count=0;

sub populate_SNP_color_found_hashes {
	my $self = shift;
	$debug_log->debug("Populating found hash ...\n");
	foreach my $csfasta_path ($self->csfasta_path_list) {
		open(CSFASTA_FILE_IN, $csfasta_path);
		while(<CSFASTA_FILE_IN>) {
			# lines of interest look like T32020033020112020001010022332120211101131111201103
			# or T21023210.222230221.3213011120210220231023322113220
			chomp;
			if(/^>/ || /^#/)
			{
				next;
			}
			my $seq=$_;
			my $size = length($seq);
			for(my $i=1;$i<=$size-24;$i++) {
				my $match=substr($seq,$i,11)." ".substr($seq,$i+13,11);
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
					if( !exists($found{$probes{$match}})) {
						$found{$probes{$match}} = $SNP_base;
					}
					else {
						$found{$probes{$match}} .= "#".$SNP_base;
					}
				} 	
			}
		}
		close(CSFASTA_FILE_IN);
	}
	$debug_log->debug("Finished populating found hash.\n");
	# ensure %found has been populated
	if (scalar keys %found == 0) { $warn_log->warn("%found contains no items\n") }
	if ($self->debug_flag) {
		open(DEBUG, "> ".$self->debug_file."_populate_SNP_color_found_hashes");
		print DEBUG Data::Dumper->Dump([\%found], [qw(found)]);
		close(DEBUG);
	}
}

sub write_chr_array {
	my $self = shift;
	$debug_log->debug("Writing chr_array ...\n");
	open(FOUT,"> ".$self->output_file) ||
		die $error_log->error("Failed to open file for writing: ".$self->output_file."\n");
	for(my $i=0;$i<25;$i++) {
		my $chr=$chr_array[$i];
		my %chr_split=();
		foreach my $key (keys(%found)) {
			my @a=split(/_/,$key);
			if($a[0] eq $chr) {
				$chr_split{$a[1]} = $found{$key};
			}
		}
		# ensure that %chr_split contains something to print
		foreach my $key(sort(keys(%chr_split))) {
			print FOUT "$chr\t$key\t$chr_split{$key}\n";
		}
	}
	close(FOUT);
	$debug_log->debug("Finished writing chr_array.\n");
}

my %AB_freq;
my %BB_freq;

sub populate_AB_BB_freq_hashes {
	my $self = shift;
	$debug_log->debug("Populating AB and BB frequency hashes ...\n");
	open(ASIAP_FILE_IN, $self->asiap_file) ||
		die $error_log->error("Failed to open file :".$self->asiap_file."\n");
	while(<ASIAP_FILE_IN>) {
		chomp;
		my @a=split(/\s+/);
		my $temp="chr".$a[4]."_".$a[5];
		$AB_freq{$temp} = $a[7];
		$BB_freq{$temp} = $a[8];
	}
	close(ASIAP_FILE_IN);
	$debug_log->debug("Finished populating AB and BB frequency hashes.\n");
	if (scalar keys %AB_freq == 0) { $warn_log->warn("%AB_freq contains no items\n") }
	if (scalar keys %BB_freq == 0) { $warn_log->warn("%BB_freq contains no items\n") }
	if ($self->debug_flag) {
		open(DEBUG, "> ".$self->debug_file."_populate_AB_BB_freq_hashes");
		print DEBUG Data::Dumper->Dump([\%AB_freq, \%BB_freq], [qw(AB_freq BB_freq)]);
		close(DEBUG);
	}
}

my %fre;
my $ref_seq="";
my $alt_seq="";
my $ref_num=0;
my $alt_num=0;
my $noise_num=0;
my $total_num=0;

sub populate_fre_hash {
	my $self = shift;
	$debug_log->debug("Populating frequency hash ...\n");
	open(FIN,$self->output_file) ||
		die $error_log->error("Failed to open file: ".$self->output_file."\n");
	my $genotype = undef;
	while(<FIN>) {
		chomp;
		my @a=split(/\t/);
		my @b=split(/#/,$a[2]);
		my $size=@b;
		$ref_num=0;
		$alt_num=0;
		for(my $i=0;$i<$size;$i++) {
			my @c=split(//,$b[$i]);
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
		if($total_num > 4 && $total_num < 16 )
		{
			if($alt_num < 0.1 * $total_num) {
				$genotype = $ref_seq.$ref_seq;
			}
			elsif($alt_num > 0.75 * $total_num) {
				$genotype = $alt_seq.$alt_seq;
			}
			else {
				$genotype = $ref_seq.$alt_seq;
			}
			#print STDERR "$genotype\n";
			my $temp = "chr".$a[0]."_".$a[1];
			my $temp_geno = $ref_seq.$ref_seq;
			if($genotype ne $temp_geno) {
				$genotype = $genotype.$ref_seq;
				$fre{$temp} = $genotype;
			}
		}
	}
	close(FIN);
	$debug_log->debug("Finished populating frequency hash.\n");
	if (scalar keys %fre == 0) { $warn_log->warn("%fre contains no items\n") }
	if ($self->debug_flag) {
		open(DEBUG, "> ".$self->debug_file."_populate_fre_hash");
		print DEBUG Data::Dumper->Dump([\%fre], [qw(fre)]);
		close(DEBUG);
	}
}

sub big_ass_loop {
	my $self = shift;
	$debug_log->debug("Beginning big ass loop ...\n");
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
	my $birdseed_files="/stornext/snfs0/next-gen/SNP_array/".$self->snp_array_dir."/*.birdseed";
	# my $birdseed_files = $self->birdseed_dir;
	my @files = Concordance::Utils->get_file_list($self->birdseed_dir, "birdseed");
	my @files = glob("$birdseed_files");
	if ($#files==-1) {
		$error_log->error("There are no birdseed files in: $birdseed_files\n");
	}
	open(FOUT,"> ".$self->con_result_file) ||
		die $error_log->error("Failed to open file for writing: ".$self->con_result_file."\n");
	if ($self->debug_flag) { open(FDEBUG, "> ".$self->debug_file."_DEBUG_big_ass_loop") }

	foreach my $file(@files) {
		
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

		while(<FIN>) {
			chomp;
			if(/^#/) {
				next;
			}
			my @a=split(/\s+/);
			my $a_size=@a;
			if($a_size < 4) {
				next;
			}
			if($a[3] eq "00") {
					next;
			}
			if($a[0] =~ /^chr(.*?)$/) {
			}
			else {
				$a[0] = "chr".$a[0];
			}
			my $temp = $a[0]."_".$a[1];
			if ($self->debug_flag) {
				print FDEBUG Data::Dumper->Dump([\@a, $temp], [qw(a temp)]);
			}
			if(!exists($BB_freq{$temp})) {
				next;
			}
			if(exists($fre{$temp})) {
				my @b = split(//,$fre{$temp});
				my @c = split(//,$a[3]);
				if($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0]) {
					$cor_num++;
				}
				else {
					$non_num++;
				}
				my $temp_f=$c[0].$c[1];
				my $temp_r=$c[1].$c[0];
				my $temp_c=$b[0].$b[1];
				if($temp_f eq $temp_c || $temp_r eq $temp_c) {
					$exact_match++;
					if($b[0] eq $b[1]) {
						$exact_match_BB += 1-$BB_freq{$temp};
					}
					else {
						$exact_match_AB += 1-$AB_freq{$temp};
					}
				}
				elsif($c[0] eq $b[0] || $c[0] eq $b[1] || $c[1] eq $b[1] || $c[1] eq $b[0]) {
					$one_match++;
					my $temp_match = undef;
					if($c[0] eq $b[0] || $c[0] eq $b[1] ) {
						$temp_match=$c[0];
					}
					else {
						$temp_match=$c[1];
					}
					if($temp_match eq $b[2]) {
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
			my $co = ($exact_match_AB*2 + $exact_match_BB*2 + $one_match_A + $one_match_B ) / ($one_match_A +$one_match_B +$one_mismatch_A + $one_mismatch_B + $exact_match_AB*2 + $exact_match_BB*2+ $no_match*2);
			my $temp_snp_array_dir = $self->snp_array_dir;
			$file =~ /^(.*?)($temp_snp_array_dir)\/(.*?)\.birdseed$/;
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
			print FOUT "$file\n";
		}
	}
	close(FDEBUG);
	$debug_log->debug("Finished big ass loop.\n");
}

sub round {
    my($number) = shift;
    return int($number + .5);
}

sub execute {
	my $self = shift;
	$self->populate_ref_and_alt_hashes;
	$self->populate_SNP_color_found_hashes;
	$self->write_chr_array;
	$self->populate_AB_BB_freq_hashes;
	$self->populate_fre_hash;
	$self->big_ass_loop;
}

1;
