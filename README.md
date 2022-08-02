# wod-backend
This project is the back-end part of our Workshop-on-Demand setup.

Instruction for installation are in INSTALL.md

It will setup a complete jupyterhub with extensions on your system, ready to host Workshops on demand that you can find at https://github.com/Workshops-on-Demand/wod-notebooks.git

# deliver
This command has to be run whenever some changes are made to any .j2 or ansible file. It will update scripts and relevants files related to the platform on which the deliver script is launched.


## Setup Appliances for Workshops:
Necessary scripts to run set up for workshops appliances 
pre reqs:
- Workshop entry in front end DB
- Necessary infos in ansible variable file defining platform on which the Workshop will run (definied in plaftform yaml file in ansible/group-vars/...)
- Necessary scripts:
    -setup-WKSHP-Workshop-name.sh.j2
    -In case of Docker Appliance:
      - Yaml file in ansible-jupyter folder:  setup_WKSHP-Dataspaces_appliance.yml
Steps:
* launch setup script for appliance (This script will prepare the appliance : adding pre reqs and users)
* ./setup-appliance.sh WKSHP-Workshop-name
