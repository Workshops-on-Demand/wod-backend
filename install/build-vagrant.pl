#!/usr/bin/perl -w
#
use strict;
use Getopt::Long;

sub usage {
	print "Syntax: build-vagrant.pl [-t (backend|frontend|api-db|appliance)][-w WKSHP-Name]\n";
	print "\n";
	print "where you can give the type of wod system to build with the -t option\n";
	print "not specifying the option launch the build for all the 3 systems sequentially\n";
	exit(-1);
}

my $wodtype = undef;
my $wkshp = "";
my $help;
GetOptions("type|t=s" => \$wodtype,
	   "workshop|w" => \$wkshp,
	   "help|h" => \$help,
);

usage() if ($help || defined $ARGV[0]); 

# Automate Wod systems creation
my %machines = (
	'api-db' => "wod-api-ubuntu-20.04",
	'frontend' => "wod-fe-ubuntu-20.04",
	'backend' => "wod-be-centos-7",
	'appliance' => "wod-$wkshp-centos-7",
);

if (($wodtype =~ /appliance/) && ((not defined $wkshp) || ($wkshp !~ /^WKSHP-/))) {
	print "missing or incorrect workshop name - should be WKSHP-Name\n";
	usage();
}

my @mtypes = ();
if (not defined $wodtype) {
	@mtypes = sort keys %machines;
} else {
	@mtypes = ($wodtype);
}

my $h = \%machines;
foreach my $m (@mtypes) {
	system("vagrant halt $h->{$m}");
	system("vagrant up $h->{$m}");
	if ($wodtype =~ /appliance/) {
		# We need to find who is the WODUSER to use it
		my $WODUSER=`vagrant ssh  $h->{'backend'} -c grep -Ev 'WODUSER' /etc/wod.yml | cut -d: -f2`;
		my $cmd = "sudo su - $WODUSER -c \"./wod-backend/scripts/setup-appliance $wkshp\"";
		system("vagrant ssh $h->{'backend'} -c \"sudo su - $WODUSER -c $cmd\"");
	} else {
		system("vagrant ssh $h->{$m} -c \"sudo /vagrant/install.sh -t $m -g production -b wod-be-centos-7 -f wod-fe-ubuntu-20.04 -a wod-api-ubuntu-20.04\"");
	}
}
