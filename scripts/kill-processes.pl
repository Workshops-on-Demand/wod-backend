#!/usr/bin/perl -w

use strict;
use Data::Dumper;

open(PIPE,"top -b -d 60 |") || die "Unable to execute top";
# skip 7 first line of headers
while (<PIPE>) {
        my @fields = split(/ +/,$_);
	#print Dumper(@fields) if ($fields[12] =~ /bash/);
	next if ($fields[0] =~ /^[A-z%]..*$/);
	next if ($fields[0] =~ /^[\s]+$/);
        $fields[0] =~ s/^ *//;
	next if ($fields[1] =~ /^PID/);
        # Does it use 100% ?
        $fields[9] =~ s/,/./;
	#print "PID: $fields[1]\n" if ($fields[12] =~ /bash/);
	#print "CPU: $fields[9]\n" if ($fields[12] =~ /bash/);
        if ($fields[9] >= 98) {
        	print "CPU% : $fields[9]\n";
        	if ((defined $fields[2]) && ($fields[2] =~ /^student/)) {
                        my $d=`date`;
                        print chomp($d)."- Killing $fields[1] - $fields[12]";
                        system("sudo kill $fields[1]");
                }
        }
}
