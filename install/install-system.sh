#!/bin/bash

set -x 

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
	cat >> $HOME/.bash_profile << EOF
export PATH=$PATH:"$DIR/node_modules/pm2/bin"
EOF
	# Allow error to occur
	set +e
	pm2 show $APP 2>&1 > /dev/null
	if [ $? -eq 0 ]; then
		echo "Stop a previous server for $APP"
		pm2 del $APP
	fi
	set -e
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
export INSTALLDIR=`dirname $SCRIPT`

source $INSTALLDIR/functions.sh

# This main dir is computed and is the backend main dir
export WODBEDIR=`dirname $INSTALLDIR`

# This is where wod.sh will be stored
SCRIPTDIR="$WODBEDIR/scripts"

cat > $SCRIPTDIR/wod.sh << EOF
# This is the wod.sh script, generated at install
#
# Name of the admin user
export WODUSER=$WODUSER

# Name of the wod machine type (backend, api-db, frontend, appliance)
export WODTYPE=$WODTYPE

# Location of the backend directory
export WODBEDIR=$WODBEDIR
#
# Name of the backend server seen from outside
export WODBEEXTFQDN=$WODBEEXTFQDN

# Name of the api-db server
export WODAPIDBFQDN="$WODAPIDBFQDN"
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
PBKDIR=$WODGROUP

if [ $WODTYPE = "backend" ]; then
	export JPHUB=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | yq '.JPHUB' | sed 's/"//g'`
	# In case of update remove first old jupyterhub version
	sudo rm -rf $JPHUB
fi


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
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "ubuntu-20.04" ] || [ $WODDISTRIB = "ubuntu-22.04" ]; then
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
		get_wodapidb_userpwd
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

	export USERMAX=`ansible-inventory -i $ANSIBLEDIR/inventory $PRIVINV --host $PBKDIR --playbook-dir $ANSIBLEDIR --playbook-dir $ANSIBLEPRIVDIR | jq ".USERMAX"`

	cat > .env << EOF
FROM_EMAIL_ADDRESS="$WODSENDER"
SENDGRID_API_KEY="None"
API_PORT=$WODAPIDBPORT
DB_PW=$PGPASSWORD
DURATION=4
POSTFIX_EMAIL=$WODUSER@$WODBEEXTFQDN
POSTFIX_HOST=$WODBEEXTFQDN
POSTFIX_PORT=$WODPOSTPORT
FEEDBACK_WORKSHOP_URL="None"
PRODUCTION_API_SERVER=$WODFEFQDN
NO_OF_STUDENT_ACCOUNTS=$USERMAX
SLACK_CHANNEL_WORKSHOPS_ON_DEMAND="None"
SESSION_TYPE_WORKSHOPS_ON_DEMAND="None"
SOURCE_ORIGIN="http://$WODFEFQDN:3000,http://$WODFEFQDN:$WODFEPORT"
WODUID=`id -u`
WODGID=`id -g`
EOF
	echo "Launching docker PostgreSQL stack"
	# Start the PostgreSQL DB stack
	PGSQLDIR=`cat $WODAPIDBDIR/docker-compose.yml | yq '.services.db.environment.PGDATA' | sed 's/"//g'`
	# We need to relog with sudo as $WODUSER so it's really in the docker group
	# and be able to communicate with docker
	# and we need to stop it before to be idempotent
	# and we need to remove the data directory not done by the compose down
	sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker compose down"
	# That dir is owned by lxd, so needs root to remove
	sudo su - -c "rm -rf $PGSQLDIR"
	sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker compose config ; docker compose up -d"
	POSTGRES_DB=`cat $WODAPIDBDIR/docker-compose.yml | yq '.services.db.environment.POSTGRES_DB' | sed 's/"//g'`
	echo "Reset DB data"
	npm run reset-data
	echo "Setup $WODAPIDBUSER"
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBUSERPWD',gen_salt('bf')) where username='$WODAPIDBUSER';"
	echo "Setup $WODAPIDBADMIN"
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBADMINPWD',gen_salt('bf')) where username='$WODAPIDBADMIN';"
	echo "Setup user_roles table not done elsewhere"
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE TABLE IF NOT EXISTS user_roles (createAt timestamp DEFAULT current_timestamp, updatedAt timestamp DEFAULT current_timestamp, roleID integer CONSTRAINT no_null NOT NULL, userID integer CONSTRAINT no_null NOT NULL);'
	# Get info on roles and users already declared
	userroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='user';"`
	moderatorroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='$WODAPIDBUSER';"`
	adminroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='$WODAPIDBADMIN';"`
	nbuser=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT COUNT(id) FROM users;"`
	moderatoruserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBUSER';"`
	adminuserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBADMIN';"`
	# Every user as a role of user so it's probably useless !
	for (( i=$nbuser ; i>=1 ; i--)) do
		psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "INSERT INTO user_roles (roleID, userID) VALUES ($userroleid,$i);"
	done
	# Map the moderator user
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "INSERT INTO user_roles (roleID, userID) VALUES ($moderatorroleid,$moderatoruserid);"
	# Map the admin user
	psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "INSERT INTO user_roles (roleID, userID) VALUES ($adminroleid,$adminuserid);"
	echo "Starting API"
	launch_with_pm2 $WODAPIDBDIR wod-$WODTYPE
elif [ $WODTYPE = "frontend" ]; then
	cd $WODFEDIR
	cat > .env << EOF
API_PORT=$WODAPIDBPORT
# TODO: Should we add WODFEPORT here ?
PRODUCTION_API_SERVER=http://$WODFEFQDN/api
GATSBY_WORKSHOP_API_ENDPOINT=http://$WODAPIDBFQDN:$WODAPIDBPORT
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
