#!/bin/bash
#
# Functions called from other install scripts
#
# (c) Bruno Cornec <bruno.cornec@hpe.com>, Hewlett Packard Development
# Released under the GPLv2 License
#
set -e
#set -x

# This function fetches the DB user/passwd
get_wodapidb_userpwd() {
if [ -f "$ANSIBLEDIR/group_vars/$PBKDIR" ]; then
	WODAPIDBUSER=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER'`
	WODAPIDBPWD=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD'`
fi
if [ -f "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" ]; then
	WODAPIDBUSER=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER'`
	WODAPIDBPWD=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD'`
fi
if [ _"$WODAPIDBUSER" = _"" ]; then
	echo "You need to configure WODAPIDBUSER in your $PBKDIR ansible variable file"
	WODAPIDBUSER="moderator"
	echo "Using default $WODAPIDBUSER instead"
fi
if [ _"$WODAPIDBPWD" = _"" ]; then
	echo "You need to configure WODAPIDBPWD in your $PBKDIR ansible variable file"
	WODAPIDBPWD="UnMotDePassCompliqué"
	echo "Using default $WODAPIDBPWD instead"
fi
export WODAPIDBUSER
export WODAPIDBPWD
}

