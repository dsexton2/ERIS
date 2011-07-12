#! /usr/bin/perl -w

##############################################################################
#	Change_AA_to_0.pl
#
#	Modified by David Sexton 06/28/11
#
#	This script is intended to change Illumina AA/AB/BB genotype encoding to 
#	0/1/2 Birdseed encoding.  It will take in all text files in a directory and 
#	attempt to make this conversion.
#
#	Usage: perl Change_AA_to_0.pl
#
#	This script needs to be modified to ignore .txt files which do not contain
#	genotype calls.
#
##############################################################################

package Concordance::Change_AA_to_0;

use strict;
use warnings;
use Log::Log4perl;

my $error_log = Log::Log4perl->get_logger("errorLogger");
my $debug_log = Log::Log4perl->get_logger("debugLogger");

sub new {
	my $self = {};
	$self->{PATH} = undef;
	bless($self);
	return $self;
}

sub path {
	my $self = shift;
	if (@_) { $self->{PATH} = shift; }
	return $self->{PATH};
}

sub change_aa_to_0 {
	my $self = shift;

	my @files=glob($self->path."/*.txt"); #Take in all text files
	my $file;
	foreach $file(@files) # Iterate over files and open each. 
	{
		$debug_log->debug("processing file: $file\n");
	
		open(FIN,"$file") || die ($error_log->error("Could not open $file: $!"));
	
		$file =~ s/\.[^.]+$//; 				#remove .txt suffix
	
		my $outfile = $file.".birdseed.data.txt";
	
		#my $errorfile = $file.".error";
	
		open(FOUT,"> $outfile") || die "Could not open $outfile: $!";
	
		#open(FERR,"> $errorfile") || die "Could not open $errorfile: $!";
			
		#print FERR "$file\n";
		
		$error_log->error("$file\n");
		
	
		my @lines = <FIN>; 					#Pump file contents to an array
	
		foreach my $line(@lines) 			#Iterate over lines
		{
			chomp($line);
			
			if ($line =~ m/^(#|Probe)/)  		#If line begins with "#" or "Prob" print line
			{
				print FOUT "$line\n";
			}
			else 						#otherwise split line on tabs.
			{
				my @a=split(/\t/, $line);
				my $size=@a;
				my $a;
				if($size != 3) 		#Is array the correct size?
				{
					#$print STDERR "1\t$size\t$file\n";
					$error_log->error("1\t$size\t$file\n");
					next;
				}
				if($a[1] eq "AA") 	#make changes to genotype calls	
				{
					print FOUT "$a[0]\t0\t$a[2]\n";
				}
				elsif($a[1] eq "AB")
				{
					print FOUT "$a[0]\t1\t$a[2]\n";
				}
				elsif($a[1] eq "BB")
				{
					print FOUT "$a[0]\t2\t$a[2]\n";
				}
				else
				{
					#print FERR "$a[0]\t$a[1]\t$file\n";
					$error_log->error("$a[0]\t$a[1]\t$file\n");
				}
			}
		}
		close(FIN);
		close(FOUT);
	}
}
