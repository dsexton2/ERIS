#!/hgsc_software/perl/latest/bin/

use strict;
use warnings;
use diagnostics;

use Concordance::Birdseed::Conversion::Partek;
use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
	\%options,
	'birdseed_dir=s',
	'append_mode=i',
	'partek_file=s',
	'probelist_file=s',
	'help|?',
	'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

my $obj = Concordance::Birdseed::Conversion::Partek->new(
	birdseed_dir => $options{'birdseed_dir'},
	append_mode => $options{'append_mode'},
	partek_file => $options{'partek_file'},
	probelist_file => $options{'probelist_file'},
);

$obj->execute;

=head1 NAME

B<moab_concordance_birdseed_conversion_partek.pl> - moab wrapper script for class Concordance::Birdseed::Conversion::Partek

=head1 SYNOPSIS

B<moab_concordance_birdseed_conversion_partek.pl> [--birdseed_dir=Partek::Path] [--append_mode=Int] [--partek_file=Partek::Path] [--probelist_file=Partek::Path] [--man] [--help] [--?]

Options:

 --birdseed_dir	Full path to converted birdseed destination
 --append_mode	Appends to birdseed files rather than overwrite
 --partek_file	Full path to Partek file
 --probelist_file	Full path to the probelist file

=head1 OPTIONS

=over 8

=item B<--birdseed_dir>

Full path to converted birdseed destination

=item B<--append_mode>

Appends to birdseed files rather than overwrite

=item B<--partek_file>

Full path to Partek file

=item B<--probelist_file>

Full path to the probelist file

=item B<--help|?>

Prints a short help message concerning usage of this script.

=item B<--man>

Prints a man page containing detailed usage of this script.

=back

=head1 DESCRIPTION

This is an automatically generated script to allow jobs to be submitted to Moab utilizing the Concordance::Birdseed::Conversion::Partek module.

=head1 LICENSE

GPLv3

=head1 AUTHOR

John McAdams - L<mailto:mcadams@bcm.edu>

=cut


