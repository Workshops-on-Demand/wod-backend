#!/bin/bash

set -e
set -u
set -o pipefail

usage() {
    echo "install.sh [-h][-t type][-g groupname][-b backend][-f frontend][-a api-db][-e external][-u user][-s sender][-k]"
    echo " "
    echo "where:"
    echo "type      is the installation type"
    echo "          valid values: appliance, backend, frontend or api-db"
    echo "          if empty using 'backend'                "
    echo "groupname is the ansible group_vars name to be used"
    echo "          example: production, staging, test, ...  "
    echo "          if empty using 'production'                "
    echo "backend   is the FQDN of the backend JupyterHub server"
    echo "          example: be.internal.example.org  "
    echo "          if empty using the local name for the backend                "
    echo "frontend  is the FQDN of the frontend Web server"
    echo "          example: fe.example.org  "
    echo "          if empty using the external name for the backend                "
    echo "api-db    is the FQDN of the API/DB server "
    echo "          example: api.internal.example.org  "
    echo "          if empty using the name for the frontend                "
    echo "external  is the external FQDN of the backend JupyterHub server, reachable from the Internet"
    echo "          example: jphub.example.org  "
    echo "          if empty using the internal name of the backend                "
    echo "user      is the name of the admin user for the WoD project"
    echo "          example: mywodadmin "
    echo "          if empty using wodadmin               "
    echo "-k        if used, force the re-creation of ssh keys for the previously created admin user"
    echo "          if not used keep the existing keys in place if any (backed up and restored)"
    echo "          if the name of the admin user is changed, new keys are created"
    echo "sender    is the e-mail address used in the WoD frontend to send API procmail mails to the WoD backend"
    echo "          example: sender@example.org "
    echo "          if empty using wodadmin@localhost"
}

echo "install.sh called with $*"
# Run as root
t=""
f=""
e=""
b=""
a=""
g=""
u=""
s=""
k=""
WODGENKEYS=0

while getopts "t:f:e:b:a:g:u:s:hk" option; do
    case "${option}" in
        t)
            t=${OPTARG}
            if [ ${t} !=  "backend" ] && [ ${t} != "frontend" ] && [ ${t} != "api-db" ] && [ ${t} != "appliance" ]; then
                echo "wrong type: ${t}"
                usage
                exit -1
            fi
            ;;
        f)
            f=${OPTARG}
            ;;
        e)
            e=${OPTARG}
            ;;
        b)
            b=${OPTARG}
            ;;
        g)
            g=${OPTARG}
            ;;
        a)
            a=${OPTARG}
            ;;
        u)
            u=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
        k)
            WODGENKEYS=1
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit -1
            ;;
    esac
done
shift $((OPTIND-1))
#if [ -z "${v}" ] || [ -z "${g}" ]; then
    #usage
#fi
if [ ! -z "${t}" ]; then
    WODTYPE="${t}"
else
    WODTYPE="backend"
fi
if [ ! -z "${b}" ]; then
    WODBEFQDN="${b}"
else
    WODBEFQDN=`hostname -f`
fi
if [ ! -z "${e}" ]; then
    WODBEEXTFQDN="${e}"
else
    WODBEEXTFQDN=$WODBEFQDN
fi
if [ ! -z "${f}" ]; then
    WODFEFQDN="${f}"
else
    WODFEFQDN=$WODBEFQDN
fi
if [ ! -z "${a}" ]; then
    WODAPIDBFQDN="${a}"
else
    WODAPIDBFQDN=$WODFEFQDN
fi
if [ ! -z "${u}" ]; then
    export WODUSER="${u}"
else
    export WODUSER="wodadmin"
fi

if [ ! -z "${s}" ]; then
    export WODSENDER="${s}"
else
    export WODSENDER="wodadmin@localhost"
fi
if [ ! -z "${g}" ]; then
    WODGROUP="${g}"
else
    WODGROUP="production"
fi
export WODGROUP WODFEFQDN WODBEFQDN WODAPIDBFQDN WODBEEXTFQDN WODTYPE
export WODBEIP=`ping -c 1 $WODBEFQDN 2>/dev/null | grep PING | grep $WODBEFQDN | cut -d'(' -f2 | cut -d')' -f1`
WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
res=`echo $WODDISTRIB | { grep -i rocky || true; }`
if [ _"$res" != _"" ]; then
    # remove subver
    export WODDISTRIB=`echo $WODDISTRIB | cut -d. -f1`
else
    export WODDISTRIB
fi
echo "WODUSER: $WODUSER" > /etc/wod.yml
echo "WODSENDER: $WODSENDER" >> /etc/wod.yml

echo "Installing a Workshop on Demand $WODTYPE environment"
echo "Using api-db $WODAPIDBFQDN"
echo "Using backend $WODBEFQDN ($WODBEIP)"
echo "Using groupname $WODGROUP"
echo "Using WoD user $WODUSER"

if [ ${t} != "appliance" ]; then
    echo "Using frontend $WODFEFQDN"
    echo "Using external backend $WODBEEXTFQDN"
fi

# Needs to be root
if [ _"$SUDO_USER" = _"" ]; then
    echo "You need to use sudo to launch this script"
    exit -1
fi
HDIR=`grep -E "^$SUDO_USER" /etc/passwd | cut -d: -f6`
if [ _"$HDIR" = _"" ]; then
    echo "$SUDO_USER has no home directory"
    exit -1
