#!/bin/bash

set -e
set -u
set -o pipefail

usage() {
    echo "install.sh [-h][-t type][-i ip][-g groupname][-b backend[:beport][-n number][-f frontend[:feport]][-a api-db[:apidbport]][-u user][-p postport][-k][-s sender]"
    echo " "
    echo "where:"
    echo "type      is the installation type"
    echo "          valid values: appliance, backend, frontend or api-db"
    echo "          if empty using 'backend'                "
    echo " "
    echo "groupname is the ansible group_vars name to be used"
    echo "          example: production, staging, test, ...  "
    echo "          if empty using 'production'                "
    echo " "
    echo "backend   is the FQDN of the backend JupyterHub server, potentially with a port."
    echo "          This FQDN address should be reachable from Your clients or the Internet if providing external services."
    echo "          if empty using the local name for the backend and default port               "
    echo "          If you use multiple backend systems corresponding to multiple locations, "
    echo "          use option -n to give the backend number currently being installed, starting at 1."
    echo " "
    echo "          When installing the api-db server you have to specify one or multiple backend servers,"
    echo "          using their FQDN separated with ','"
    echo "          using the same order as given with the -n option during backend installation."
    echo " "
    echo "-n        if used, this indicates the number of the backend currently installed"
    echo "          used for the backend installation only, when  multiple backend systems will be used in the configuration"
    echo "          example: -b be.internal.example.org:9999  (for a single backend server installation using port 9999)"
    echo "          example: -b be.internal.example.org:8888 -n 1 (for the first of the 2 backends installed)"
    echo "          example: -b be2.internal.example.org:8888 -n 2 (for the second of the 2 backends installed)"
    echo "          example: -b be.internal.example.org:8888,be2.internal.example.org:8888 (for the installation of the corresponding api-db server)"
    echo "ip        IP address of the backend server being used"
    echo "          if empty, try to be autodetected from FQDN of the backend server"
    echo "          Used in particular when the IP can't be guessed such as with Vagrant"
    echo "          or when you want to mask the external IP returned by an internal one as its usage is for the hosts creation"
    echo "postport  is the port on which the postfix service is listening on the backend"
    echo "          example: -p 10030 "
    echo "          if empty using 10025               "
    echo "sender    is the e-mail address used in the WoD frontend to send API procmail mails to the WoD backend"
    echo "          example: sender@example.org "
    echo "          if empty using wodadmin@localhost"
    echo " "
    echo "frontend  is the FQDN of the frontend Web server, potentially with a port"
    echo "          example: fe.example.org  "
    echo "          if empty using the external name for the backend                "
    echo " "
    echo "api-db    is the FQDN of the API/DB server, potentially with a port "
    echo "          example: api.internal.example.org  "
    echo "          if empty using the name for the frontend                "
    echo " "
    echo "user      is the name of the admin user for the WoD project"
    echo "          example: mywodadmin "
    echo "          if empty using wodadmin               "
    echo "-k        if used, force the re-creation of ssh keys for the previously created admin user"
    echo "          if not used keep the existing keys in place if any (backed up and restored)"
    echo "          if the name of the admin user is changed, new keys are created"
}

echo "install.sh called with $*"
# Run as root
t=""
f=""
b=""
a=""
g=""
u=""
s=""
k=""
i=""
p=""
n=""
WODGENKEYS=0

while getopts "t:f:b:o:n:a:g:i:u:s:p:hk" option; do
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
        i)
            i=${OPTARG}
            ;;
        b)
            b=${OPTARG}
            ;;
        n)
            n=${OPTARG}
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
        p)
            p=${OPTARG}
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

# Here we have either a single backend for backend install
# WODBEFQDN will point to its FQDN
# WODBEPORT will point to its port
# or we have multiple of these when installing an api-db
# WODBEFQDN will point to the list of backends with ports seprarated with ,
# WODBEPORT will be default and not used later.
WODBEPORT=8000
MULTIBCKEND=0
if [ ! -z "${b}" ]; then
    WODBEFQDN="`echo ${b} | cut -d: -f1`"
    res=`echo "${b}" | { grep ',' || true; }`
    if [ _"$res" != _"" ]; then
   # We have multiple backends only meaningful in api-db install
        if [ $WODTYPE = "api-db" ]; then
       WODBEFQDN="${b}"
       MULTIBCKEND=1
        else
       echo "Multiple backends are only possible when installing an api-db machine"
       echo " "
       usage
       exit -1
   fi
    else
   # Single backend get its port
        res=`echo "${b}" | { grep ':' || true; }`
        if [ _"$res" != _"" ]; then
            WODBEPORT="`echo ${b} | cut -d: -f2`"
        fi
    fi
