#!/bin/bash

# This is the second part of the installation process that is called by a specific installation script for a distribution
# Run as root

set -e
set -u
set -o pipefail

clean_clone_log() {

		# Now get the directory in which we cloned
		BRANCH=$1
		shift
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
		git clone $*

		# This line checks the correct branch out
		(cd $NREPODIR ; git checkout $BRANCH)

		# Store commit Ids for these repos
		(cd $NREPODIR ; echo "$NREPODIR: `git show --oneline | head -1 | awk '{print $1}'`")
}

# This is run as WODUSER user

# Get content for WoD
rm -rf .ssh
if [ $WODTYPE = "api-db" ]; then
	clean_clone_log $WODAPIBRANCH $WODAPIREPO
	clean_clone_log $WODNOBOBRANCH $WODNOBOREPO
elif [ $WODTYPE = "frontend" ]; then
	clean_clone_log $WODFEBRANCH $WODFEREPO
elif [ $WODTYPE = "backend" ]; then
	clean_clone_log $WODNOBOBRANCH $WODNOBOREPO
fi

# We'll store in backend dir the data we need whatever the type we're building
clean_clone_log $WODBEBRANCH $WODBEREPO
clean_clone_log $WODPRIVBRANCH $WODPRIVREPO

if [ $WODGENKEYS -eq 0 ] && [ -f "$WODTMPDIR/id_rsa" ]; then
	# We do not have to regenerate keys and reuse existing one preserved
	echo "Keep existing ssh keys for $WODUSER"
	ls -al $WODTMPDIR
	mkdir -p .ssh
	chmod 700 .ssh
	cp $WODTMPDIR/[a-z]* .ssh
	chmod 644 .ssh/*
	chmod 600 .ssh/id_rsa
	if [ -f .ssh/authorized_keys ]; then
		chmod 600 .ssh/authorized_keys
	fi
else
	# Setup ssh for WODUSER
	echo "Generating ssh keys for $WODUSER"
	ssh-keygen -t rsa -b 4096 -N '' -f $HOME/.ssh/id_rsa
	install -m 0600 wod-backend/skel/.ssh/authorized_keys .ssh/
	cat $HOME/.ssh/id_rsa.pub >> $HOME/.ssh/authorized_keys
fi
# temp dir remove in caller by root to avoid issues

# Change default passwd for vagrant and root

# Install WoD - install scripts managed in backend whatever system we install
$HOME/wod-backend/install/install-system.sh $WODTYPE
