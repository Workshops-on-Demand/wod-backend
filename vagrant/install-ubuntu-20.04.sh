#!/bin/bash

set -e

# Script to customize an Ubuntu 20.04 distribution so it's ready for a WoD usage
# This first part is distribution specific and should be adapted based on its nature

# Base packages required
apt install -y ansible git openssh-server jq

# Create the jupyter user
grep -qE '^jupyter:' /etc/passwd
if [ $? -eq 0 ]; then
        userdel -f -r jupyter
fi
useradd -U -m jupyter 
