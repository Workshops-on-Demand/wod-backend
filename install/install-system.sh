#!/bin/bash

date

export WODTYPE=$1
if [ -z "$WODTYPE" ]; then
	echo "Syntax: install-system.sh api-db|backend|frontend|appliance"
	exit -1
fi

launch_with_pm2() {
	DIR=$1
	shift
	APP=$1
	shift
	echo "Install pm2"
	npm install pm2@latest
	export PATH=$PATH:"$DIR/node_modules/pm2/bin"
	pm2 show $APP 2>&1 > /dev/null
	if [ $? -eq 0 ]; then
		echo "Stop a previous server for $APP"
		pm2 del $APP
	fi
	echo "Start the $APP server"
	pm2 start --name=$APP npm -- start
}

if [ ! -f $HOME/.gitconfig ]; then
	cat > $HOME/.gitconfig << EOF
# This is Git's per-user configuration file.
[user]
# Please adapt and uncomment the following lines:
name = $WODUSER
email = $WODUSER@nowhere.org
EOF
fi

SCRIPT=`realpath $0`
# This is the installation directory where install scripts are located.
INSTALLDIR=`dirname $SCRIPT`

# This main dir is computed and is the backend main dir
export WODBEDIR=`dirname $INSTALLDIR`

# This is where wod.sh will be stored
SCRIPTDIR="$WODBEDIR/scripts"

if [ $WODTYPE = "backend" ]; then
	# In case of update remove first old jupyterhub version
	sudo rm -rf /opt/jupyterhub
fi

cat > $SCRIPTDIR/wod.sh << EOF
# This is the wod.sh script, generated at install
#
# Name of the admin user
export WODUSER=$WODUSER

# Name of the wod machine type (backend, api-db, frontend, appliance)
export WODTYPE=$WODTYPE

# Location of the backend directory
export WODBEDIR=$WODBEDIR

EOF
cat >> $SCRIPTDIR/wod.sh << 'EOF'
# BACKEND PART
# The backend dir has some fixed subdirs 
# wod-backend (WODBEDIR)
#    |---------- ansible (ANSIBLEDIR)
#    |---------- scripts (SCRIPTDIR defined in all.yml not here to allow overloading)
#    |---------- sys (SYSDIR)
#    |---------- install
#    |---------- conf
#    |---------- skel
#
export ANSIBLEDIR=$WODBEDIR/ansible
export SYSDIR=$WODBEDIR/sys
# Name of the backend server seen from outside
export WODBEEXTFQDN=$WODBEEXTFQDN

# PRIVATE PART
# These 3 dirs have fixed names by default that you can change in this file
# they are placed as sister dirs wrt WODBEDIR
# This is the predefined structure for a private repo
# wod-private (WODPRIVDIR)
#    |---------- ansible (ANSIBLEPRIVDIR)
#    |---------- notebooks (WODPRIVNOBO)
#    |---------- scripts (SCRIPTPRIVDIR)
#
PWODBEDIR=`dirname $WODBEDIR`
export WODPRIVDIR=$PWODBEDIR/wod-private
export ANSIBLEPRIVDIR=$WODPRIVDIR/ansible
export SCRIPTPRIVDIR=$WODPRIVDIR/scripts
export SYSPRIVDIR=$WODPRIVDIR/sys
export WODPRIVNOBO=$WODPRIVDIR/notebooks
WODPRIVINV=""
# Manages private inventory if any
if [ -f $WODPRIVDIR/ansible/inventory ]; then
	WODPRIVINV="-i $WODPRIVDIR/ansible/inventory"
	export WODPRIVINV
fi

# AIP-DB PART
export WODAPIDBDIR=$PWODBEDIR/wod-api-db
export WODAPIDBFQDN="$WODAPIDBFQDN"

# FRONTEND PART
export WODFEDIR=$PWODBEDIR/wod-frontend
export WODNOBO=$PWODBEDIR/wod-notebooks
EOF
if [ $WODTYPE = "backend" ]; then
	cat >> $SCRIPTDIR/wod.sh << 'EOF'

