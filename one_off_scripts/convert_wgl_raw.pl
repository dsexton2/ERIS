#!/hgsc_software/perl/latest/bin/perl

use strict;
use warnings;
use diagnostics;
use File::Touch;

if (@ARGV != 2) {
    die "usage: convert_wgl_raw.pl /path/to/raw/birdseed/to/convert /path/to/probelist/";
}

my $wgl_raw_bs_file = $ARGV[0];
(my $output_file = $wgl_raw_bs_file) =~ s/(.*)\.txt/$1.birdseed/;
my $probelist_file = $ARGV[1];

if (!-e $wgl_raw_bs_file) {
    die "DNE: $wgl_raw_bs_file\n";
}
if (!-e $probelist_file) {
    die "DNE: $probelist_file\n";
}
eval { touch($output_file) };
die $@ if $@;

# match the rs#s in the wgl_raw against those in the probelist
# grab the first two alleles from the wgl_raw as the genotype call, and the two indicators
# grab the chromosome #, position #, and reference allele from the probelist

# Raw Illumina File
#509215 15 77604963 rs11072859 G G B B 0.8142 0.7991 1.0000 -0.0362
# +
#probe list
#15 79817908 rs11072859 GAGGAACTTTGCCAC AAGCTCACATTCATT G A 0.770279971284996411 0.208183776022972003 0.0215362526920315865
# =
#birdseed file
#15 79817908 G GG rs11072859

my $super_ultra_mega_hash = {};

print "processing WGL raw birdseed file $wgl_raw_bs_file ... \n";
open(FIN_RAWBS, $wgl_raw_bs_file) or die $!;
while (<FIN_RAWBS>) {
    chomp;
    my @tabbed_columns = split(/\t/);
    if ($tabbed_columns[3] =~ m/^rs\d+$/ and $tabbed_columns[4].$tabbed_columns[5] ne "--") {
        $super_ultra_mega_hash->{$tabbed_columns[3]}->{raw_allele_1} = $tabbed_columns[4];
        $super_ultra_mega_hash->{$tabbed_columns[3]}->{raw_allele_2} = $tabbed_columns[5];
        $super_ultra_mega_hash->{$tabbed_columns[3]}->{raw_ab_allele_1} = $tabbed_columns[6];
        $super_ultra_mega_hash->{$tabbed_columns[3]}->{raw_ab_allele_2} = $tabbed_columns[7];
    }
}
close(FIN_RAWBS) or warn $!;

print "processing probelist $probelist_file ... \n";
open(FIN_PROBES, $probelist_file) or die $!;
while (<FIN_PROBES>) {
    chomp;
    my @tabbed_columns = split(/\t/);
    if (defined($super_ultra_mega_hash->{$tabbed_columns[2]})) {
        $super_ultra_mega_hash->{$tabbed_columns[2]}->{chromosome} = $tabbed_columns[0];
        $super_ultra_mega_hash->{$tabbed_columns[2]}->{chromosome_pos} = $tabbed_columns[1];
        $super_ultra_mega_hash->{$tabbed_columns[2]}->{ref_allele} = $tabbed_columns[5];
        $super_ultra_mega_hash->{$tabbed_columns[2]}->{var_allele} = $tabbed_columns[6];
    }
}
close(FIN_PROBES) or warn $!;

# at this point, super_ultra_mega_hash items look like:
#    rsid => rs123456
#        raw_allele_1 => G
#        raw_allele_2 => G
#        raw_ab_allele_1 => B
#        raw_ab_allele_2 => B
#        chromosome => 1
#        chromosome_pos => 123456
#        ref_allele => G
#        var_allele => A

open(FOUT, ">".$output_file) or die $!;
open(FOUT_ERR, ">".$output_file."_ERROR") or die $!;
foreach my $rsId (keys %$super_ultra_mega_hash) {
    my @birdseed_vals = ();
    push @birdseed_vals, $super_ultra_mega_hash->{$rsId}->{chromosome};
    push @birdseed_vals, $super_ultra_mega_hash->{$rsId}->{chromosome_pos};
    my $ref_and_geno_call_vals = &get_ref_allele_and_genotype_call(
        $super_ultra_mega_hash->{$rsId}->{raw_allele_1},
        $super_ultra_mega_hash->{$rsId}->{raw_allele_2},
        $super_ultra_mega_hash->{$rsId}->{raw_ab_allele_1},
        $super_ultra_mega_hash->{$rsId}->{raw_ab_allele_2},
        $super_ultra_mega_hash->{$rsId}->{ref_allele},
        $super_ultra_mega_hash->{$rsId}->{var_allele}
    );
    # make sure we received good data from the sub call
    foreach my $i (0..2) {
        if (!defined($$ref_and_geno_call_vals[$i])) {
            $ref_and_geno_call_vals = ();
            last;
        }
    }
    if (!defined($ref_and_geno_call_vals)) {
        print FOUT_ERR $rsId."\n";
        next;
    }
    push @birdseed_vals, $$ref_and_geno_call_vals[0];
    push @birdseed_vals, $$ref_and_geno_call_vals[1].$$ref_and_geno_call_vals[2];
    print FOUT join("\t", @birdseed_vals)."\n";
}
close(FOUT) or warn $!;
close(FOUT_ERR) or warn $!;

