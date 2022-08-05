#!/usr/bin/perl -w
#
use strict;
use Getopt::Long;

sub usage {
	print "Syntax: build-vagrant.pl [-t (backend|frontend|api-db)]\n";
	print "\n";
	print "where you can give the type of wod system to build with the -t option\n";
	print "not specifying the option launch the build for all the 3 systems sequentially\n";
	exit(-1);
}

my $wodtype = undef;
my $help;
GetOptions("type|t=s" => \$wodtype,
	   "help|h" => \$help,
);

usage() if ($help || defined $ARGV[0]); 

# Automate Wod systems creation
my %machines = (
	'api-db' => "wod-api-ubuntu-20.04",
	'frontend' => "wod-fe-ubuntu-20.04",
	'backend' => "wod-be-centos-7",
);
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
	system("vagrant ssh  $h->{$m} -c \"sudo /vagrant/install.sh -t $m -g production -b wod-be-centos-7 -f wod-fe-ubuntu-20.04 -s wod-api-ubuntu-20.04\"");
}
