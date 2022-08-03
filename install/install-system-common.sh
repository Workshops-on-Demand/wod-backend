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
token=`cat /vagrant/token`
su - jupyter -c "rm -rf wod-backend wod-private .ssh"
if [ $WODTYPE = "server" ]; then
	su - jupyter -c "rm -rf wod-server
	su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-server.git"
elif [ $WODTYPE = "backend" ]; then
	su - jupyter -c "rm -rf wod-notebooks
	su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-notebooks.git"
fi

su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-backend.git"
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
WODDISTRIB: $WODDISTRIB
EOF
cat ~jupyter/wod-backend/ansible/group_vars/wod-system >> ~jupyter/wod-backend/ansible/group_vars/$WODGROUP
if [ $WODTYPE = "backend" ]; then
	cat ~jupyter/wod-backend/ansible/group_vars/wod-backend >> ~jupyter/wod-backend/ansible/group_vars/$WODGROUP
fi
if [ $WODTYPE = "backend" ]; then
	cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "server" ]; then
	cat > ~jupyter/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODFEFQDN ansible_connection=local
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

if [ $WODTYPE = "server" ]; then
	su - jupyter -c "touch wod-server/.env"
	cat > ~jupyter/wod-server/.env << EOF
FROM_EMAIL_ADDRESS='sender@example.org'
SENDGRID_API_KEY="None"
API_PORT=8021
DB_PW=TrèsCompliqué!!##123
DURATION=4
JUPYTER_MOUGINS_LOCATION=
JUPYTER_GRENOBLE_LOCATION=GNB
JUPYTER_GREENLAKE_LOCATION=
POSTFIX_EMAIL_GRENOBLE=jupyter@$WODBEEXTFQDN
POSTFIX_EMAIL_MOUGINS=
POSTFIX_EMAIL_GREENLAKE=
POSTFIX_HOST_GRENOBLE=$WODBEEXTFQDN
POSTFIX_PORT_GRENOBLE=10025
POSTFIX_HOST_MOUGINS=
POSTFIX_PORT_MOUGINS=
POSTFIX_HOST_GREENLAKE=
POSTFIX_PORT_GREENLAKE=
FEEDBACK_WORKSHOP_URL="None"
FEEDBACK_CHALLENGE_URL="None"
PRODUCTION_API_SERVER=$WODFEFQDN
NO_OF_STUDENT_ACCOUNTS=1000
SLACK_CHANNEL_WORKSHOPS_ON_DEMAND="None"
SESSION_TYPE_WORKSHOPS_ON_DEMAND="None"
SESSION_TYPE_CODING_CHALLENGE="None"
SLACK_CHANNEL_CHALLENGES="None"
EOF
	su - jupyter -c "cd wod-server ; npm install"
fi

# Change default passwd for vagrant and root

# Install WoD
su - jupyter -c "./wod-backend/scripts/install_backend.sh"
