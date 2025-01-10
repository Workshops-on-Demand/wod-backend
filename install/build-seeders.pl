#!/usr/bin/perl -w
#
# Build the workshop seeder file to create the correct Workshops during install time
# Need to be called after wod.sh has been sourced
# Done automatically at intall time

use strict;
use open ":std", ":encoding(UTF-8)"; # to avoid wide char in print msgs

# Load functions also used by the update process
use lib "$ENV{'INSTALLDIR'}";
require "functions.pl";

# Calling the subfunction
my $h = get_wod_metadata();

# Generating workshop seeder file
my $seederfile = "$ENV{'WODAPIDBDIR'}/seeders/01-workshop.js";

# The first
my @backends=split(/,/,$ENV{'WODBEFQDN'});
# The others
my @altbackends=@backends[ 1 .. $#backends ];
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
	print(WKSHP "        location: '$backends[0]',\n");
	print(WKSHP "        sessionType: 'Workshops-on-Demand',\n");
	print(WKSHP "        createdAt: new Date(),\n");
	print(WKSHP "        updatedAt: new Date(),\n");
	my $alt="";
	foreach my $a (@altbackends) {
		$alt=$alt."'$a',";
	}
	# remove last ,
	$alt =~ s/,$//;
	print(WKSHP "        alternateLocation: [$alt],\n");
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

# We need to loop for each backend to create USERMAX students, using the correct ids
print(WKSHP "const N = $ENV{'USERMAX'}\n\n");

	print WKSHP <<'EOF';
module.exports = {
  up: (queryInterface) => {
EOF

# Loop per location
my $cpt=0;
while ($cpt < @backends) {
	print WKSHP <<"EOF";
    const arr$cpt = [...Array(N + 1).keys()].slice(1);
    const entries$cpt = arr$cpt.map((key) => ({
      createdAt: new Date(),
      updatedAt: new Date(),
EOF
	# This variable exists when that script is called at install
	# TODO: Also get it at run time for upgrade
	print(WKSHP "      url: \`http://$backends[$cpt]/user/student");
	print WKSHP <<'EOF';
${key}/lab?`,
      username: `student${key}`,
      password: 'MyNewPassword',
EOF
print(WKSHP "      location: '$backends[$cpt]',\n");
print WKSHP <<'EOF';
        }));
EOF
	$cpt++;
}
	print WKSHP "      let entries = [";
$cpt = 0;
while ($cpt < @backends) {
    print WKSHP "...entries$cpt, ";
	$cpt++;
}
	print WKSHP "];\n";

	print WKSHP <<"EOF";
        return queryInterface.bulkInsert('students', entries, { returning: true });
      },
      down: (queryInterface) => queryInterface.bulkDelete('students', null, {}),
    };
EOF
close(WKSHP);

# Now deal with locations
$seederfile = "$ENV{'WODAPIDBDIR'}/seeders/07-location.js";

print "Generate the location file from collected data under $seederfile\n";
open(WKSHP,"> $seederfile") || die "Unable to create $seederfile";
# Loop per location
$cpt=0;
print WKSHP <<"EOF";
module.exports = {
  up: (queryInterface) =>
    queryInterface.bulkInsert(
      'locations',
      [
EOF
while ($cpt < @backends) {
        print WKSHP <<"EOF";
		{
          name: '$backends[$cpt]',
          basestdid: $ENV{'USERMAX'}*$cpt,
          updatedAt: new Date(),
        },
EOF
	$cpt++;
}
print WKSHP <<"EOF";
      ],
      {
        returning: true,
      }
    ),

  down: (queryInterface) => queryInterface.bulkDelete('locations', null, {}),
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
        {
          username: '$ENV{'WODAPIDBADMIN'}',
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
