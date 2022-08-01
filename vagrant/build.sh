#!/bin/bash

# Automate Wod server creation
# By default work with CentOS 7 - 
# Change the link to the Vagrantfile to point to an Ubuntu one
ln -sf Vagrantfile.centos-7 Vagrantfile
vagrant halt
vagrant up
vagrant ssh -c "sudo /vagrant/install.sh"
