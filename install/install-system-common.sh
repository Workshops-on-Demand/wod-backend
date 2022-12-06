#!/bin/bash

# This is the second part of the installation process that is called by a specific installation script for a distribution
# Run as root

set -e
set -u
set -o pipefail

clean_clone_log() {

		# Now get the directory in which we cloned
		REPODIR=`echo "$*" | tr ' ' '\n' | tail -1`
		res=`echo $REPODIR | { grep "://" || true; }`
		if [ _"$res" != _"" ]; then
			# REPODIR points to URL not dir
			# dir is then computed automatically
			NREPODIR=`echo "$REPODIR" | tr '/' '\n' | tail -1 | sed 's/\.git$//'`
		else
			NREPODIR="$REPODIR"
		fi

		if [ _"$NREPODIR" = _"" ]; then
			echo "Directory into which to clone is empty"
			exit -1
		fi
		if [ _"$NREPODIR" = _"/" ]; then
			echo "Directory into which to clone is /"
			exit -1
		fi
		if [ _"$NREPODIR" = _"$HOME" ]; then
			echo "Directory into which to clone is $HOME"
			exit -1
		fi

		# Remove directory first
		rm -rf $NREPODIR

		# This line will clone the repo
		$*

		# Store commit Ids for these repos
		(cd $NREPODIR ; echo "$NREPODIR: `git show --oneline | awk '{print $1}'`")
}

# This is run as WODUSER user

# Get content for WoD - now in private mode
rm -rf .ssh
if [ $WODTYPE = "api-db" ]; then
	# using branch rename/migrationfiles for now - rebased on it
	clean_clone_log $WODAPIREPO
elif [ $WODTYPE = "frontend" ]; then
	clean_clone_log $WODFEREPO
elif [ $WODTYPE = "backend" ]; then
	clean_clone_log $WODNOBOREPO
fi

# We'll store in backend dir the data we need whatever the type we're building
clean_clone_log $WODBEREPO
clean_clone_log $WODPRIVREPO

#Setup ssh for WODUSER
ssh-keygen -t rsa -b 4096 -N '' -f $HOME/.ssh/id_rsa
install -m 0600 wod-backend/skel/.ssh/authorized_keys .ssh/
cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys

# Setup this using the group for WoD
cat > $HOME/wod-backend/ansible/group_vars/$WODGROUP << EOF
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

cat $HOME/wod-backend/ansible/group_vars/wod-system >> $HOME/wod-backend/ansible/group_vars/$WODGROUP
if [ -f $HOME/wod-backend/ansible/group_vars/wod-$WODTYPE ]; then
	cat $HOME/wod-backend/ansible/group_vars/wod-$WODTYPE >> $HOME/wod-backend/ansible/group_vars/$WODGROUP
fi

# Inventory based on the installed system
if [ $WODTYPE = "backend" ]; then
	cat > $HOME/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "api-db" ]; then
	cat > $HOME/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODAPIDBFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "frontend" ]; then
	cat > $HOME/wod-backend/ansible/inventory << EOF
[$WODGROUP]
$WODFEFQDN ansible_connection=local
EOF
fi
if [ $WODTYPE = "api-db" ] ||  [ $WODTYPE = "frontend" ]; then
	cd wod-$WODTYPE
	npm install
fi

# Change default passwd for vagrant and root

# Install WoD - install scripts managed in backend whatever system we install
$HOME/wod-backend/scripts/install_system.sh $WODTYPE