sub get_ref_allele_and_genotype_call {
    my $results = ();
    # 0 - "ref" allele
    # 1 - genotype call char 1
    # 2 - genotype call char 2
    (my $raw_allele_1, my $raw_allele_2, my $raw_ab_allele_1, my $raw_ab_allele_2, my $ref_allele, my $var_allele) = @_;
    (my $comp_raw_allele_1 = $raw_allele_1) =~ tr/acgtACGT/tgcaTGCA/;
    (my $comp_raw_allele_2 = $raw_allele_2) =~ tr/acgtACGT/tgcaTGCA/;
    # "default" return values
    push @$results, $ref_allele;
    push @$results, $raw_allele_1;
    push @$results, $raw_allele_2;
    if ($raw_ab_allele_1 =~ m/a/i) {
        if ($raw_allele_1 =~ m/$ref_allele/i) {
            $$results[0] = $ref_allele;
            $$results[1] = $raw_allele_1;
        }
        elsif ($raw_allele_1 =~ m/$var_allele/i) {
            $$results[0] = $var_allele;
            $$results[1] = $var_allele;
        }
        else {
            if ($comp_raw_allele_1 =~ m/$ref_allele/i) {
                $$results[0] = $ref_allele;
                $$results[1] = $comp_raw_allele_1;
            }
            elsif ($comp_raw_allele_1 =~ m/$var_allele/i) {
                $$results[0] = $var_allele;
                $$results[1] = $comp_raw_allele_1;
            }
        }
    }
    if ($raw_ab_allele_2 =~ m/a/i) {
        if ($raw_allele_2 =~ m/$ref_allele/i) {
            $$results[0] = $ref_allele;
            $$results[2] = $raw_allele_2;
        }
        elsif ($raw_allele_2 =~ m/$var_allele/i) {
            $$results[0] = $var_allele;
            $$results[2] = $var_allele;
        }
        else {
            if ($comp_raw_allele_2 =~ m/$ref_allele/i) {
                $$results[0] = $ref_allele;
                $$results[2] = $comp_raw_allele_2;
            }
            elsif ($comp_raw_allele_2 =~ m/$var_allele/i) {
                $$results[0] = $var_allele;
                $$results[2] = $comp_raw_allele_2;
            }
        }
    }
    if ($raw_ab_allele_1 =~ m/b/i) {
        if ($raw_allele_1 !~ m/$var_allele/i) {
            if ($raw_allele_1 =~ m/$ref_allele/i) {
                if ($raw_ab_allele_2 =~ m/b/i) {
                    $$results[0] = $var_allele;
                }
                $$results[1] = $ref_allele;
            }
            else {
                if ($comp_raw_allele_1 !~ m/$var_allele/i) {
                    if ($comp_raw_allele_1 =~ m/$ref_allele/i) {
                        if ($raw_ab_allele_2 =~ m/b/i) {
                            $$results[0] = $var_allele;
                        }
                        $$results[1] = $ref_allele;
                    }
                }
                else {
                    $$results[1] = $comp_raw_allele_1;
                }
            }
        }
    }
    if ($raw_ab_allele_2 =~ m/b/i) {
        if ($raw_allele_2 !~ m/$var_allele/i) {
            if ($raw_allele_2 =~ m/$ref_allele/i) {
                $$results[2] = $ref_allele;
            }
            else {
                if ($comp_raw_allele_2 !~ m/$var_allele/i) {
                    if ($comp_raw_allele_2 =~ m/$ref_allele/i) {
                        $$results[2] = $ref_allele;
                    }
                }
                else {
                    $$results[2] = $comp_raw_allele_2;
                }
            }
        }
    }
    return $results;
}
