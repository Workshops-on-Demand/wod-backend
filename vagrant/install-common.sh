#!/bin/bash

# This is the second part of the installation process that is called by a specific installation script for a distribution
# Run as root

set -e

# Get content for WoD - now in private mode
su - jupyter -c "rm -rf wod-backend.git .ssh"
token=`cat /vagrant/token`
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-backend.git"
cat >> ~jupyter/wod-backend/ansible/inventory << EOF

[wod]
wod-$woddistrib 
EOF
#su - jupyter -c "git clone https://github.com/Workshops-on-Demand/wod-backend.git"

#Setup ssh for jupyter
su - jupyter -c "ssh-keygen -t rsa -b 4096 -N '' -f ~jupyter/.ssh/id_rsa"
su - jupyter -c "install -m 0600 wod-backend/skel/.ssh/authorized_keys .ssh/"

# setup sudo for jupyter
cat > /etc/sudoers.d/jupyter << EOF
Defaults:jupyter !fqdn
Defaults:jupyter !requiretty
jupyter ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/jupyter

# Change default passwd for vagrant and root

# Install WoD
su - jupyter -c "cd wod-backend ; ./scripts/install_jupyter.sh"
