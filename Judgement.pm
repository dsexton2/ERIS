package Concordance::Judgement;

=head1 NAME

Concordance::Judgement

=head1 SYNOPSIS

 my $judgement = Concordance::Judgement->new;
 $judgement->output_csv($output_csv_file);
 $judgement->project_name($project_name);
 $judgement->birdseed_txt_dir($birdseed_txt_dir);
 $judgement->samples(\%samples);
 $judgement->execute;

=head1 DESCRIPTION

This module judges the concordance analyses.

=head2 Methods

=cut

use strict;
use warnings;
use diagnostics;

use Carp;
use Concordance::Utils;
use Lingua::EN::Numbers::Ordinate;
use Log::Log4perl;

if (!Log::Log4perl->initialized()) {
    Log::Log4perl->init("/users/p-qc/dev_concordance_pipeline/Concordance/log4perl.cfg");
}
my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");
my $warn_log = Log::Log4perl->get_logger("warnLogger");

=head3 new

 my $judgement = Concordance::judgement->new;

Returns a new instance of Concordance::Judgement.

=cut

sub new {
    my $self = {};
    $self->{project_name} = undef;
    $self->{output_csv} = undef;
    $self->{samples} = undef;
    $self->{birdseed_txt_dir} = undef;
    $self->{results_email_address} = undef;
    bless($self);
    return $self;
}

=head3 project_name

 $judgement->project_name("foo");

Gets and sets the project name.

=cut

sub project_name {
    my $self = shift;
    if (@_) { $self->{project_name} = shift; }
    return $self->{project_name};
}

=head3 output_csv

 $judgement->output_csv("/foo/bar.csv");

Gets and sets the path to the CSV file, to which shall be written the judgement
results.

=cut

sub output_csv {
    my $self = shift;
    if (@_) { $self->{output_csv} =  shift }
    return $self->{output_csv};
}

=head3 samples

 $judgement->samples(\%samples_param);

Gets and sets the hash reference to the Sample container.

=cut

sub samples {
    my $self = shift;
    if (@_) { $self->{samples} = shift }
    return $self->{samples};
}

=head3 birdseed_txt_dir

 $judgement->birdseed_txt_dir("/foo/bar");

Gets and sets the path to the CSV file, to which shall be written the judgement
results.

=cut

sub birdseed_txt_dir {
    my $self = shift;
    if (@_) { $self->{birdseed_txt_dir} =  shift }
    return $self->{birdseed_txt_dir};
}

=head3 results_email_address

 $judgement->results_email_address("/foo/bar");

Gets and sets the path to the CSV file, to which shall be written the judgement
results.

=cut

sub results_email_address {
    my $self = shift;
    if (@_) { $self->{results_email_address} =  shift }
    return $self->{results_email_address};
}

=head3 execute

 $judgement->execute;

Public method to kick off concordance judgement; named execute to follow the
convention of other classes.

=cut

sub execute {
    my $self = shift;
    $self->__judge__;
}

=head3 __print_summary__

 $self->__print_summary__($hashref);

Private method to print to the screen a summary of the judgement analysis, which
consists of each state seen and a count of that state.

=cut

sub __print_summary__ {
    my $self = shift;
    my $judgement_report_information = shift;

    my $summary_message = "Concordance Analysis Summary for ".$self->project_name.": \n";
    
    foreach my $judgement_state (keys %$judgement_report_information) {
        $summary_message .= "\t".$judgement_state."\t".$judgement_report_information->{$judgement_state}."\n";
    }
    
    print $summary_message;
}

=head3 __print_report__

 $self->__print_report__($hashref);

Private method to print a CSV containing the results of the judgement analysis.

=cut

sub __print_report__ {
    my $self = shift;
    my $judgement_hashref = shift;

    open(FOUT, ">".$self->output_csv) or croak $!;
    # print headers
    print FOUT "State,Sequencing Event ID,Sample ID,\% Contamination,Average Concordance,".
        "1st Self Concordance,Best Hit ID,Best Hit Concordance,".
        "2nd Best Hit ID,2nd Best Hit Concordance,3rd Best Hit ID,".
        "3rd Best Hit Concordance,4th Best Hit ID,4th Best Hit Concordance,".
        "5th Best Hit ID,5th Best Hit Concordance,6th Best Hit ID,".
        "6th Best Hit Concordance\n";

    foreach my $judgement (values %$judgement_hashref) {
        print FOUT $judgement->{judgement_state}.",".
            $judgement->{sample}->run_id.",".
            $judgement->{sample}->sample_id.",".
            $judgement->{contamination}.",".
            $judgement->{average}.",".
            $judgement->{self_concordance};
        # print best hit ID/value pairs
        foreach my $best_hit_id (sort { $judgement->{concordance_pairs}->{$b} <=> $judgement->{concordance_pairs}->{$a} } (keys %{ $judgement->{concordance_pairs} })) {
            print FOUT ",".$best_hit_id.",".$judgement->{concordance_pairs}->{$best_hit_id};
        }
        print FOUT "\n";
    }

    close(FOUT) or carp $!;
}

=head3 __email_report__

 $self->__email_report__("foo@bar.com");

