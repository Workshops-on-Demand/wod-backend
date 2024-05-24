#!/usr/bin/perl -w
#
# Build the workshop seeder file to create the correct Workshops during install time
# Need to be called after wod.sh has been sourced
# Done automatically at intalls time

use strict;
use YAML::Tiny;
use Data::Dumper;
use open ":std", ":encoding(UTF-8)"; # to avoid wide char in print msgs

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

# Generating workshop seeder file
my $seederfile = "$ENV{'WODAPIDBDIR'}/seeders/01-workshop.js";

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print(WKSHP "'use strict';\n\n") if ($seederfile =~ /01-/);
print(WKSHP "module.exports = {\n");
print(WKSHP "  up: (queryInterface, Sequelize) => {\n");
print(WKSHP "    return queryInterface.bulkInsert('workshops', [\n");
foreach my $w (sort keys %$h) {
	print(WKSHP "      {\n");
	foreach my $f (sort keys %{$h->{$w}}) {
		#print "Looking at $f: ***$h->{$w}->{$f}***\n";
		## If boolean or integer or array no quoting needed
		if (($h->{$w}->{$f} =~ /true/) || ($h->{$w}->{$f} =~ /false/) || ($h->{$w}->{$f} =~ /^[0-9]+$/) ||  ($h->{$w}->{$f} =~ /\[/)) {
			print(WKSHP "        $f: $h->{$w}->{$f},\n");
		} else {
			if ($h->{$w}->{$f} =~ /'/) {
				print(WKSHP "        $f: \"$h->{$w}->{$f}\",\n");
			} else {
				print(WKSHP "        $f: '$h->{$w}->{$f}',\n");
			}
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
print(WKSHP "    return queryInterface.bulkDelete('Workshops', null, {});\n");
print(WKSHP "  },\n");
print(WKSHP "};\n");
close(WKSHP);

# Now deal with students
$seederfile = "$ENV{'WODAPIDBDIR'}/seeders/03-students.js";

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print(WKSHP "const N = $ENV{'USERMAX'}\n\n");

# TODO: Loop per location,once locations are managed properly
print WKSHP <<'EOF';
module.exports = {
  up: (queryInterface) => {
    const arr3 = [...Array(N + 1).keys()].slice(1);
    const entries3 = arr3.map((key) => ({
      createdAt: new Date(),
      updatedAt: new Date(),
EOF
# This variable exists when that script is called at install
# TODO: Also get it at run time for upgrade
my $wodbeextfqdn = "";
my $pbkdir = "";
$wodbeextfqdn = $ENV{'WODBEEXTFQDN'} if (defined $ENV{'WODBEEXTFQDN'});
$pbkdir = $ENV{'PBKDIR'} if (defined $ENV{'PBKDIR'});
print(WKSHP "      url: \`$wodbeextfqdn/user/student");
print WKSHP <<'EOF';
${key}/lab?`,
      username: `student${key}`,
      password: 'MyNewPassword',
EOF
print(WKSHP "      location: '$pbkdir',\n");
print WKSHP <<'EOF';
    }));

    let entries = [...entries3];

    return queryInterface.bulkInsert('students', entries, { returning: true });
  },
  down: (queryInterface) => queryInterface.bulkDelete('students', null, {}),
};
EOF
close(WKSHP);

# Now deal with users
$seederfile = "$ENV{'WODAPIDBDIR'}/seeders/06-users.js";

print "Generate the seeder file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
print WKSHP <<"EOF";
const getDates = () => {
  const startDate = new Date();
  const endDate = new Date();
  //start.setDate(start.getDate() - 9 + key);
  endDate.setHours(endDate.getHours() + 4);
  return { startDate, endDate };
};
module.exports = {
  up: (queryInterface) =>
    queryInterface.bulkInsert(
      'users',
      [
        {
          username: '$ENV{'WODAPIDBUSER'}',
          email: 'dummy',
          password: '',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ],
      {
        returning: true,
      }
    ),

  down: (queryInterface) => queryInterface.bulkDelete('users', null, {}),
};
EOF
close(WKSHP);
