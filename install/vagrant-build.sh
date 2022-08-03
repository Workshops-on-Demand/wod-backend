#!/bin/bash

set -e
# Automate Wod server creation
# By default work with CentOS 7 - 
#default=ubuntu-20.04
default=centos-7
# Change the link to the Vagrantfile to point to an Ubuntu one
vagrant halt $default
vagrant up $default
vagrant ssh  $default -c "sudo /vagrant/install.sh"