Private method to email the CSV containing the results of the concordance judgement anlysis.

=cut

sub __email_report__ {
    my $self = shift;
    if (!-e $self->output_csv) {
        carp "Failed to email report - problem finding CSV file ".$self->output_csv."\n";
        return;
    }
    if (!defined($self->{results_email_address})) {
        carp "Failed to email report - no email address(es) provided\n";
        return;
    }
    eval { system("echo \"$self->{project_name} Concordance Judgement Results\" | mutt -a $self->{output_csv} -s \"$self->{project_name} Concordance Judgement Results\" $self->{results_email_address}") };
    if ($@) {
        $error_log->error("Error sending email containing the results of the concordance judgement: $@\n");
        print STDERR "Error sending email containing the results of the concordance judgement: $@\n";
    }
}

=head3 __submit_report_to_LIMS__

 $self->__submit_report_to_LIMS__($hashref);

=cut

sub __submit_report_to_LIMS__ {
    my $self = shift;
    my $judgement_hashref = shift;

    foreach my $judgement (values %$judgement_hashref) {
        my $arg_string = $judgement->{sample}->run_id." ".
            "EZENOTYPING_FINISHED ";
        $arg_string .= "SAMPLE_EXTERNAL_ID ".$judgement->{sample}->sample_id." ".
            "EGENO_AVERAGE_CONCORDANCE ".$judgement->{average}." ".
            "EGENO_SELF_CONCORDANCE ".$judgement->{self_concordance}." ".
            "EGENO_STATE ".$judgement->{judgement_state}." ";
        my @best_hit_ids = ();
        my $best_hit_count = 1;
        foreach my $best_hit_id (sort { $judgement->{concordance_pairs}->{$b} <=> $judgement->{concordance_pairs}->{$a} } (keys %{ $judgement->{concordance_pairs} })) {
            $arg_string .= "EGENO_".uc(ordinate($best_hit_count))."_BEST_HIT_ID ".$best_hit_id." ".
                "EGENO_".uc(ordinate($best_hit_count++))."_BEST_HIT_CONCORDANCE ".$judgement->{concordance_pairs}->{$best_hit_id}." ";
        }
        # the script expects BEST instead of 1ST_BEST, so replace accordingly
        $arg_string =~ s/1ST_//g;
        $arg_string .= "EGENO_SNPS_TESTED ".$judgement->{egeno_snps_tested}." ".
            "EGENO_SNPS_PASSING_COVERAGE ".$judgement->{egeno_snps_passing_by_coverage}." ".
            "EGENO_SNPS_PASSING_MATCH ".$judgement->{egeno_snps_passing_match}." ".
            "PERCENT_CONTAMINATION ".$judgement->{contamination};
        $debug_log->debug("Args for setIlluminaLaneStatus.pl: ".$arg_string."\n");
        eval { `perl /users/p-qc/dev_concordance_pipeline/Concordance/setIlluminaLaneStatus.pl $arg_string` };
        if ($@) { $error_log->error($@."\n") }
    }
}

=head3 __build_concordance_hash__

 $__build_concordance_hash__($birdseed_txt_file);

Private method to read a birdseed file and build a hash of SNP_array_name =>
concordance_value pairs.

=cut

sub __build_concordance_hash__ {
    my $concordance = {}; open(FIN, my $file = shift);
    while(<FIN>) {
        chomp;
        if (m/\//) {
            $error_log->error("$file is an angry birdseed file!!\n");
            last;
        } 
        my @line_cols = split(/\s+/);
        $concordance->{$line_cols[0]}->{concordance} = $line_cols[8];
        if ($#line_cols == 13) {
            # this is the contamination value, and also the self-named SNP row
            $concordance->{$line_cols[0]}->{contamination} = $line_cols[13];
            $concordance->{$line_cols[0]}->{egeno_snps_tested} = $line_cols[9];
            $concordance->{$line_cols[0]}->{egeno_snps_passing_by_coverage} = $line_cols[10];
            $concordance->{$line_cols[0]}->{egeno_snps_passing_match} = $line_cols[12];
        }
    }
    close(FIN);
    return $concordance;
}

=head3 __build_prejudgement_hash__

 my $judgement_hashref = $self->__build_prejudgement_hash__;

Private method to build a structure containing the information necessary for
judgement.
    run_id =>
        sample => Concordance::Sample
        judgement_state => TBD in judge method
        average => ...
        self_concordance => ...
        contamination => ...
        concordance_pairs =>
            foreach (1..$max_pairs)
                best_hit_id => ...
                best_hit_value => ...

=cut

