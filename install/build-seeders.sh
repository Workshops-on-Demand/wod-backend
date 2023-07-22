#!/bin/bash
#
# Wrapper for build-workshops.pl
#
SCRIPT=`realpath $0`
# This is the installation directory where install scripts are located.
INSTALLDIR=`dirname $SCRIPT`

source $INSTALLDIR/../scripts/wod.sh
if [ -f "$ANSIBLEPRIVDIR/inventory" ]; then
	PRIVINV="-i $ANSIBLEPRIVDIR/inventory"
else
	PRIVINV=""
fi
export USERMAX=`ansible-inventory -i $ANSIBLEDIR/inventory $PRIVINV --list | jq "._meta.hostvars.\"127.0.0.1\".USERMAX"`
$INSTALLDIR/build-seeders.pl
