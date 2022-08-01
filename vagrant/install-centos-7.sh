#!/bin/bash

set -e
# Script to customize a CentOS 7 distribution so it's ready for a WoD usage

# This first part is distribution specific and should be adapted based on its nature

# First stay with IPv4 for my setup
grep -q 'ip_resolve=4' /etc/yum.conf
if [ $? -ne 0 ]; then
	echo "ip_resolve=4" >> /etc/yum.conf
fi

# Base packages required
yum -y install epel-release ansible git openssh-server jq

# Additional repo for up to date git
rpm -q --quiet endpoint-repo
if [ $? -ne 0 ]; then
	yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
fi
yum -y update git

# Create the jupyter user
grep -qE '^jupyter:' /etc/passwd
if [ $? -eq 0 ]; then
	userdel -f -r jupyter
fi
useradd -U -m jupyter 