sub __build_prejudgement_hash__ {
    my $self = shift;
    my $samples = $self->samples;

    my $prejudgement_hashref = {};
    foreach my $sample (values %$samples) {
        # look for the .birdseed.txt produced by e-Genotyping concordance analysis
        # will be named with the run ID, i.e. <run_id>.birdseed.txt
        my $birdseed_txt_file = $self->birdseed_txt_dir."/".$sample->run_id.".birdseed.txt";
        if (!-e $birdseed_txt_file) {
            carp $!." ... missing .birdseed.txt file for run ID ".$sample->run_id."\n";
            next;
        }
        $debug_log->debug("Processing file $birdseed_txt_file for prejudgement ...\n");

        $prejudgement_hashref->{$sample->run_id}->{sample} = $sample;
        my $concordance = __build_concordance_hash__($birdseed_txt_file);
        my $num = scalar keys %$concordance;

        # get the self-concordance value from the hash using the self-named SNP array as key
        if (defined($concordance->{$sample->snp_array})) {
            $prejudgement_hashref->{$sample->run_id}->{self_concordance} = $concordance->{$sample->snp_array}->{concordance};
            $prejudgement_hashref->{$sample->run_id}->{contamination} = $concordance->{$sample->snp_array}->{contamination};
            $prejudgement_hashref->{$sample->run_id}->{egeno_snps_tested} = $concordance->{$sample->snp_array}->{egeno_snps_tested};
            $prejudgement_hashref->{$sample->run_id}->{egeno_snps_passing_by_coverage} = $concordance->{$sample->snp_array}->{egeno_snps_passing_by_coverage};
            $prejudgement_hashref->{$sample->run_id}->{egeno_snps_passing_match} = $concordance->{$sample->snp_array}->{egeno_snps_passing_match};

        }
        else {
            $prejudgement_hashref->{$sample->run_id}->{self_concordance} = "N/A";
            $prejudgement_hashref->{$sample->run_id}->{judgement_state} = "Missing SNP array";
        }

        # compute the average concordance value from the concordance hash
        my $average = "0";
        if (scalar keys %$concordance != 0) {
            foreach my $concordance_value (values %$concordance) { $average += $concordance_value->{concordance} }
            $average = $average / (scalar keys %$concordance);
        }
        $prejudgement_hashref->{$sample->run_id}->{average} = $average;
        
        # grab the first $max_pairs %$concordance items, sorting in descending
        # order of concordance value
        my $max_pairs = 6;
        if (scalar keys %$concordance != 0) {
            foreach my $key (sort { $concordance->{$b}->{concordance} <=> $concordance->{$a}->{concordance} } (keys %$concordance)) {
                $prejudgement_hashref->{$sample->run_id}->{concordance_pairs}->{$key} = $concordance->{$key}->{concordance};
                if (--$max_pairs == 0) { last; }
            }
        }
        else {
            print "No concordance values for $birdseed_txt_file";
        }
    }
    return $prejudgement_hashref;
}

=head3 __judge__

 $self->__judge__;

Private method that does the work of concordance judgement.

=cut

sub __judge__ {
    my $self = shift;
    my $samples = $self->samples;
    my %judgement_report_information;
    my $judgement_hashref = $self->__build_prejudgement_hash__;

    foreach my $sample (values %$samples) {
        if (defined($judgement_hashref->{$sample->run_id}->{judgement_state})) {
            # this will only pass if it's "Missing SNP array" in the concordance values
            # constructed from $sample->run_id.".birdseed"
            next;
        }
        if ($judgement_hashref->{$sample->run_id}->{average} < 0.5) {
            $judgement_hashref->{$sample->run_id}->{judgement_state} = "Low Average Concordance";
        }
        elsif ($judgement_hashref->{$sample->run_id}->{average} > 0.75) {
            $judgement_hashref->{$sample->run_id}->{judgement_state} = "Insensitive Test";
        }
        else {
            # the $best_hit_value is the highest concordance value from the birdseed.txt file
            my $best_hit_value = 0;
            if ($judgement_hashref->{$sample->run_id}->{self_concordance} > 0.9) {
                if ($judgement_hashref->{$sample->run_id}->{self_concordance} >= $best_hit_value) {
                    $judgement_hashref->{$sample->run_id}->{judgement_state} = "Pass";
                }
                else {
                    $judgement_hashref->{$sample->run_id}->{judgement_state} = "Pass - Best hit greater than self concordance";
                }
            }
            elsif (0.8 <= $judgement_hashref->{$sample->run_id}->{self_concordance} and $judgement_hashref->{$sample->run_id}->{self_concordance} <= 0.9) {
                $judgement_hashref->{$sample->run_id}->{judgement_state} = "Marginal Concordance";
            }
            elsif ($judgement_hashref->{$sample->run_id}->{self_concordance} < 0.8) {
                if ($best_hit_value > 0.9) {
                    $judgement_hashref->{$sample->run_id}->{judgement_state} = "Known Swap";
                }
                elsif (0.8 <= $best_hit_value and $best_hit_value <= 0.9) {
                    $judgement_hashref->{$sample->run_id}->{judgement_state} = "Possible Contamination";
                }
                else {
                    $judgement_hashref->{$sample->run_id}->{judgement_state} = "Unknown Swap";
                }
            }
        }
        $judgement_report_information{$judgement_hashref->{$sample->run_id}->{judgement_state}} += 1;
    }
    $self->__print_summary__(\%judgement_report_information);
    $self->__print_report__($judgement_hashref);
    $self->__email_report__;
    $self->__submit_report_to_LIMS__($judgement_hashref);
}

1;

=head1 LICENSE

GPLv3.

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut
