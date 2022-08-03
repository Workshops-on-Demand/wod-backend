#!/bin/bash

# This is the second part of the installation process that is called by a specific installation script for a distribution
# Run as root

set -e
set -u
set -o pipefail

# Create the jupyter user

if grep -qE '^jupyter:' /etc/passwd; then
        userdel -f -r jupyter
fi
useradd -U -m jupyter

# Get content for WoD - now in private mode
su - jupyter -c "rm -rf wod-server.git .ssh"
token=`cat /vagrant/token`
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-server.git"
#su - jupyter -c "git clone https://github.com/Workshops-on-Demand/wod-server.git"

#Setup ssh for jupyter
su - jupyter -c "ssh-keygen -t rsa -b 4096 -N '' -f ~jupyter/.ssh/id_rsa"
su - jupyter -c "cat ~jupyter/.ssh/id_rsa.pub >> ~jupyter/.ssh/authorized_keys"

# setup sudo for jupyter
cat > /etc/sudoers.d/jupyter << EOF
Defaults:jupyter !fqdn
Defaults:jupyter !requiretty
jupyter ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/jupyter

cd wod-server/server

# Change default passwd for vagrant and root

# Install WoD
su - jupyter -c "./wod-server/install_backend.sh"
