#!/bin/bash

# Script to finish customization of a Greenlake CentOS 7 VM suited for either jupyterhub or appliance usage

# Adapt network configuration
perl -pi -e 's|DNS1=.*|DNS1=8.8.8.8|' /etc/sysconfig/network-scripts/ifcfg-e*
perl -pi -e 's|GATEWAY=.*|GATEWAY=172.17.70.250|' /etc/sysconfig/network-scripts/ifcfg-e*
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
EOF
perl -pi -e 's|^|#|' /etc/environment
iface_file=$(basename "$(find /etc/sysconfig/network-scripts/ -name 'ifcfg*' -not -name 'ifcfg-lo' | head -n 1)")
iface_name=${iface_file:6}
if [ _"$iface_name" != _"eth0" ]; then
	mv /etc/sysconfig/network-scripts/$iface_file /etc/sysconfig/network-scripts/ifcfg-eth0
	perl -pi -e "s/$iface_name/eth0/" /etc/sysconfig/network-scripts/ifcfg-eth0
	echo 'NM_CONTROLLED=\"no\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0
fi
export http_proxy=""
export https_proxy=""
export https_no_proxy=""
export no_proxy=""
export ftp_proxy=""
/etc/init.d/network restart
systemctl stop NetworkManager
systemctl disable NetworkManager

#PKG="yum"
PKG="apt"
# Update system²
$PKG update -y
if [ _"$PKG" = _"apt" ]; then
	$PKG upgrade -y
fi
$PKG -y install epel-release
$PKG -y install open-vm-tools
$PKG -y install cloud-init cloud-utils-growpart dracut-modules-growroot git wget ntp curl unzip ansible

# System setup
perl -pi -e 's|SELINUX=.*|SELINUX=permissive|' /etc/selinux/config
perl -pi -e 's/quiet/quiet net.ifnames=0 biosdevname=0/' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
cat >> /etc/sudoers.d/90-cloud-init-users << EOF
# User rules for jupyter
jupyter ALL=(ALL) NOPASSWD:ALL
EOF
