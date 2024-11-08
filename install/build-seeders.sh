#!/bin/bash
#
# Wrapper for build-seeders.pl
#
SCRIPT=`realpath $0`
# This is the installation directory where install scripts are located.
export INSTALLDIR=`dirname $SCRIPT`

source $INSTALLDIR/functions.sh
source $INSTALLDIR/../scripts/wod.sh
if [ -f "$WODPRIVINV" ]; then
	PRIVINV="-i $WODPRIVINV"
else
	PRIVINV=""
fi
# Only valid for wod-apidb anyway
export USERMAX=`ansible-inventory -i $ANSIBLEDIR/inventory $PRIVINV --host $WODAPIDBFQDN --playbook-dir $ANSIBLEDIR --playbook-dir $ANSIBLEPRIVDIR | jq ".USERMAX"`
get_wodapidb_userpwd
$INSTALLDIR/build-seeders.pl
