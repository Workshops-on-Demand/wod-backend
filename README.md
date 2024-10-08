# wod-backend
This project is the back-end part of our Workshop-on-Demand setup. It will setup :
* A complete jupyterhub with extensions on your system, ready to host Workshops on demand that you can find at https://github.com/Workshops-on-Demand/wod-notebooks.git
* A postfix server used for the procmail API
* An Ansible engine to allow automation
* A fail2ban server
* An Admin user to manage everything

Instructions for installation are in INSTALL.md


# wod-deliver
This command has to be run whenever some changes are made to any .j2 or ansible variables file. It will update scripts and relevants files related to the platform on which the wod-deliver script is launched.


## Setup Appliances for Workshops:
Pre reqs for appliance :
* Needs a centos 7 vm
* Needs admin account with sudo priviledges ( wodadmin in our case)
* Needs ssh keys setup from account (backend server) setup on the appliance

Necessary scripts to run set up for workshops appliances 
pre reqs:
- Workshop entry in front end DB
- Necessary infos in ansible variable file defining platform on which the Workshop will run (definied in plaftform yaml file in ansible/group-vars/...)
- Necessary scripts:
    -setup-WKSHP-Workshop-name.sh.j2
    -In case of Docker Appliance:
      - Yaml file in ansible folder:  setup_WKSHP-Dataspaces_appliance.yml
Steps:
* launch setup script for appliance (This script will prepare the appliance : adding pre reqs and users)
* ./setup-appliance.sh WKSHP-Workshop-name
