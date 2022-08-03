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
su - jupyter -c "rm -rf wod-backend wod-notebooks wod-private .ssh"
token=`cat /vagrant/token`
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-backend.git"
#su - jupyter -c "git clone https://github.com/Workshops-on-Demand/wod-backend.git"
# For now clone also notebooks
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-notebooks.git"
# For now clone also public private
su - jupyter -c "git clone https://bcornec:$token@github.com/Workshops-on-Demand/wod-private.git"

# Setup this using the group for WoD - created as jupyter
su - jupyter -c "cd wod-backend/ansible/group_vars ; echo PBKDIR: $WODGROUP > $WODGROUP"
cat > ~jupyter/wod-backend/ansible/group_vars/$WODGROUP << EOF
# 
# Installation specific values
# Modify afterwards or re-run the installer to update
#
WODBEFQDN: $WODBEFQDN
WODBEIP: $WODBEIP
WODBEEXTFQDN: $WODBEEXTFQDN
WODFEFQDN: $WODFEFQDN
WODDISTRIB: $WODDISTRIB
EOF
cat ~jupyter/wod-backend/ansible/group_vars/wod-base >> ~jupyter/wod-backend/ansible/group_vars/$WODGROUP
cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF

#Setup ssh for jupyter
su - jupyter -c "ssh-keygen -t rsa -b 4096 -N '' -f ~jupyter/.ssh/id_rsa"
su - jupyter -c "install -m 0600 wod-backend/skel/.ssh/authorized_keys .ssh/"
su - jupyter -c "cat ~jupyter/.ssh/id_rsa.pub >> ~jupyter/.ssh/authorized_keys"

# setup sudo for jupyter
cat > /etc/sudoers.d/jupyter << EOF
Defaults:jupyter !fqdn
Defaults:jupyter !requiretty
jupyter ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/jupyter

# Change default passwd for vagrant and root

# Install WoD
su - jupyter -c "./wod-backend/scripts/install_backend.sh"
