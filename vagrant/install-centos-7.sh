#!/bin/bash

# Script to customize a CentOS 7 distribution so it's ready for a WoD usage

# This first part is distribution specific and should be adapted based on its nature

# Base packages required
yum -y install epel-release ansible git openssh-server

# Additional repo for up to date git
yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
yum update git

# Create the jupyter user
useradd -U -m jupyter 
