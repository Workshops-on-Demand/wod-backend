#!/usr/bin/perl -w
#
# Build the workshop seeder file to create the correct Workshops during install time
# Need to be called after wod.sh has been sourced
# Done automatically at intall time

use strict;
use Data::Dumper;
use YAML::Tiny;
use open ":std", ":encoding(UTF-8)"; # to avoid wide char in print msgs

sub get_wod_metadata {

my $h = {};

# Analyses metadata stored within Workshops both public and private
opendir(DIR,$ENV{'WODNOBO'}) || die "Unable to open directory $ENV{'WODNOBO'}";
while (my $wkshp = readdir(DIR)) {
	next if ($wkshp =~ /^\./);
	my $meta = "$ENV{'WODNOBO'}/$wkshp/wod.yml";
	if (-f "$meta") {
		# Open the config
		my $yaml = YAML::Tiny->read("$meta") || die "Unable to open $meta";
		# Get a reference to the first document
		$h->{$wkshp} = $yaml->[0];
	}
}
closedir(DIR);

if (-d $ENV{'WODPRIVNOBO'}) {
	opendir(PRIVDIR,$ENV{'WODPRIVNOBO'}) || die "Unable to open directory $ENV{'WODPRIVNOBO'}";
	while (my $wkshp = readdir(PRIVDIR)) {
		next if ($wkshp =~ /^\./);
		my $meta = "$ENV{'WODPRIVNOBO'}/$wkshp/wod.yml";
		if (-f "$meta") {
			# Open the config
			my $yaml = YAML::Tiny->read("$meta") || die "Unable to open $meta";
			# Get a reference to the first document
			$h->{$wkshp} = $yaml->[0];
		}
	}
	closedir(PRIVDIR);
}

print "Data gathered from YAML files wod.yml under $ENV{'WODNOBO'}\n";
#print Dumper($h);
return($h);
}