# These dirs are also fixed by default and can be changed as needed
export STUDDIR=/student
#
EOF
fi

chmod 755 $SCRIPTDIR/wod.sh
source $SCRIPTDIR/wod.sh

cd $SCRIPTDIR/../ansible
SHORTNAME="`hostname -s`"
PBKDIR=$WODGROUP

# Declares shell variables as ansible variables as well
# then they can be used in playbooks
ANSPLAYOPT="-e PBKDIR=$PBKDIR -e WODUSER=$WODUSER -e WODBEDIR=$WODBEDIR -e WODNOBO=$WODNOBO -e WODPRIVNOBO=$WODPRIVNOBO -e WODPRIVDIR=$WODPRIVDIR -e WODAPIDBDIR=$WODAPIDBDIR -e WODFEDIR=$WODFEDIR -e STUDDIR=$STUDDIR -e ANSIBLEDIR=$ANSIBLEDIR -e ANSIBLEPRIVDIR=$ANSIBLEPRIVDIR -e SCRIPTPRIVDIR=$SCRIPTPRIVDIR -e SYSDIR=$SYSDIR -e SYSPRIVDIR=$SYSPRIVDIR"

# For future wod.sh usage by other scripts
cat >> $SCRIPTDIR/wod.sh << EOF
export ANSPLAYOPT="$ANSPLAYOPT"
export PBKDIR=$PBKDIR
EOF
export ANSPLAYOPT

if ! command -v ansible-galaxy &> /dev/null
then
    echo "ansible-galaxy could not be found, please install ansible"
    exit -1
fi
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "ubuntu-20.04" ]; then
	# Older distributions require an older version of the collection to work.
	# See https://github.com/ansible-collections/community.general
	ansible-galaxy collection install --force-with-deps community.general:4.8.5
else
	ansible-galaxy collection install community.general
fi
ansible-galaxy collection install ansible.posix

# Execute private script if any
SCRIPTREL=`echo $SCRIPT | perl -p -e "s|$WODBEDIR||"`
if [ -x $WODPRIVDIR/$SCRIPTREL ];
then
	echo "Executing additional private script $WODPRIVDIR/$SCRIPTREL"
	$WODPRIVDIR/$SCRIPTREL
fi

ANSPRIVOPT=""
if [ -f "$ANSIBLEPRIVDIR/group_vars/all.yml" ]; then
	ANSPRIVOPT="$ANSPRIVOPT -e @$ANSIBLEPRIVDIR/group_vars/all.yml"
fi
if [ -f "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" ]; then
	ANSPRIVOPT="$ANSPRIVOPT -e @$ANSIBLEPRIVDIR/group_vars/$PBKDIR"
fi
# For future wod.sh usage by other scripts
cat >> $SCRIPTDIR/wod.sh << EOF
export ANSPRIVOPT="$ANSPRIVOPT"
EOF
export ANSPRIVOPT

if [ $WODTYPE = "backend" ]; then
	ANSPLAYOPT="$ANSPLAYOPT -e LDAPSETUP=0 -e APPMIN=0 -e APPMAX=0"
elif [ $WODTYPE = "api-db" ] || [ $WODTYPE = "frontend" ]; then
	ANSPLAYOPT="$ANSPLAYOPT -e LDAPSETUP=0"
fi

