#!/bin/bash

set -e

# redirect stdout/stderr to a file
mkdir -p $HOME/.mail
exec &> >(tee $HOME/.mail/install.log)

date

export WODTYPE=$1
if [ -z "$WODTYPE" ]; then
	echo "Syntax: install_system api-db|backend|frontend"
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

SCRIPT=`realpath $0`
SCRIPTDIR=`dirname $SCRIPT`

if [ $WODTYPE = "backend" ]; then
	# In case of update remove first old jupyterhub version
	sudo rm -rf /opt/jupyterhub
fi

cat > $SCRIPTDIR/wod.sh << EOF
# This main dir is computed
export WODBEDIR=`dirname $SCRIPTDIR`
export WODUSER=$WODUSER
EOF
cat >> $SCRIPTDIR/wod.sh << 'EOF'
# These 3 dirs have fixed names by default that you can change in this file
# they are placed as sister dirs wrt WODBEDIR
PWODBEDIR=`dirname $WODBEDIR`
export WODPRIVDIR=$PWODBEDIR/wod-private
export WODAPIDBDIR=$PWODBEDIR/wod-api-db
export WODFEDIR=$PWODBEDIR/wod-frontend
WODANSOPT=""
# Manages private inventory if any
if [ -f $WODPRIVDIR/ansible/inventory ]; then
	WODANSOPT="-i $WODPRIVDIR/ansible/inventory"
	export WODANSOPT
fi
EOF
if [ $WODTYPE = "backend" ]; then
	cat >> $SCRIPTDIR/wod.sh << 'EOF'
# This dir is also fixed by default and can be changed as needed
export WODNOBO=$PWODBEDIR/wod-notebooks
export STUDDIR=/student
EOF
fi

chmod 755 $SCRIPTDIR/wod.sh
source $SCRIPTDIR/wod.sh

cd $SCRIPTDIR/../ansible
SHORTNAME="`hostname -s`"
FULLNAME=`ansible-inventory -i inventory --list | jq -r '._meta.hostvars | to_entries[] | .key' | grep -E "^$SHORTNAME(\.|$)"`
if [ _"$FULLNAME" = _"" ]; then
        echo "This machine is not a $WODTYPE machine, defined in the ansible inventory so can't be installed"
        exit -1
fi
PBKDIR=`ansible-inventory -i inventory --list | jq -r "._meta.hostvars | to_entries[] | select(.key == \"$FULLNAME\") | .value.PBKDIR"`

WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
# Another way using ansible
#DISTRIB=`ansible -m gather_facts -i inventory $FULLNAME | perl -p -e "s/$FULLNAME \| SUCCESS => //" | jq -r ".ansible_facts | .ansible_distribution"`
#DVER=`ansible -m gather_facts -i inventory $FULLNAME | perl -p -e "s/$FULLNAME \| SUCCESS => //" | jq -r ".ansible_facts | .ansible_distribution_major_version"`
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


SCRIPTREL=`echo $SCRIPT | perl -p -e "s|$WODBEDIR||"`
if [ -x $WODPRIVDIR/$SCRIPTREL ];
then
	echo "Executing additional private script $WODPRIVDIR/$SCRIPTREL"
	$WODPRIVDIR/$SCRIPTREL
fi

if [ $WODTYPE = "backend" ]; then
	ANSPLAYOPT="-e LDAPSETUP=0 -e APPMIN=0 -e APPMAX=0"
elif [ $WODTYPE = "api-db" ] || [ $WODTYPE = "frontend" ]; then
	ANSPLAYOPT="-e LDAPSETUP=0"
fi
# Automatic Installation script for the system 
ansible-playbook -i inventory --limit $PBKDIR $ANSPLAYOPT install_$WODTYPE.yml

if [ $WODTYPE = "api-db" ]; then
	cd $WODAPIDBDIR
	cat > .env << EOF
FROM_EMAIL_ADDRESS='sender@example.org'
SENDGRID_API_KEY="None"
API_PORT=8021
DB_PW=TrèsCompliqué!!##123
DURATION=4
JUPYTER_MOUGINS_LOCATION=
JUPYTER_GRENOBLE_LOCATION=GNB
JUPYTER_GREENLAKE_LOCATION=
POSTFIX_EMAIL_GRENOBLE=$WODUSER@$WODBEEXTFQDN
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
SOURCE_ORIGIN="http://localhost:3000,http://localhost:8000"
EOF
	# Start the PostgreSQL DB stack
	# We need to relog as $WODUSER so it's really in the docker group
	# and be able to communicate with docker
	echo "Launching docker PostgreSQL stack"
	sudo su - $WODUSER -c "cd $WODAPIDBDIR ; docker-compose up -d"
	echo "Reset DB data"
	npm run reset-data
	echo "Start the API server"
	npm start &
elif [ $WODTYPE = "frontend" ]; then
	cd $WODFEDIR
	echo "Start the Frontend server"
	npm start &
fi

cd $SCRIPTDIR/../ansible
ANSPLAYOPT=""
if [ -f $WODPRIVDIR/ansible/install_$WODTYPE.yml ]; then
	ansible-playbook -i inventory $WODANSOPT --limit $PBKDIR $ANSPLAYOPT install_$WODTYPE.yml
fi

ansible-playbook -i inventory --limit $PBKDIR check_$WODTYPE.yml
# Manages private part if any
if [ -f $WODPRIVDIR/ansible/check_$WODTYPE.yml ]; then
	ansible-playbook -i inventory $WODANSOPT --limit $PBKDIR check_$WODTYPE.yml
fi
date
