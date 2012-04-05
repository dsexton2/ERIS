#!/hgsc_software/perl/latest/bin/

use strict;
use warnings;
use diagnostics;

use Concordance::Birdseed::Conversion::PLINK;
use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
	\%options,
	'tfam_file=s',
	'probelist_path=s',
	'tped_file=s',
	'help|?',
	'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

my $obj = Concordance::Birdseed::Conversion::PLINK->new(
	tfam_file => $options{'tfam_file'},
	probelist_path => $options{'probelist_path'},
	tped_file => $options{'tped_file'},
);

$obj->execute;

=head1 NAME

B<moab_concordance_birdseed_conversion_plink.pl> - moab wrapper script for class Concordance::Birdseed::Conversion::PLINK

=head1 SYNOPSIS

B<moab_concordance_birdseed_conversion_plink.pl> [--tfam_file=Path] [--probelist_path=Path] [--tped_file=Path] [--man] [--help] [--?]

Options:

 --tfam_file	Full path to the tfam file
 --probelist_path	Full path to the probelist file
 --tped_file	Full path to the tped file

=head1 OPTIONS

=over 8

=item B<--tfam_file>

Full path to the tfam file

=item B<--probelist_path>

Full path to the probelist file

=item B<--tped_file>

Full path to the tped file

=item B<--help|?>

Prints a short help message concerning usage of this script.

=item B<--man>

Prints a man page containing detailed usage of this script.

=back

=head1 DESCRIPTION

This is an automatically generated script to allow jobs to be submitted to Moab utilizing the Concordance::Birdseed::Conversion::PLINK module.

=head1 LICENSE

GPLv3

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut


