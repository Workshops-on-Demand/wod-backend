#!/bin/bash

set -e
set -u
set -o pipefail
# Script to customize a Rocky 8 distribution so it's ready for a WoD usage

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
dnf -y install $PKGLIST