else
    WODBEFQDN=`hostname -f`
fi

# In case of multiple backends, record which number this one is.
# only valid for backend install
if [ ! -z "${n}" ]; then
    if [ $WODTYPE = "backend" ]; then
        export WODBENBR=$((n-1))
    else
        echo "Numbering backends is only possible when installing a backend machine"
        echo " "
        usage
        exit -1
    fi
else
    export WODBENBR="0"
fi


WODFEPORT=8000
if [ ! -z "${f}" ]; then
    WODFEFQDN="`echo ${f} | cut -d: -f1`"
    res=`echo "${f}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODFEPORT="`echo ${f} | cut -d: -f2`"
    fi
else
    WODFEFQDN="`echo $WODBEFQDN | cut -d: -f1`"
fi
WODAPIDBPORT=8021
if [ ! -z "${a}" ]; then
    WODAPIDBFQDN="`echo ${a} | cut -d: -f1`"
    res=`echo "${a}" | { grep ':' || true; }`
    if [ _"$res" != _"" ]; then
        WODAPIDBPORT="`echo ${a} | cut -d: -f2`"
    fi
else
    WODAPIDBFQDN=$WODFEFQDN
fi

# This IP address is for the backend only so makes only sense deploying a backend server
if [ ! -z "${i}" ]; then
    WODBEIP="${i}"
else
    if [ ! -x /usr/bin/ping ] || [ ! -x /bin/ping ]; then
        echo "Please install the ping command before re-running this install script"
        exit -1
    fi
    # If ping doesn't work continue if we got the IP address
    FQDN="`echo $WODBEFQDN | cut -d, -f1 | cut -d: -f1`"
set +e
    WODBEIP=`ping -c 1 $FQDN 2>/dev/null | grep PING | grep $FQDN | cut -d'(' -f2 | cut -d')' -f1`
set -e
    if [ _"$WODBEIP" = _"" ]; then
        echo "Unable to find IP address for server $WODBEFQDN"
        exit -1
    fi
fi
export WODBEIP

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
if [ ! -z "${p}" ]; then
    export WODPOSTPORT="${p}"
else
    export WODPOSTPORT="10025"
fi
if [ ! -z "${g}" ]; then
    WODGROUP="${g}"
else
    WODGROUP="production"
fi
export WODGROUP WODFEFQDN WODBEFQDN WODAPIDBFQDN WODTYPE WODBEPORT WODFEPORT WODAPIDBPORT WODPOSTPORT

WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
res=`echo $WODDISTRIB | { grep -i rocky || true; }`
if [ _"$res" != _"" ]; then
    # remove subver
    export WODDISTRIB=`echo $WODDISTRIB | cut -d. -f1`
else
    export WODDISTRIB
fi
echo "Installing a Workshop on Demand $WODTYPE environment"
echo "Using api-db $WODAPIDBFQDN on port $WODAPIDBPORT"
if [ _"$MULTIBCKEND" = _"1" ]; then
    echo "Using backends $WODBEFQDN (with first IP $WODBEIP)"
else
    echo "Using backend $WODBEFQDN ($WODBEIP) on port $WODBEPORT"
fi
echo "Using groupname $WODGROUP"
echo "Using WoD user $WODUSER"
echo "Using WoD base student coef $WODBENBR"

if [ ${t} != "appliance" ]; then
    echo "Using frontend $WODFEFQDN on port $WODFEPORT"
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
    WODHDIR=`grep -E "^$WODUSER" /etc/passwd | cut -d: -f6`

   # For idempotency, kill potentially existing jobs
   if [ $WODTYPE = "api-db" ]; then
       set +e
       # Clean potential remaining docker containers
       docker --version 2>&1 /dev/null
       if [ $? -eq 0 ]; then
           systemctl restart docker
           docker stop postgres
           docker stop wod-api-db-adminer-1
           systemctl stop docker
       fi
       # Avoid errors with wod-api-db/data removal as WODUSER
       rm -rf $WODHDIR/wod-$WODTYPE/data
       set -e
   fi

    if ps auxww | grep -qE "^$WODUSER"; then
       pkill -u $WODUSER
       sleep 1
       pkill -9 -u $WODUSER
    fi
    echo "$WODUSER home directory: $WODHDIR"
    if [ -d "$WODHDIR/.ssh" ]; then
        echo "Original SSH keys"
        ls -al $WODHDIR/.ssh/
        mkdir -p $WODTMPDIR
        chmod 700 $WODTMPDIR
        if [ $WODGENKEYS -eq 0 ] && [ -f $WODHDIR/.ssh/id_rsa ]; then
            echo "Copying existing SSH keys for $WODUSER in $WODTMPDIR"
            cp -a $WODHDIR/.ssh/[a-z]* $WODTMPDIR
        fi
        chown -R $WODUSER $WODTMPDIR
    fi
    userdel -f -r $WODUSER
    if [ -d $WODHDIR ] && [ _"$WODHDIR" != _"/" ]; then
        echo $WODHDIR | grep -qE '^/home'
        if [ $? -eq 0 ]; then
            rm -rf $WODHDIR
        fi
    fi

    # If we do not have to regenerate keys
    if [ $WODGENKEYS -eq 0 ] && [ -d $WODTMPDIR ]; then
        echo "Preserved SSH keys"
        ls -al $WODTMPDIR
    else
        echo "Generating ssh keys for pre-existing $WODUSER"
    fi
else
    echo "Generating ssh keys for non-pre-existing $WODUSER"
fi
useradd -U -m -s /bin/bash $WODUSER

# Keep conf
echo "WODUSER: $WODUSER" > /etc/wod.yml
echo "WODSENDER: $WODSENDER" >> /etc/wod.yml
chown $WODUSER /etc/wod.yml

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

export WODGENKEYS

# Call the distribution specific install script
echo "Installing $WODDISTRIB specificities for $WODTYPE"
$EXEPATH/install-system-$WODDISTRIB.sh

# In order to be able to access install script we need correct rights on the home dir of the uid launching the script
WODHDIR=`grep -E "^$WODUSER" /etc/passwd | cut -d: -f6`
BKPSTAT=`stat --printf '%a' $WODHDIR`
echo "Found $WODUSER home directory $WODHDIR with rights $BKPSTAT"
echo "Forcing temporarily open rights to access install scripts"
chmod o+x $WODHDIR

HDIRSTAT=`stat --printf '%a' $HDIR`
echo "Found $SUDO_USER home directory $HDIR with rights $HDIRSTAT"
echo "Forcing temporarily open rights to access install scripts"
chmod o+x $HDIR

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
export WODFEPORT="$WODFEPORT"
export WODBEPORT="$WODBEPORT"
export WODAPIDBPORT="$WODAPIDBPORT"
export WODPOSTPORT="$WODPOSTPORT"
export WODBENBR="$WODBENBR"
EOF
    chmod 644 /tmp/wodexports
    su - $WODUSER -c "source /tmp/wodexports ; $EXEPATH/install-system-common.sh"
    rm -f /tmp/wodexports
else
    su - $WODUSER -w WODGROUP,WODFEFQDN,WODBEFQDN,WODAPIDBFQDN,WODTYPE,WODBEIP,WODDISTRIB,WODUSER,WODFEREPO,WODBEREPO,WODAPIREPO,WODNOBOREPO,WODPRIVREPO,WODFEBRANCH,WODBEBRANCH,WODAPIBRANCH,WODNOBOBRANCH,WODPRIVBRANCH,WODSENDER,WODGENKEYS,WODTMPDIR,WODFEPORT,WODBEPORT,WODAPIDBPORT,WODPOSTPORT,WODBENBR -c "$EXEPATH/install-system-common.sh"
fi

echo "Setting up original rights for $WODHDIR with $BKPSTAT"
chmod $BKPSTAT $WODHDIR

echo "Setting up original rights for $HDIR with $HDIRSTAT"
chmod $HDIRSTAT $HDIR

# In any case remove the temp dir
rm -rf $WODTMPDIR

echo "Install ending at `date`"
