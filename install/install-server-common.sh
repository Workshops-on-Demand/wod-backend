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
su - jupyter -c "rm -rf wod-server wod-private .ssh"
token=`cat /vagrant/token`
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-server.git"
#su - jupyter -c "git clone https://github.com/Workshops-on-Demand/wod-server.git"
su - jupyter -c "git clone -b private https://bcornec:$token@github.com/Workshops-on-Demand/wod-private.git"

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
npm install
cat > .env << EOF
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

# Change default passwd for vagrant and root

# Install WoD
su - jupyter -c "./wod-server/scripts/install_server.sh"
