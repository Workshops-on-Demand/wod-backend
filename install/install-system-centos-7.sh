#!/bin/bash

set -e
set -u
set -o pipefail
# Script to customize a CentOS 7 distribution so it's ready for a WoD usage

# This first part is distribution specific and should be adapted based on its nature

# First stay with IPv4 for my setup
if grep -qv 'ip_resolve=4' /etc/yum.conf; then
	echo "ip_resolve=4" >> /etc/yum.conf
fi

PKGLIST="epel-release perl ansible openssh-server"

if [ $WODTYPE != "appliance" ]; then
	PKGLIST="$PKGLIST git jq npm"
fi

# Base packages required
yum -y install $PKGLIST
# yarn is needed for server TBChecked requires an additional repo

if [ $WODTYPE != "appliance" ]; then
	# Additional repo for up to date git
	if rpm -q --quiet endpoint-repo; then
		# Do nothing
		echo ""
	else
		yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
	fi
	yum -y update git
fi
