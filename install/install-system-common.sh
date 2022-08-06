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
useradd -U -m -s /bin/bash jupyter
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


# Get content for WoD - now in private mode
token=`cat /vagrant/token`
su - jupyter -c "rm -rf wod-backend wod-private .ssh"
if [ $WODTYPE = "api-db" ]; then
	su - jupyter -c "rm -rf wod-api-db"
	# using branch rename/migrationfiles for now - rebased on it
	su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-api-db.git"
elif [ $WODTYPE = "frontend" ]; then
	su - jupyter -c "rm -rf wod-frontend"
	su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-frontend.git"
elif [ $WODTYPE = "backend" ]; then
	su - jupyter -c "rm -rf wod-notebooks"
	su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-notebooks.git"
fi

# We'll store in backend dir the data we need whatever the type we're building
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-backend.git"
# When Open Sourced used that one
#su - jupyter -c "git clone https://github.com/Workshops-on-Demand/wod-backend.git"
su - jupyter -c "git clone https://bcornec:$token@github.com/Workshops-on-Demand/wod-private.git"

# Setup this using the group for WoD - created as jupyter
su - jupyter -c "cd wod-backend/ansible/group_vars ; touch $WODGROUP"
cat > ~jupyter/wod-backend/ansible/group_vars/$WODGROUP << EOF
PBKDIR: $WODGROUP
# 
# Installation specific values
# Modify afterwards or re-run the installer to update
#
WODBEFQDN: $WODBEFQDN
WODBEIP: $WODBEIP
WODBEEXTFQDN: $WODBEEXTFQDN
WODFEFQDN: $WODFEFQDN
WODAPIDBFQDN: $WODAPIDBFQDN
WODDISTRIB: $WODDISTRIB
EOF

cat ~jupyter/wod-backend/ansible/group_vars/wod-system >> ~jupyter/wod-backend/ansible/group_vars/$WODGROUP
if [ -f ~jupyter/wod-backend/ansible/group_vars/wod-$WODTYPE ]; then
	cat ~jupyter/wod-backend/ansible/group_vars/wod-$WODTYPE >> ~jupyter/wod-backend/ansible/group_vars/$WODGROUP
fi

# Inventory based on the installed system
if [ $WODTYPE = "backend" ]; then
	cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "api-db" ]; then
	cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODAPIDBFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "frontend" ]; then
	cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODFEFQDN ansible_connection=local
EOF
fi
if [ $WODTYPE = "api-db" ] ||  [ $WODTYPE = "frontend" ]; then
	su - jupyter -c "cd wod-$WODTYPE ; npm install"
fi

# Change default passwd for vagrant and root

# Install WoD - install scripts managed in backend whatever system we install
su - jupyter -c "./wod-backend/scripts/install_system.sh $WODTYPE"
