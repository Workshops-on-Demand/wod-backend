#!/usr/bin/perl -w
#
use strict;

# Automate Wod server creation
my %machines = (
	'server' => "wod-srv-ubuntu-20.04",
	'frontend' => "wod-fe-ubuntu-20.04",
	'backend' => "wod-be-centos-7",
);
my @mtypes = ();
if (not defined $ARGV[0]) {
	@mtypes = sort keys %machines;
} else {
	@mtypes = @ARGV;
}

my $h = \%machines;
foreach my $m (@mtypes) {
	system("vagrant halt $h->{$m}");
	system("vagrant up $h->{$m}");
	system("vagrant ssh  $h->{$m} -c \"sudo /vagrant/install.sh -t $m -g production -b wod-be-centos-7 -f wod-fe-ubuntu-20.04 -s wod-srv-ubuntu-20.04\"");
}