fi

# redirect stdout/stderr to a file in the launching user directory
mkdir -p $HDIR/.wodinstall
exec &> >(tee $HDIR/.wodinstall/install.log)

echo "Install starting at `date`"
# Get path of execution
EXEPATH=`dirname "$0"`
export EXEPATH=`( cd "$EXEPATH" && pwd )`

source $EXEPATH/install.repo
# Overload WODPRIVREPO if using a private one
if [ -f $EXEPATH/install.priv ]; then
    source $EXEPATH/install.priv
fi
export WODFEREPO WODBEREPO WODAPIREPO WODNOBOREPO WODPRIVREPO
export WODFEBRANCH WODBEBRANCH WODAPIBRANCH WODNOBOBRANCH WODPRIVBRANCH
echo "Installation environment :"
echo "---------------------------"
env | grep WOD
echo "---------------------------"

export WODTMPDIR=/tmp/wod.$$

# Create the WODUSER user
if grep -qE "^$WODUSER:" /etc/passwd; then
    if ps auxww | grep -qE "^$WODUSER:"; then
        pkill -u $WODUSER
    fi
	WODHDIR=`grep -E "^$WODUSER" /etc/passwd | cut -d: -f6`
	echo "$WODUSER home directory: $WODHDIR"
	echo "Original SSH keys"
    ls -al $WODHDIR/.ssh/
    mkdir -p $WODTMPDIR
    chmod 700 $WODTMPDIR
    if [ $WODGENKEYS -eq 0 ] && [ -f $WODHDIR/.ssh/id_rsa ]; then
		echo "Copying existing SSH keys for $WODUSER in $WODTMPDIR"
        cp -a $WODHDIR/.ssh/[a-z]* $WODTMPDIR
    fi
    chown -R $WODUSER $WODTMPDIR
    userdel -f -r $WODUSER

	# If we do not have to regenerate keys
	if [ $WODGENKEYS -eq 0 ]; then
		echo "Preserved SSH keys"
		ls -al $WODTMPDIR
	else
		echo "Generating ssh keys for pre-existing $WODUSER"
	fi
else
	echo "Generating ssh keys for non-pre-existing $WODUSER"
fi
useradd -U -m -s /bin/bash $WODUSER

# Manage passwd
export WODPWD=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
echo "$WODUSER:$WODPWD" | chpasswd
echo "$WODUSER is $WODPWD" > $HDIR/.wodinstall/$WODUSER

# setup sudo for $WODUSER
cat > /etc/sudoers.d/$WODUSER << EOF
Defaults:$WODUSER !fqdn
Defaults:$WODUSER !requiretty
$WODUSER ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/$WODUSER
chown $WODUSER /etc/wod.yml

export WODGENKEYS

# Call the distribution specific install script
echo "Installing $WODDISTRIB specificities for $WODTYPE"
$EXEPATH/install-system-$WODDISTRIB.sh

# Now drop priviledges
# Call the common install script to finish install
echo "Installing common remaining stuff as $WODUSER"
if [ $WODDISTRIB = "centos-7" ] || [ $WODDISTRIB = "rocky-8" ] ; then
    # that su version doesn't support option -w turning around
    cat > /tmp/wodexports << EOF
export WODGROUP="$WODGROUP"
export WODFEFQDN="$WODFEFQDN"
export WODBEFQDN="$WODBEFQDN"
export WODAPIDBFQDN="$WODAPIDBFQDN"
export WODBEEXTFQDN="$WODBEEXTFQDN"
export WODTYPE="$WODTYPE"
export WODBEIP="$WODBEIP"
export WODDISTRIB="$WODDISTRIB"
export WODUSER="$WODUSER"
export WODFEREPO="$WODFEREPO"
export WODBEREPO="$WODBEREPO"
export WODAPIREPO="$WODAPIREPO"
export WODNOBOREPO="$WODNOBOREPO"
export WODPRIVREPO="$WODPRIVREPO"
export WODFEBRANCH="$WODFEBRANCH"
export WODBEBRANCH="$WODBEBRANCH"
export WODAPIBRANCH="$WODAPIBRANCH"
export WODNOBOBRANCH="$WODNOBOBRANCH"
export WODPRIVBRANCH="$WODPRIVBRANCH"
export WODSENDER="$WODSENDER"
export WODGENKEYS="$WODGENKEYS"
export WODTMPDIR="$WODTMPDIR"
EOF
    chmod 644 /tmp/wodexports
    su - $WODUSER -c "source /tmp/wodexports ; $EXEPATH/install-system-common.sh"
    rm -f /tmp/wodexports
else
    su - $WODUSER -w WODGROUP,WODFEFQDN,WODBEFQDN,WODAPIDBFQDN,WODBEEXTFQDN,WODTYPE,WODBEIP,WODDISTRIB,WODUSER,WODFEREPO,WODBEREPO,WODAPIREPO,WODNOBOREPO,WODPRIVREPO,WODFEBRANCH,WODBEBRANCH,WODAPIBRANCH,WODNOBOBRANCH,WODPRIVBRANCH,WODSENDER,WODGENKEYS,WODTMPDIR -c "$EXEPATH/install-system-common.sh"
fi
echo "Install ending at `date`"
