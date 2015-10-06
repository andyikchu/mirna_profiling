#!/usr/bin/env perl
use strict;
use Getopt::Std;
use Pod::Usage;
use File::Find;
use File::Basename;
use File::Copy;

use vars qw($opt_p);
getopts("p:");

my $usage = "$0 -p project_directory\n";
die "$usage" unless $opt_p;

my $r = get_config();

print STDERR "Searching for .sam files to in project directory...\n";
my @samfiles;
find(\&findsamfiles, $opt_p);
print STDERR "Done\n";
die "No sam files found in $opt_p" unless scalar @samfiles;

my $dir = dirname(__FILE__); #R scripts are in the same directory as this script

mkdir "$opt_p/graphs" unless -e "$opt_p/graphs";
mkdir "$opt_p/graphs/tags" unless -e "$opt_p/graphs/tags";
mkdir "$opt_p/graphs/adapter" unless -e "$opt_p/graphs/adapter";

foreach my $samfile (@samfiles) {
	my $samdir = dirname($samfile);
	my $filename = basename($samfile);
	$filename =~ s/\.[bs]am$//;
	my ($lib, $index) = split('_', $filename);
	$index = '' unless defined $index;

	my $datadir = "$samdir/$filename\_features";
	my $filtered_file = "$datadir/filtered_taglengths.csv";
	my $softclip_file = "$datadir/softclip_taglengths.csv";
	my $chastity_file = "$datadir/chastity_taglengths.csv";
	my $adapter_file = "$samdir/$filename\_adapter.report";
	
	system "$r CMD BATCH \"--args $datadir $filename $filtered_file tags\" $dir/taglengths.R";
	system "$r CMD BATCH \"--args $datadir $filename $softclip_file softclip\" $dir/taglengths.R";
	system "$r CMD BATCH \"--args $datadir $filename $chastity_file chastity\" $dir/taglengths.R";

	system "$r CMD BATCH \"--args $datadir $filename $adapter_file adapter \" $dir/adapter.R" if -e $adapter_file;

	#make a copy of tags and adapter under the graphs directory for each access
	copy("$datadir/$filename\_tags.jpg", "$opt_p/graphs/tags/$filename\_tags.jpg");
	copy("$datadir/$filename\_adapter.jpg", "$opt_p/graphs/adapter/$filename\_adapter.jpg");
}

my $proj = basename($opt_p); #use project name for saturation graph title
#get the repools and failed libraries in the saturation graph
copy("$opt_p/alignment_stats.csv", "$opt_p/alignment_stats.saturation.csv");
system "grep -v Library $opt_p/repool/alignment_stats.csv >> $opt_p/alignment_stats.saturation.csv" if -e "$opt_p/repool/alignment_stats.csv";
system "grep -v Library $opt_p/obsoleted/repool/alignment_stats.csv >> $opt_p/alignment_stats.saturation.csv" if -e "$opt_p/obsoleted/repool/alignment_stats.csv";

system "$r CMD BATCH \"--args $opt_p/graphs/$proj\_saturation.jpg ".uc($proj)." $opt_p/alignment_stats.saturation.csv\" $dir/saturation.R";

system "rm -f $opt_p/alignment_stats.saturation.csv";

sub findsamfiles {
	if ($File::Find::name =~ /\.sam$/ || $File::Find::name =~ /\.bam$/) {
		#skip specialized analyses within _features directories
		next if $File::Find::name =~ /_features/;
		#skip files in obsoleted directory
		next if $File::Find::name =~ /obsoleted/;
		push(@samfiles, $File::Find::name);
		print STDERR "\t$File::Find::name\n";
	}
}

sub get_config {
	my $dir = dirname(__FILE__);
	my $config_file = "$dir/../../config/pipeline_params.cfg";
	
	open CONFIG, $config_file or die "Could not find config file in default location ($config_file)";
	my @config = <CONFIG>;
	close CONFIG;
	chomp @config;
	
	my ($r) = [grep(/^\s*R/, @config)]->[0] =~ /^\s*R\s*=\s*(.+)/ or die "No entry found for R binary in config file.";
	return $r;
}
