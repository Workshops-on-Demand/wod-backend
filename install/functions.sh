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
	WODAPIDBADMIN=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBADMIN' | sed 's/"//g'`
	if [ _"$WODAPIDBADMIN" = _"null" ]; then
		WODAPIDBADMIN=""
	fi
	WODAPIDBUSERPWD=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSERPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBUSERPWD" = _"null" ]; then
		WODAPIDBUSERPWD=""
	fi
	WODAPIDBADMINPWD=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBADMINPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBADMINPWD" = _"null" ]; then
		WODAPIDBADMINPWD=""
	fi
fi
if [ -f "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" ]; then
	WODAPIDBUSER2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER' | sed 's/"//g'`
	if [ _"$WODAPIDBUSER2" = _"null" ]; then
		WODAPIDBUSER2=""
	fi
	WODAPIDBADMIN2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBADMIN' | sed 's/"//g'`
	if [ _"$WODAPIDBADMIN2" = _"null" ]; then
		WODAPIDBADMIN2=""
	fi
	WODAPIDBUSERPWD2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSERPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBUSERPWD2" = _"null" ]; then
		WODAPIDBUSERPWD2=""
	fi
	WODAPIDBADMINPWD2=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBADMINPWD' | sed 's/"//g'`
	if [ _"$WODAPIDBADMINPWD2" = _"null" ]; then
		WODAPIDBADMINPWD2=""
	fi
fi
# Overload standard with private if anything declared there
if [ _"$WODAPIDBUSER2" != _"" ]; then
	WODAPIDBUSER=$WODAPIDBUSER2
fi
if [ _"$WODAPIDBUSERPWD2" != _"" ]; then
	WODAPIDBUSERPWD=$WODAPIDBUSERPWD2
fi
if [ _"$WODAPIDBADMIN2" != _"" ]; then
	WODAPIDBADMIN=$WODAPIDBADMIN2
fi
if [ _"$WODAPIDBADMINPWD2" != _"" ]; then
	WODAPIDBADMINPWD=$WODAPIDBADMINPWD2
fi

if [ _"$WODAPIDBUSER" = _"" ]; then
	echo "You need to configure WODAPIDBUSER in your $PBKDIR ansible variable file"
	WODAPIDBUSER="moderator"
	echo "Using default $WODAPIDBUSER instead"
fi
if [ _"$WODAPIDBUSERPWD" = _"" ]; then
	echo "You need to configure WODAPIDBUSERPWD in your $PBKDIR ansible variable file"
	WODAPIDBUSERPWD="UnMotDePassCompliqué"
	echo "Using default $WODAPIDBUSERPWD instead"
fi
if [ _"$WODAPIDBADMIN" = _"" ]; then
	echo "You need to configure WODAPIDBADMIN in your $PBKDIR ansible variable file"
	WODAPIDBADMIN="hackshack"
	echo "Using default $WODAPIDBADMIN instead"
fi
if [ _"$WODAPIDBADMINPWD" = _"" ]; then
	echo "You need to configure WODAPIDBADMINPWD in your $PBKDIR ansible variable file"
	WODAPIDBADMINPWD="UnAutreMotDePassCompliqué"
	echo "Using default $WODAPIDBADMINPWD instead"
fi
export WODAPIDBUSER
export WODAPIDBUSERPWD
export WODAPIDBADMIN
export WODAPIDBADMINPWD
}

