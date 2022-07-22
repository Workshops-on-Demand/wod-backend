#!/bin/bash

# Script to customize an Ubuntu 20.04 distribution so it's ready for a WoD usage
# This first part is distribution specific and should be adapted based on its nature

# Base packages required
apt install -y ansible git openssh-server jq

# Create the jupyter user
userdel -f -r jupyter
useradd -U -m jupyter 
