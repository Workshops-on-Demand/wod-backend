#!/bin/bash

set -x 

date

export WODTYPE=$1
if [ -z "$WODTYPE" ]; then
    echo "Syntax: install-system.sh api-db|backend|frontend|appliance"
    exit -1
fi

if [ ! -f $HOME/.gitconfig ]; then
    cat > $HOME/.gitconfig << EOF
# This is Git's per-user configuration file.
[user]
# Please adapt and uncomment the following lines:
name = $WODUSER
email = $WODUSER@nowhere.org
EOF
fi

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

cd $ANSIBLEDIR
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
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "ubuntu-20.04" ] || [ $WODDISTRIB = "ubuntu-22.04" ]; then
    # Older distributions require an older version of the collection to work.
    # See https://github.com/ansible-collections/community.general
    ansible-galaxy collection install --force-with-deps community.general:4.8.5
else
    ansible-galaxy collection install community.general
fi
ansible-galaxy collection install ansible.posix

# Execute private script if any
SCRIPT=`realpath $0`
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

# Inventory based on the installed system
if [ $WODTYPE = "backend" ]; then
    # In this case WODBEFQDN represents a single system
    cat > $ANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODBEFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "api-db" ]; then
    cat > $ANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODAPIDBFQDN ansible_connection=local
EOF
elif [ $WODTYPE = "frontend" ]; then
    cat > $ANSIBLEDIR/inventory << EOF
[$WODGROUP]
$WODFEFQDN ansible_connection=local
EOF
fi

# Import the USERMAX value here as needed for both backend and api-db
export USERMAX=`ansible-inventory -i $ANSIBLEDIR/inventory $WODPRIVINV --host $PBKDIR --playbook-dir $ANSIBLEDIR --playbook-dir $ANSIBLEPRIVDIR | jq ".USERMAX"`

if [ $WODTYPE != "appliance" ]; then
    # Setup this using the group for WoD
    cat > $ANSIBLEDIR/group_vars/$WODGROUP << EOF
PBKDIR: $WODGROUP
# 
# Installation specific values
# Modify afterwards or re-run the installer to update
#
# WODBEFQDN may represents multiple systems
WODBEFQDN: $WODBEFQDN
WODBEIP: $WODBEIP
WODFEFQDN: $WODFEFQDN
WODAPIDBFQDN: $WODAPIDBFQDN
WODDISTRIB: $WODDISTRIB
WODBEPORT: $WODBEPORT
WODFEPORT: $WODFEPORT
WODAPIDBPORT: $WODAPIDBPORT
WODPOSTPORT: $WODPOSTPORT
EOF
    cat $ANSIBLEDIR/group_vars/wod-system >> $ANSIBLEDIR/group_vars/$WODGROUP

    if [ -f $ANSIBLEDIR/group_vars/wod-$WODTYPE ]; then
        cat $ANSIBLEDIR/group_vars/wod-$WODTYPE >> $ANSIBLEDIR/group_vars/$WODGROUP
    fi
fi

if [ $WODTYPE = "backend" ]; then
    # Compute WODBASESTDID based on the number of this backend server multiplied by the number of users wanted
    WODBASESTDID=$(($USERMAX*$WODBENBR))
    cat >> $ANSIBLEDIR/group_vars/$WODGROUP << EOF
#
# WODBASESTDID is the offset used to create users in the DB. It is required that each backend has a different non overlapping value.
# Overlap is defined by adding USERMAX (from all.yml)
# The number of the deployed a backend in a specific location is used to compute the range available here
#
# Example:
# for student 35 in location A having WODBASESTDID to 0 the user is created as id 35
# for student 35 in location B having WODBASESTDID to 2000 the user is created as id 2035
# There is no overlap as long as you do not create more than 2000 users which should be the value of USERMAX in that case.
#
# This is different from the offset UIDBASE used for Linux uid
#
WODBASESTDID: $WODBASESTDID
EOF
fi

if [ $WODTYPE = "backend" ]; then
    JPHUB=`cat "$ANSIBLEDIR/group_vars/$PBKDIR" | grep -E '^JPHUB:' | cut -d: -f2`
    # In case of update remove first old jupyterhub version
    if [ _"$JPHUB" = _"" ]; then
        echo "Directory for jupyterhub is empty"
        exit -1
    fi
    if [ _"$JPHUB" = _"/" ]; then
        echo "Directory for jupyterhub is /"
        exit -1
    fi
    if [ _"$JPHUB" = _"$HOME" ]; then
        echo "Directory for jupyterhub is $HOME"
        exit -1
    fi
    sudo rm -rf $JPHUB
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

    cat > .env << EOF
