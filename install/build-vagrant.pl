#!/usr/bin/perl -w
#
use strict;
use Getopt::Long;

sub usage {
	print "Syntax: build-vagrant.pl [-t (backend|frontend|api-db|appliance)][-w WKSHP-Name][-m key=value][-k]\n";
	print "\n";
	print "where you can give the type of wod system to build with the -t option\n";
	print "(not specifying the option launch the build for all the 3 systems sequentially)\n";
	print "\n";
	print "If deploying an appliance, please specify the Workshop Name you're deploying for with -w\n";
	print "\n";
	print "If you want to use specific machine names, please specify the them with -m\n";
	print "Example: -m backend=wodbec8\n";
	print "\n";
	print "If you want to regenerate admin user ssh keys, please specify the -k option\n";
	exit(-1);
}

my $wodtype = undef;
my $wkshp = "";
my $woduser = "wodadmin";
my $localnet = "wodnet.local";
my $help;
my $genkeys;
# Automate Wod systems creation
my %machines = (
	'api-db' => "wodapiu2204",
	'frontend' => "wodfeu2204",
	'backend' => "wodbec7",
);
my $machines = \%machines;
GetOptions("type|t=s" => \$wodtype,
	   "workshop|w" => \$wkshp,
	   "machines|m=s%" => $machines,
	   "help|h" => \$help,
	   "gen-keys|k" => \$genkeys,
);

usage() if ($help || defined $ARGV[0]); 


if ((defined $wodtype) && ($wodtype =~ /appliance/) && ((not defined $wkshp) || ($wkshp !~ /^WKSHP-/))) {
	print "Missing or incorrect workshop name - should be WKSHP-Name\n";
	usage();
}

if ((defined $wodtype) && ($wodtype =~ /appliance/)) {
	# Remove WKSHP prefix
	$wkshp =~ s/^WKSHP-//;
	$machines{'appliance'} = "wodapp".$wkshp;
}

# Manages the private network for machines and DHCP/DNS setup
# TODO: managing this depends on hypervisor type
my $wodnet = `sudo virsh net-list --name`;
if ($wodnet =~ /^vagrant-libvirt$/) {
	system("sudo virsh net-start --network vagrant-libvirt");
}
if ($wodnet =~ /^wodnet$/) {
	system("sudo virsh net-define wodnet.xml");
	system("sudo virsh net-start --network wodnet");
}

my @mtypes = ();
if (not defined $wodtype) {
	@mtypes = sort keys %machines;
} else {
	@mtypes = ($wodtype);
}

my $h = \%machines;
foreach my $m (@mtypes) {
	print "Stopping vagrant machine $h->{$m}\n";
	system("vagrant halt $h->{$m}");
	print "Starting vagrant machine $h->{$m}\n";
	system("vagrant up $h->{$m}");
	print "Getting IP address for vagrant machine $h->{$m}\n";
	open(CMD,"vagrant ssh-config $h->{$m} |") || die "Unable to execute vagrant ssh-config $h->{$m}";
	my $srvip = "";
	my $void;
	while (<CMD>) {
		next if ($_ !~ /HostName/);
		chomp($_);
		$srvip = $_;
		$srvip =~ s/\s+HostName\s+([0-9.]+)\s*/$1/;
		($void,$void,$srvip) = split(/ +/,$_);
		last;
	}
	print "Got $srvip\n";
	print "Installing vagrant machine $h->{$m}\n";
	my $kk = "";
	$kk = "-k" if ($genkeys);
	if ($wodtype =~ /appliance/) {
		system("vagrant ssh $h->{$m} -c \"sudo /vagrant/install.sh -t $m $kk\"");
		print "Setting up vagrant appliance $h->{$m}\n";
		my $cmd = "\"./wod-backend/scripts/setup-appliance $wkshp\"";
		system("vagrant ssh $h->{'backend'} -c \"sudo su - $woduser -c $cmd\"");
	} else {
		system("vagrant ssh $h->{$m} -c \"sudo /vagrant/install.sh -t $m -i $srvip -g production -b $machines{'backend'}.$localnet -f $machines{'frontend'}.$localnet -a $machines{'api-db'}.$localnet -e localhost -u $woduser -s wod\@flossita.org\" $kk");
	}
}
