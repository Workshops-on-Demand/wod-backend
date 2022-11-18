# Jupyterhub server preparation:
* Fresh OS install on Physical / VM  server running Ubuntu 20.04 or Centos 7.9 via ILO e.g: using ubuntu-20.04.1-live-server-amd64.iso or with a VM template or an autodeploy mechanism
* to support 100 concurrent users :
  * 2 cpus or more machine
  *  128 Gigas of Ram
  * 500 Gigas of Drive



# Pre requesites: 
From Jupyterhub server

Create a linux  account with sudo priviledges on your linux distro.

As created user:

# For public only based Workshops-on-Demand (No private backend nor workshops)

* git clone https://github.com/Workshops-on-Demand/wod-backend.git
* cd wod-backend/install

To examine default installation parameters: Please look at the following files within ansible/group_vars directory:
  *  all.yml file
  *  wod-system file
  *  wod-backend file
 
# For private based Workshops-on-Demand (private backend + private workshops) or if you need to modify defaults
* Fork private repo (https://github.com/Workshops-on-Demand/wod-private.git) on github under your own github account
* Clone the forked repo:

git clone https://github.com/...................../wod-private.git wod-private

cd wod-private/ansible/group_vars
* Please edit the all.yml and << groupname >> files to customize your setup.
* Commit and push changes to your repo

cd $HOME/wod-backend/install
* edit the install.repo file located in install directory if using a private repo :
  * Update accordingly the last line with the correct url to clone 
WODPRIVREPO="git clone https://github.com/.........../wod-private.git wod-private"

** Note If using a token**
 PLease refer to the following url to generate token :
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
* edit the install.repo file located in install directory of wod-backend:
  * Uncomment line :  token=`cat $EXEPATH/token`
  * use the token in the url
  WODPRIVREPO="git clone https://user:$token@github.com/....../wod-private.git wod-private"
 
Install process details:
install script: install.sh
usage() {
        echo "install.sh [-h][-t type][-g groupname][-b backend][-f frontend][-a api-db][-e external][-u user]"
        
        echo " "
        
        echo "where:"
        
        echo "type      is the installation type"
        
        echo "          example: backend, frontend or api-db"
        
        echo "          if empty using 'backend'               "
        
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
        
        echo "user      is the name of the admin user for the WoD project"
        
        echo "          example: mywodamin "
          
        echo "          if empty using wodadmin               "
}

Example : 

sudo ./install.sh -t backend -g staging -b jup.example.net -f notebooks.example.io -a api.example.io -e notebooks.example.io


Install.sh calls :
* install-system-<< distribution name >>.sh
  * Install minimal requirered (Ansible, git, jq, openssh server, npm)
* creates an admin user as defined upper (default is wodadmin) with sudo rights
* install-system-common.sh
  * cleanup 
  * github repos cloning  (leveraging install.repo file) : Backend and Private
  * Create ssh keys for wodadmin
  * Creates GROUPNAME variables
  * Creates ansible inventory files
* install_system.sh with type (Backend, Frontend, etc..)
  * Install the necessary stack based on selected type
  * Create a wod.sh script in wod-backend directory to be used by all other scrits
  * Source the wod.sh file
  * Setup ansible-galaxies (community.general and posix)
  * Setup Ansible and call the playbook  install_<<TYPE>>.yml followed by the ansible_check_<<TYPE>>.yml

 Playbooks are self documented. Please check for details.


At the end of the installation process:
 * you will have a jupyterhub server running on port http 8000 
 * You will get a new wodadmin user
 * You will get a set of students



