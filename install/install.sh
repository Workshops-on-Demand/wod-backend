#!/bin/bash

set -e
set -u
set -o pipefail

usage() {
	echo "install.sh [-h][-t type][-g groupname][-b backend][-f frontend][-a api-db][-e external]"
	echo " "
	echo "where:"
	echo "type      is the installation type"
	echo "          example: backend, frontend or api-db"
	echo "          if empty using 'backend'                "
	echo "groupname is the ansible group_vars name to be used"
	echo "          example: production, staging, test, ...  "
	echo "          if empty using 'production'                "
	echo "backend   is the FQDN of the back-end JupyterHub server"
	echo "          example: be.internal.example.org  "
	echo "          if empty using the local name for the back-end                "
	echo "frontend  is the FQDN of the front-end Web server"
	echo "          example: fe.example.org  "
	echo "          if empty using the external name for the back-end                "
	echo "api-db    is the FQDN of the API/DB server "
	echo "          example: api.internal.example.org  "
	echo "          if empty using the name for the front-end                "
	echo "external  is the external FQDN of the back-end JupyterHub server, reachable from the Internet"
	echo "          example: jphub.example.org  "
	echo "          if empty using the internal name of the back-end                "
}

echo "install.sh called with $*"
# Run as root
t=""
f=""
e=""
b=""
a=""
g=""

while getopts "t:f:e:b:a:g:h" option; do
    case "${option}" in
        t)
            t=${OPTARG}
            if [ ${t} !=  "backend" ] && [ ${t} != "frontend" ] && [ ${t} != "api-db" ]; then
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
if [ ! -z "${g}" ]; then
	WODGROUP="${g}"
else
	WODGROUP="production"
fi
export WODGROUP WODFEFQDN WODBEFQDN WODAPIDBFQDN WODBEEXTFQDN WODTYPE
export WODBEIP=`host $WODBEFQDN | grep -v 'not found' | cut -d' ' -f4 | head -1`
export WODDISTRIB=`grep -E '^ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`-`grep -E '^VERSION_ID=' /etc/os-release | cut -d= -f2 | sed 's/"//g'`
export WODUSER="wodadmin"
echo "WODUSER: $WODUSER" > /etc/wod.conf

echo "Installing a Workshop on Demand $WODTYPE environment"
echo "Using frontend $WODFEFQDN"
echo "Using api-db $WODAPIDBFQDN"
echo "Using backend $WODBEFQDN ($WODBEIP)"
echo "Using external backend $WODBEEXTFQDN"
echo "Using groupname $WODGROUP"
echo "Using WoD user $WODUSER"

# redirect stdout/stderr to a file
mkdir -p $HOME/.jupyter
exec &> >(tee $HOME/.jupyter/install.log)

# Get path of execution
EXEPATH=`dirname "$0"`
export EXEPATH=`( cd "$EXEPATH" && pwd )`

source $EXEPATH/install.repo
export WODFEREPO WODBEREPO WODAPIREPO WODNOBOREPO WODPRIVREPO
# Needs to be root
# Call the distribution specific install script
echo "Installing $WODDISTRIB specificities for $WODTYPE"
$EXEPATH/install-system-$WODDISTRIB.sh

# Create the WODUSER user
if grep -qE "^$WODUSER:" /etc/passwd; then
        userdel -f -r $WODUSER
fi
useradd -U -m -s /bin/bash $WODUSER
# setup sudo for $WODUSER
cat > /etc/sudoers.d/$WODUSER << EOF
Defaults:$WODUSER !fqdn
Defaults:$WODUSER !requiretty
$WODUSER ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/$WODUSER

# Now drop priviledges
# Call the common install script to finish install
echo "Installing common remaining stuff as $WODUSER"
if [ $WODDISTRIB = "centos-7" ]; then
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
EOF
	chmod 644 /tmp/wodexports
	su - $WODUSER -c "source /tmp/wodexports ; $EXEPATH/install-system-common.sh"
	rm -f /tmp/wodexports
else
	su - $WODUSER -w WODGROUP,WODFEFQDN,WODBEFQDN,WODAPIDBFQDN,WODBEEXTFQDN,WODTYPE,WODBEIP,WODDISTRIB,WODUSER,WODFEREPO,WODBEREPO,WODAPIREPO,WODNOBOREPO,WODPRIVREPO -c "$EXEPATH/install-system-common.sh"
fi
