# Fresh OS install via ILO e.g: using ubuntu-20.04.1-live-server-amd64.iso or with a VM template or an autodeploy mechanism
user creation user wodadmin / P@ssw0rd
sshd server, up to date git and ansible installed
* Ubuntu: 
 - sudo apt install -y ansible git openssh-server
* Centos7:
 - sudo yum -y install epel-release
 - sudo yum install -y ansible git openssh-server
 - sudo yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
 - sudo yum update git
setup ssh for wodadmin account
ssh-keygen -t rsa -b 4096
add appropriate id_rsa.pub files in authorized_keys
(copy ssh keys from another jupyterhub server e.g. with scp -p /home/wodadmin/.ssh/id_[jms]* new:.ssh/)
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/id_*.pub
test ssh connection with ssh localhost ls
setup sudo:
sudo visudo
  wodadmin ALL=(ALL) NOPASSWD:ALL


# If reusing an existing install
cleanup potential old apt setup
cleanup potential /usr/local/{bin,lib,go} content
stop a potentially running jupyter service
setup wodadmin account (or rename previous one) as above

# Take a snapshot of that setup if you want to reproduce

# Now you're ready to install a jupyterhub env !

# If you have write commit access
GIT_SSH_COMMAND='ssh -i ~/.ssh/id_jupproc -v ' git clone git@github.com:Workshops-on-Demand/wod-backend.git
check that this line is in .git/config: sshCommand = ssh -i ~/.ssh/id_jupproc -F /dev/null
# If you don't
git clone https://github.com/Workshops-on-Demand/wod-backend.git

cd wod-backend
./scripts/install_backend.sh
