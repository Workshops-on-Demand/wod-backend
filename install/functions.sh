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
	WODAPIDBUSER=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER' | sed 's/"//g'`
	if [ _"$WODAPIDBUSER" = _"null" ]; then
		WODAPIDBUSER=""
	fi
	WODAPIDBPWD=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBPWD" = _"null" ]; then
		WODAPIDBPWD=""
	fi
fi
if [ -f "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" ]; then
	WODAPIDBUSER2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER' | sed 's/"//g'`
	if [ _"$WODAPIDBUSER2" = _"null" ]; then
		WODAPIDBUSER2=""
	fi
	WODAPIDBPWD2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBPWD2" = _"null" ]; then
		WODAPIDBPWD2=""
	fi
fi
# Overload standard with private if anything declared there
if [ _"$WODAPIDBUSER2" != _"" ]; then
	WODAPIDBUSER=$WODAPIDBUSER2
fi
if [ _"$WODAPIDBPWD2" != _"" ]; then
	WODAPIDBPWD=$WODAPIDBPWD2
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

