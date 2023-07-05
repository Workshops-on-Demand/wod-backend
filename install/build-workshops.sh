#!/bin/bash
#
# Wrapper for build-workshops.pl
#
SCRIPT=`realpath $0`
# This is the installation directory where install scripts are located.
INSTALLDIR=`dirname $SCRIPT`

source $INSTALLDIR/../scripts/wod.sh
$INSTALLDIR/build-workshops.pl