FROM_EMAIL_ADDRESS="$WODSENDER"
DB_PW=$PGPASSWORD
# Target user to send mail to, managed with procmail
POSTFIX_EMAIL=$WODUSER
POSTFIX_PORT=$WODPOSTPORT
FEEDBACK_WORKSHOP_URL="None"
WODAPIDBPORT=$WODAPIDBPORT
WODUID=`id -u`
WODGID=`id -g`
SLACK_CHANNEL_WORKSHOPS_ON_DEMAND="None"
SENDGRID_API_KEY="None"
# Blacklist for input field
DENYLIST='@alilot.com,@leadwizzer.com,@thecarinformation.com,@acrossgracealley.com,@onekisspresave.com,@vusra.com,@tempmailin.com,@musiccode.me,@metalunits.com,@1secmail.com,@1secmail.org,@1secmail.net,@xojxe.com,@yoggm.com,@wwjmp.com,@esiix.com,@oosln.com,@vddaz.com,@trythe.net,uniromax.com,@pussport.com,@gpromotedx.com,@vusra.com,@atxcrunner.com,@efind.com,@acrossgracealley.com,causeweapo.n.6138@gmail.com,mailstop1483@gmail.com,oliviamacleo.d8.9.3.9640@gmail.com,onekisspresave.com,@kellychibale-researchgroup-uct.com,@tlbreaksm.com,cori.aniv@logdots.com,@wolfpat.com,@spam4.me,@guerillamail.bi,@belaca@famytown.club,@belaca@clark-college.cf,@sharkfaces.com,@chewydonut.com,@spamsandwich.com,@pizzajunk.com,@realquickemail.com,@sociallymediocre.com,@silenceofthespam.com,@silenceofthespam.com,@mailbiscuit.com,@snakebutt.com,@itsjiff.com,@hypenated-domain.com,lilspam.com,@whaaaaaaaaaat.com,@thespamfather.com,@spamfellas.com,@alilot.com,@vixej.com,@smartinbox.online,@nicoric.com,@dgzlweb.com,@chapedia.net,@smartinbox.online,@freemailus.com,@Grabmail.club,@Betaalverzoek.cyou,@Beezom.buzz,@Fitshot.xyz,@emailnax.com,@btzyud.tk,@wifaide.ml,@2fexbox.ru,@chitthi.in,@facetek.store,@litrs.site,@treamysell.store,@treamysell.store'
EOF
    echo "Launching docker PostgreSQL stack"
    # Start the PostgreSQL DB stack
	# We can use yq now as installed by ansible before
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
	# Manage locations
    #psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE TABLE IF NOT EXISTS locations ("createdAt" timestamp DEFAULT current_timestamp, "updatedAt" timestamp DEFAULT current_timestamp, "location" varchar CONSTRAINT no_null NOT NULL, "basestdid" integer CONSTRAINT no_null NOT NULL);'
    echo "Reset DB data"
    npm run reset-data
    echo "Setup user $WODAPIDBUSER"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto;'
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBUSERPWD',gen_salt('bf')) where username='$WODAPIDBUSER';"
    echo "Setup user $WODAPIDBADMIN"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c "UPDATE users set password=crypt('$WODAPIDBADMINPWD',gen_salt('bf')) where username='$WODAPIDBADMIN';"
    echo "Setup user_roles table not done elsewhere"
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'CREATE TABLE IF NOT EXISTS user_roles ("createdAt" timestamp DEFAULT current_timestamp, "updatedAt" timestamp DEFAULT current_timestamp, "roleId" integer CONSTRAINT no_null NOT NULL REFERENCES roles (id), "userId" integer CONSTRAINT no_null NOT NULL REFERENCES users (id));'
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'ALTER TABLE user_roles ADD CONSTRAINT "ID_PKEY" PRIMARY KEY ("roleId","userId");'
    # Get info on roles and users already declared
    userroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='user';"`
    moderatorroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='moderator';"`
    adminroleid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM roles WHERE name='admin';"`
    nbuser=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT COUNT(id) FROM users;"`
    moderatoruserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBUSER';"`
    adminuserid=`psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -AXqtc "SELECT id FROM users WHERE username='$WODAPIDBADMIN';"`
    # Every user as a role of user so it's probably useless !
    for (( i=$nbuser ; i>=1 ; i--)) do
        psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$userroleid','$i');'
    done
    # Map the moderator user
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$moderatorroleid','$moderatoruserid');'
    # Map the admin user
    psql --dbname=$POSTGRES_DB --username=postgres --host=localhost -c 'INSERT INTO user_roles ("roleId", "userId") VALUES ('$adminroleid','$adminuserid');'
	# Install pm2
	install_pm2 $WODAPIDBDIR
elif [ $WODTYPE = "frontend" ]; then
    cd $WODFEDIR
    cat > .env << EOF
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
	# Install pm2
	install_pm2 $WODFEDIR
fi

if [ $WODTYPE != "appliance" ]; then
    cd $SCRIPTDIR/../ansible

    ansible-playbook -i inventory $WODPRIVINV --limit $PBKDIR $ANSPLAYOPT $ANSPRIVOPT check_$WODTYPE.yml
fi
date
