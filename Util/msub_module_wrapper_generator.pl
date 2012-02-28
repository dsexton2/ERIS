#!/hgsc_software/perl/latest/bin/perl

use warnings;
use strict;
use diagnostics;

use Getopt::Long;
use Pod::Usage;

my %options = ();

GetOptions(
    \%options,
    'module-name=s',
    'help|?',
    'man'
);

pod2usage(-exitstatus => 0, -verbose => 1) if defined($options{help});
pod2usage(-exitstatus => 0, -verbose => 2) if defined($options{man});
pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys %options == 0;

(my $msub_script_file_name = "msub_".lc($options{'module-name'}).".pl") =~ s/::/_/g;

my $script_src = ""; # script that will be run by msub

$script_src = "".
    "#!/hgsc_software/perl/latest/bin/\n".
    "\n".
    "use strict;\n".
    "use warnings;\n".
    "use diagnostics;\n".
    "\n".
    "use ".$options{'module-name'}.";\n".
    "use Concordance::Common::Scheduler;\n".
    "use Getopt::Long;\n".
    "use Pod::Usage;\n".
    "\n".
    "my \%options = ();\n".
    "\n"; 

my %moose_to_getoptlong_type_mapping = (
    'Str' => 's',
    'Int' => 'i',
    'Num' => 'i'
);

my $meta  = $options{'module-name'}->meta;

$script_src .= "GetOptions(\n\t\\%options,\n";

# parameters for Scheduler
$script_src .= "\t'script-path=s',\n".
    "\t'cores=i',\n".
    "\t'memory-in-mb=i',\n".
    "\t'priority=s',\n";
# get script parameters based off of module attributes
for my $attribute ( $meta->get_all_attributes ) {
    $script_src .= "\t'".$attribute->name."=".$moose_to_getoptlong_type_mapping{$attribute->type_constraint->parent}."',\n";
}
$script_src .= "\t'help|?',\n\t'man'\n);";

$script_src .= "\n\n".
    "pod2usage(-exitstatus => 0, -verbose => 1) if defined(\$options{help});\n".
    "pod2usage(-exitstatus => 0, -verbose => 2) if defined(\$options{man});\n".
    "pod2usage(-exitstatus => 0, -verbose => 1) if scalar keys \%options == 0;\n".
    "\n";

my $cmd = "\"perl -I /users/p-qc/dev_concordance_pipeline \".\$options{'script-path'}.\" ";

for my $attribute ( $meta->get_all_attributes ) {
    $cmd .= "--".$attribute->name."=\".\$options{'".$attribute->name."'}.\" ";
}


$script_src .= "my \$cmd = $cmd\";\n".
    "(my \$job_prefix = \$options{'script-path'}) ".
    "=~ s/.*\\/([^\\/]+)\\.pl/\$1/;\n\n";

$script_src .= "my \$scheduler = Concordance::Common::Scheduler->new;\n".
    "\$scheduler->command(\$cmd);\n".
    "\$scheduler->job_name_prefix(\$job_prefix.\"_\".\$\$);\n".
    "\$scheduler->cores(\$options{'cores'});\n".
    "\$scheduler->memory(\$options{'memory-in-mb'});\n".
    "\$scheduler->priority(\$options{'priority'});\n".
    "\$scheduler->execute;\n";

# generate perldoc
$script_src .= "\n=head1 NAME\n".
    "\n".
    "B<$msub_script_file_name> - msub wrapper script for class ".$options{'module-name'}."\n".
    "\n".
    "=head1 SYNOPSIS\n\n".
    "B<$msub_script_file_name>";

for my $attribute ( $meta->get_all_attributes ) {
    $script_src .= " [--".$attribute->name."=".$attribute->type_constraint->name."]";
}
$script_src .= " [--script-path=/path/to/moab/wrapper/script]  ".
    "[--cores=number of dedicated cores] ".
    "[--memory-in-mb=amount of dedicated memory in megabytes] ".
    "[--priority=job priority level]";

$script_src .= " [--man] [--help] [--?]\n\n".
    "Options:\n\n";

$script_src .= " --script-path\tThe path to the module's Moab wrapper script\n".
    " --cores\tThe number of cores to commit to this job\n".
    " --memory-in-mb\tThe amount of memory (in megabytes) to commit to this job\n".
    " --priority\tThe priority level for this job\n";

for my $attribute ( $meta->get_all_attributes ) {
    $script_src .= " --".$attribute->name."\t".$attribute->documentation."\n";
}

$script_src .= "\n=head1 OPTIONS\n\n".
    "=over 8\n\n".
    "=item B<--script-path>\n\nThe path to the Moab wrapper script\n\n".
    "=item B<--cores>\n\nThe number of cores to commit to this job\n\n".
    "=item B<--memory-in-mb>\n\nThe amount of memory (in megabytes) to commit to this job\n\n".
    "=item B<--priority>\n\nThe priority level for this job\n\n";

for my $attribute ( $meta->get_all_attributes ) {
    $script_src .= "=item B<--".$attribute->name.">\n\n".$attribute->documentation."\n\n";
}

$script_src .= "=item B<--help|?>\n\n".
    "Prints a short help message concerning usage of this script.\n\n".
    "=item B<--man>\n\n".
    "Prints a man page containing detailed usage of this script.\n\n".
    "=back\n\n".
    "=head1 DESCRIPTION\n\n".
    "This is an automatically generated script to allow jobs to be submitted to ".
    "Moab utilizing the ".$options{'module-name'}." module.\n\n".
    "=head1 LICENSE\n\n".
    "GPLv3\n\n".
    "=head1 AUTHOR\n\n".
    "John McAdams - L<mailto:mcadams\@bcm.edu>\n\n".
    "=cut\n\n";

open(FOUT_WRAPPER_SCRIPT, ">".$msub_script_file_name) or die $!;
print FOUT_WRAPPER_SCRIPT $script_src."\n";
close(FOUT_WRAPPER_SCRIPT) or warn $!;

=head1 NAME

B<msub_module_wrapper_generator> - generate a script to sumbmit to moab a module wrapper script

=head1 SYNOPSIS

perl -mFully::Qualified::Module B<msub_module_wrapper_generator.pl> - [--module-name=Fully::Qualified::Module] [--help|?] [--man]

Options:

 --module-name    The fully qualifed module for which to generate an msub wrapper script
 --help|?    Prints a brief help message
 --man        Prints an extended help message

=head1 OPTIONS

=over 8

=item B<--module-name>

The fully qualifed module for which to generate an msub wrapper script.

=item B<--help|?>

Prints a brief help message.

=item B<--man>

Prints an extended help message.

=back

=head1 DESCRIPTION

B<msub_module_wrapper_generator> generates a wrapper script to submit a moab module wrapper script, which instantiates and executes a module.  This is intended to allow for discrete functional units to be written in an OO style while providing an automated way to run them as scripts on the cluster.  This leverages Moose's introspection abilities to automatically generate scripts that require arguments matching the class fields.

=head1 LICENSE

GPLv3

=head1 AUTHOR

John McAdams - (mcadams@bcm.edu)

=cut
