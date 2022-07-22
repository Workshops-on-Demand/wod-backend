#!/bin/bash

# Automate Wod server creation
 vagrant halt
 vagrant up
 vagrant ssh -c "sudo /vagrant/install.sh"
