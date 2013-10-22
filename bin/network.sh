#!/bin/bash

set -eux

source /opt/stack/undercloud-live/bin/common.sh
source /etc/profile.d/virsh.sh

# This script needs to be rerun if you reboot the undercloud.

wait_for 12 10 ls /var/run/libvirt/libvirt-sock

PUBLIC_INTERFACE=${PUBLIC_INTERFACE:-ucl0}

sudo sed -i "s/bridge name='brbm'/bridge name='br-ctlplane'/" /opt/stack/tripleo-incubator/templates/brbm.xml

# puppet will start dnsmasq service, need to stop it to allow
# the default network to come up
sudo service nova-bm-dnsmasq stop || true

# change interface in local heat metadata if eth0 is present
if ifconfig | grep eth0; then
    sudo sed -i "s/\"public_interface\": \"eth1\"/\"public_interface\": \"eth0\"/g" /var/lib/heat-cfntools/cfn-init-data
fi

/opt/stack/tripleo-incubator/scripts/setup-network

sudo ip link del $PUBLIC_INTERFACE || true
sudo ip link add $PUBLIC_INTERFACE type dummy

sudo /usr/local/bin/init-neutron-ovs
