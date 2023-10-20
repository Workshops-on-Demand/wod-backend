#!/usr/bin/perl -w
#
# Build the workshop seeder file to create the correct Workshops during install time
# Need to be called after wod.sh has been sourced
# Done automatically at intalls time

use strict;
use YAML::Tiny;
use Data::Dumper;

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
print Dumper($h);

# Generating workshop seeder file
my $seederfile = "$ENV{'WODAPIDBDIR'}/seeders/01-workshop.js";

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print(WKSHP "'use strict';\n\n") if ($seederfile =~ /01-/);
print(WKSHP "module.exports = {\n");
if ($seederfile =~ /01-/) {
	print(WKSHP "  up: (queryInterface, Sequelize) => {\n    return ");
} else {
	print(WKSHP "  up: (queryInterface) => \n");
}
print(WKSHP "    queryInterface.bulkInsert('");
if ($seederfile =~ /01-/) {
	print(WKSHP "workshops', [\n");
} else {
	print(WKSHP "replays', [\n");
}
foreach my $w (keys %$h) {
	print(WKSHP "      {\n");
	foreach my $f (keys %{$h->{$w}}) {
		#print "Looking at $f: ***$h->{$w}->{$f}***\n";
		if (($h->{$w}->{$f} =~ /true/) || ($h->{$w}->{$f} =~ /false/) || ($h->{$w}->{$f} =~ /^[0-9]+$/)) {
			print(WKSHP "        $f: $h->{$w}->{$f},\n");
		} else {
			if ($h->{$w}->{$f} =~ /'/) {
				print(WKSHP "        $f: \"$h->{$w}->{$f}\",\n");
			} else {
				print(WKSHP "        $f: '$h->{$w}->{$f}',\n");
			}
		}
	}
	if ($seederfile =~ /01-/) {
		print(WKSHP "        notebook: '$w',\n");
		print(WKSHP "        active: true,\n");
		print(WKSHP "        sessionType: 'Workshops-on-Demand',\n");
	}
	print(WKSHP "        createdAt: new Date(),\n");
	print(WKSHP "        updatedAt: new Date(),\n");
	print(WKSHP "      },\n");
}
if ($seederfile =~ /01-/) {
	print(WKSHP "    ]);\n");
	print(WKSHP "  },\n");
	print(WKSHP "  down: (queryInterface, Sequelize) => {\n");
	print(WKSHP "    return queryInterface.bulkDelete('Workshops', null, {});\n");
	print(WKSHP "  },\n");
} else {
	print(WKSHP "    ],\n");
	print(WKSHP "  {\n");
	print(WKSHP "      returning: true, \n");
	print(WKSHP "  }\n");
	print(WKSHP "),\n\n");
	print(WKSHP "  down: (queryInterface) => queryInterface.bulkDelete('replays', null, {}),\n");
	print(WKSHP "  },\n");
}
print(WKSHP "};\n");
close(WKSHP);

# Now deal with students
$seederfile = "$ENV{'WODAPIDBDIR'}/seeders/04-students.js";

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print(WKSHP "const N = $ENV{'USERMAX'}\n\n");

# TODO: Loop per location,once locations aremanaged properly
print WKSHP <<'EOF';
module.exports = {
  up: (queryInterface) => {
    const arr = [...Array(N + 1).keys()].slice(1);
    const entries1 = arr.map((key) => ({
      createdAt: new Date(),
      updatedAt: new Date(),
      url: `
EOF
# This variable exists when that script is called at install
# TODO: Also get it at run time for upgrade
my $wodbeextfqdn = "";
$wodbeextfqdn = $ENV{'WODBEEXTFQDN'} if (defined $ENV{'WODBEEXTFQDN'});
print(WKSHP "$wodbeextfqdn/user/student");
print WKSHP <<'EOF';
${key}/lab?`,
      username: `student${key}`,
      password: 'MyNewPassword',
      location: 'mougins',
    }));

    const arr2 = [...Array(N + 1).keys()].slice(1);
    const entries2 = arr2.map((key) => ({
      createdAt: new Date(),
      updatedAt: new Date(),
      url: `
EOF
print(WKSHP "https://notebooks2.hpedev.io/user/student");
print WKSHP <<'EOF';
${key}/lab?`,
      username: `student\${key}`,
      password: 'MyNewPassword',
      location: 'grenoble',
    }));

    let entries = [...entries1, ...entries2];

    return queryInterface.bulkInsert('students', entries, { returning: true });
  },
  down: (queryInterface) => queryInterface.bulkDelete('students', null, {}),
};
EOF
close(WKSHP);
