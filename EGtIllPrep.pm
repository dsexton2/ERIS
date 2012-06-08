#!/hgsc_software/perl/latest/bin/perl

package Concordance::EGtIllPrep;

=head1 NAME

Concordance::EGtIllPrep - prepares Illumina data for concordance analysis

=head1 SYNOPSIS

 my $egt_ill_prep = Concordance::EGtIllPrep->new;

=head1 DESCRIPTION

This module takes a CSV file and SNP array directory.  It then constructs commands
to submit to msub to execute eGenotyping concordance. This is a wrapper module to
another script.

=head2 Methods

=cut

use strict;
use warnings;
use Config::General;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) { 
    Log::Log4perl->init("/users/p-qc/production_concordance_pipeline/Concordance/log4perl.cfg");
}
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $debug_to_screen = Log::Log4perl->get_logger("debugScreenLogger");

=head3 new

 my $egt_ill_prep = Concordance::EGtIllPrep->new;

Returns a new EGtIllPrep instance.

=cut

sub new {
    my $self = {};
    $self->{output_txt_path} = undef;
    $self->{samples} = undef;
    bless($self);
    return $self;
}

=head3 output_txt_path

 $egt_ill_prep->output_txt_path("/path/to/output/tsv.txt");

This writes out a TSV of run IDs paired with their associated bz2 files, for 
consumption by EGenotypingConcordanceMsub.

=cut

sub output_txt_path {
    my $self = shift;
    if (@_) { $self->{output_txt_path} = shift; }
    return $self->{output_txt_path}; #\w+.txt$
}

=head3 samples

 $egt_ill_prep->samples(%samples_param);

Gets and sets the Sample data structure.

=cut

sub samples {
    my $self = shift;
    if (@_) { $self->{samples} = shift }
    return $self->{samples};
}

=head3 execute

 $egt_ill_prep->execute;

Replaces the result_path in each sample object, which is currently the directory
containing the bz2 files, with a comma-delimited list of these same bz2 files.  
If there are not exactly two bz2 files, or if we lack read permissions, then 
remove that sample from the Samples data structure, note it, and continue with
the rest.

=cut

sub execute {
    my $self = shift;
    my %samples = %{ $self->samples };

    foreach my $sample (values %samples) {
        my @bz2_files = glob($sample->result_path."/*sequence.txt.bz2");
        # if there aren't exactly two bz2 files, or if we lack read permissions
        # for either file, note it and remove the Samples object
        if (scalar @bz2_files != 2) {
            # delete this key from the hash, print out for later processing
            $debug_log->debug("Did not find the two required bz2 files for ".$sample->run_id."\n");
            $debug_to_screen->debug("Did not find the two required bz2 files for ".$sample->run_id."\n");
            delete $samples{$sample->run_id};
        }
        elsif (!-r $bz2_files[0]) {
            $debug_log->debug("No read permissions on ".$bz2_files[0]."\n");
            $debug_to_screen->debug("No read permissions on ".$bz2_files[0]."\n");
            delete $samples{$sample->run_id};
        }
        elsif (!-r $bz2_files[1]) {
            $debug_log->debug("No read permissions on ".$bz2_files[1]."\n");
            $debug_to_screen->debug("No read permissions on ".$bz2_files[1]."\n");
            delete $samples{$sample->run_id};
        }
        else {
            $sample->result_path(join(",", @bz2_files));
        }
    }
    # print out result TSV for consumption by EGenotypingConcordanceMsub
    open (OUTFILE, "> ".$self->output_txt_path);
    foreach my $sample (values %samples) {
        print OUTFILE $sample->run_id;
        foreach my $file (split(/,/, $sample->result_path)) { print OUTFILE "\t".$file }
        print OUTFILE "\n";
    }
    close (OUTFILE);
}

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut

1;
