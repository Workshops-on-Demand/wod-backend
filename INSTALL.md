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

sshd server, up to date git and ansible installer

* Ubuntu: 
   * sudo apt install -y ansible git openssh-server
* Centos7:
   * sudo yum -y install epel-release
   * sudo yum install -y ansible git openssh-server
   * sudo yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
   * sudo yum update git

setup ssh for installer user account
* ssh-keygen -t rsa -b 4096


# If public only based Workshops-on-Demand (No private backend nor workshops)

git clone https://github.com/Workshops-on-Demand/wod-backend.git

cd wod-backend/install

To customize default installation parameters: Please modify the following files :
* within ansible/group_vars directory
  * please edit all.yml file and adapt accordingly
  * please edit wod-system file and adapt accordingly
  * please edit wod-backend file and adapt accordingly

If private based Workshops-on-Demand (private backend + private workshops)

Please edit the install.repo file located in install directory if using a private repo : 
* Uncomment line :  token=`cat $EXEPATH/token`
* Update accordingly the last line with the correct url to clone 
WODPRIVREPO="git clone https://.....................wod-private.git wod-private"

PLease refer to the following urk to generate token :
https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
Ans uncomment the token line in th repo file




install script:
usage() {
        echo "install.sh [-h][-t type][-g groupname][-b backend][-f frontend][-a api-db][-e external][-u user]"
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
        echo "user      is the name of the admin user for the WoD project"
        echo "          example: mywodamin "
        echo "          if empty using wodadmin               "
}


sudo ./install.sh -t backend -g staging -b jup.example.net -f notebooks.example.io -a api.example.io -e notebooks.example.io


Install process details:


At the end of the installation process:
 * you will have a jupyterhub server running on port http 8000 
 * You will get a new wodadmin user



