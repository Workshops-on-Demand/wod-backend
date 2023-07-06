#!/usr/bin/perl -w
#
# Build the workshop seeder file to create the correct Workshops during install time
# Need to be called after wod.sh has been sourced
# Done automatically at intalls time

use strict;
use YAML::Tiny;
use Data::Dumper;

my $seederfile = "$ENV{'WODAPIDBDIR'}/seeders/01-workshop.js";

my $h = {};

# Analyses metadata stored within Workshops
# TODO: WODPRIVNOBO
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
print "Data gathered from YAML files wod.yml under $ENV{'WODNOBO'}\n";
print Dumper($h);

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print(WKSHP "'use strict';\n\n");
print(WKSHP "module.exports = {\n");
print(WKSHP "  up: (queryInterface, Sequelize) => {\n");
print(WKSHP "    return queryInterface.bulkInsert('workshops', [\n");
# TODO: generate 06_replays or merge with 01_workshop
foreach my $w (keys %$h) {
	print(WKSHP "      {\n");
	foreach my $f (keys %{$h->{$w}}) {
		#print "Looking at $f: ***$h->{$w}->{$f}***\n";
		if (($h->{$w}->{$f} =~ /true/) || ($h->{$w}->{$f} =~ /false/) || ($h->{$w}->{$f} =~ /^[0-9]+$/)) {
			print(WKSHP "        $f: $h->{$w}->{$f},\n");
		} else {
			print(WKSHP "        $f: '$h->{$w}->{$f}',\n");
		}
	}
	print(WKSHP "        notebook: '$w',\n");
	print(WKSHP "        active: true,\n");
	print(WKSHP "        sessionType: 'Workshops-on-Demand',\n");
	print(WKSHP "        createdAt: new Date(),\n");
	print(WKSHP "        updatedAt: new Date(),\n");
	print(WKSHP "      },\n");
}
print(WKSHP "    ]);\n");
print(WKSHP "  },\n");
print(WKSHP "  down: (queryInterface, Sequelize) => {\n");
print(WKSHP "  },\n");
print(WKSHP "};\n");
close(WKSHP);
