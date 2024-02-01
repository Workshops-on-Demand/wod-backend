#!/bin/bash
#
# Wrapper for build-workshops.pl
#
SCRIPT=`realpath $0`
# This is the installation directory where install scripts are located.
INSTALLDIR=`dirname $SCRIPT`

source $INSTALLDIR/../scripts/wod.sh
if [ -f "$WODPRIVINV" ]; then
	PRIVINV="-i $WODPRIVINV"
else
	PRIVINV=""
fi
export USERMAX=`ansible-inventory -i $ANSIBLEDIR/inventory $PRIVINV --host `hostname -f` --playbook-dir $ANSIBLEDIR --playbook-dir $ANSIBLEPRIVDIR | jq ".USERMAX"`
$INSTALLDIR/build-seeders.pl