if [ $WODTYPE != "appliance" ]; then
	# Automatic Installation script for the system 
	ansible-playbook -i inventory $WODPRIVINV --limit $PBKDIR $ANSPLAYOPT $ANSPRIVOPT install_$WODTYPE.yml
	if [ $? -ne 0 ]; then
		echo "Install had errors exiting before launching startup"
		exit -1
	fi
	if [ $WODTYPE = "api-db" ]; then
		if [ -f "$ANSIBLEDIR/group_vars/$PBKDIR" ]; then
			WODAPIDBUSER=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER'`
			WODAPIDBPWD=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD'`
		fi
		if [ -f "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" ]; then
			WODAPIDBUSER=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBUSER'`
			WODAPIDBPWD=`cat "$ANSIBLEPRIVDIR/group_vars/$PBKDIR" | yq '.WODAPIDBPWD'`
		fi
		if [ _"$WODAPIDBUSER" = _"" ]; then
			echo "You need to configure WODAPIDBUSER in your $PBKDIR ansible variable file"
			WODAPIDBUSER="moderator"
			echo "Using default $WODAPIDBUSER instead"
		fi
		if [ _"$WODAPIDBPWD" = _"" ]; then
			echo "You need to configure WODAPIDBPWD in your $PBKDIR ansible variable file"
			WODAPIDBPWD="UnMotDePassCompliqué"
			echo "Using default $WODAPIDBPWD instead"
		fi
		export PGPASSWORD="TrèsCompliqué!!##123"
	fi
fi

if [ $WODTYPE = "api-db" ]; then
	# We can now generate the seeders files 
	# for the api-db server using the backend content installed as well
	$INSTALLDIR/build-seeders.sh

	cd $WODAPIDBDIR
	echo "Launching npm install..."
	npm install

	cat > .env << EOF
FROM_EMAIL_ADDRESS="$WODSENDER"
SENDGRID_API_KEY="None"
API_PORT=$WODAPIDBPORT
DB_PW=$PGPASSWORD
DURATION=4
JUPYTER_MOUGINS_LOCATION=
JUPYTER_GRENOBLE_LOCATION=GNB
JUPYTER_GREENLAKE_LOCATION=
POSTFIX_EMAIL_GRENOBLE=$WODUSER@$WODBEEXTFQDN
POSTFIX_EMAIL_MOUGINS=
POSTFIX_EMAIL_GREENLAKE=
POSTFIX_HOST_GRENOBLE=$WODBEEXTFQDN
POSTFIX_PORT_GRENOBLE=$WODPOSTPORT
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
SOURCE_ORIGIN="http://$WODFEFQDN:3000,http://$WODFEFQDN:$WODFEPORT"
WODUID=`id -u`
WODGID=`id -g`
EOF
	echo "Launching docker PostgreSQL stack"
	# Start the PostgreSQL DB stack
	# We need to relog with sudo as $WODUSER so it's really in the docker group
	# and be able to communicate with docker
	# and we need to stop it before to be idempotent
	sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker-compose down"
	sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker-compose config ; docker-compose up -d"
	POSTGRES_DB=`cat $WODAPIDBDIR/docker-compose.yml | yq '.POSTGRES_DB'`
	echo "Reset DB data"
	npm run reset-data
	echo "Setup $WODAPIDBUSER"
	psql --dbname=postgres --username=postgres --host=localhost -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('"$WODAPIDBPWD"',gen_salt('bf')) where username='"$WODAPIDBUSER"'";
	echo "Starting API"
	launch_with_pm2 $WODAPIDBDIR wod-$WODTYPE
elif [ $WODTYPE = "frontend" ]; then
	cd $WODFEDIR
	cat > .env << EOF
API_PORT=$WODAPIDBPORT
PRODUCTION_API_SERVER=http://$WODFEFQDN/api
GATSBY_WORKSHOPCHALLENGE_API_ENDPOINT=http://$WODAPIDBFQDN:$WODAPIDBPORT
GATSBY_USERNAME=''
GATSBY_PASSWORD=''
GATSBY_NEWSLETTER_API=''
WODUID=`id -u`
WODGID=`id -g`
EOF
	echo "Launching npm install..."
	npm install
	echo "Patching package.json to allow listening on the right host:port"
	perl -pi -e "s|gatsby develop|gatsby develop -H $WODFEFQDN -p $WODFEPORT|" package.json
	echo "Start the Frontend server"
	launch_with_pm2 $WODFEDIR wod-$WODTYPE
fi

if [ $WODTYPE != "appliance" ]; then
	cd $SCRIPTDIR/../ansible

	ansible-playbook -i inventory $WODPRIVINV --limit $PBKDIR $ANSPLAYOPT $ANSPRIVOPT check_$WODTYPE.yml
fi
date
