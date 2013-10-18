#!/bin/bash

set -eux

if [ -f /opt/stack/undercloud-live/.install-leaf ]; then
    echo install-leaf.sh has already run, exiting.
    exit
fi

# Configure yum to preserve it's cache.
# This is actually because of livecd-tools behavior, where this needs to be set
# in the chroot, but it's not happening.
sudo sed -i "s/keepcache=0/keepcache=1/g" /etc/yum.conf

# Doing this just so that this script can be run on top of a control node.  If
# the package is already installed, when yum goes to install it later, it will
# fail.  No other packages depend on it, so this is safe to do.
sudo yum erase -y rdo-release-havana

# Make sure pip is installed
sudo yum install -y python-pip

# busybox is a requirement of ramdisk-image-create from diskimage-builder
sudo yum install -y busybox

# which is not installed in minimal Fedora images
sudo yum install -y which

# iptables is used instead of firewalld
sudo yum install -y iptables-services

# The packaged version of pbr that gets installed is
# python-pbr-0.5.19-2.fc19.noarch
# However, the unpackaged os-*-config expect pbr>=0.5.21, so we need to still
# use pip to update pbr for now.
sudo pip install -U pbr

# This directory is still required because not all the elements in
# tripleo-puppet-elements has been updated to use packages, specifically
# os-*-config still use git clones and expect this directory to be created.
sudo mkdir -m 777 -p /opt/stack
sudo mkdir -m 777 -p /opt/stack/boot-stack
pushd /opt/stack

if ! [ $(git config --global user.email) ]; then
    git config --global user.email "you@example.com"
fi
if ! [ $(git config --global user.name) ]; then
    git config --global user.email "Your Name"
fi


if ! [ -d python-dib-elements ]; then
    git clone https://github.com/agroup/python-dib-elements.git
fi

if ! [ -d undercloud-live ]; then
    git clone https://github.com/agroup/undercloud-live.git
    pushd undercloud-live
    git checkout slagle/package
    git pull
    popd
fi

if ! [ -d tripleo-incubator ]; then
    git clone https://github.com/openstack/tripleo-incubator.git
    pushd tripleo-incubator
    git config user.email "you@example.com"
    git config user.email "Your Name"
    # Oct 8 commit 'Switch from ">/dev/stderr" to ">&2"'
    # For the next ones let's use cherry-pick.
    # NOTE(lucasagomes): cherry-pick will require the git
    # global config to be set
    git reset --hard 8031466c1688e686d121de9a59fd4b59096b9115
    popd
fi

if ! [ -d diskimage-builder ]; then
    git clone https://github.com/openstack/diskimage-builder.git
    pushd diskimage-builder
    git config user.email "you@example.com"
    git config user.email "Your Name"
    git checkout 9211a7fecbadc13e8254085133df1e3b53f150d8
    git fetch https://review.openstack.org/openstack/diskimage-builder refs/changes/30/46230/1 && git cherry-pick -x FETCH_HEAD
    git fetch https://review.openstack.org/openstack/diskimage-builder refs/changes/21/52321/3 && git cherry-pick -x FETCH_HEAD
    git fetch https://review.openstack.org/openstack/diskimage-builder refs/changes/49/52349/3 && git cherry-pick -x FETCH_HEAD
    git fetch https://review.openstack.org/openstack/diskimage-builder refs/changes/38/52538/1 && git cherry-pick -x FETCH_HEAD
    popd
fi

if ! [ -d tripleo-puppet-elements ]; then
    git clone https://github.com/agroup/tripleo-puppet-elements.git
fi

if ! [ -d tripleo-heat-templates ]; then
    git clone https://github.com/openstack/tripleo-heat-templates.git
    pushd tripleo-heat-templates
    git config user.email "you@example.com"
    git config user.email "Your Name"
    # Sept 18 commit "Add functional tests and examples for merge"
    git reset --hard 0dbf2810a0ee78658c35e61dc447c5f968226cb9
    popd
fi

sudo pip install -e python-dib-elements
sudo pip install -e diskimage-builder

# Add scripts directory from tripleo-incubator and diskimage-builder to the
# path.
# These scripts can't just be symlinked into a bin directory because they do
# directory manipulation that assumes they're in a known location.
if [ ! -e /etc/profile.d/tripleo-incubator-scripts.sh ]; then
    sudo bash -c "echo export PATH='\$PATH':/opt/stack/tripleo-incubator/scripts/ >> /etc/profile.d/tripleo-incubator-scripts.sh"
    sudo bash -c "echo export PATH=/opt/stack/diskimage-builder/bin/:'\$PATH' >> /etc/profile.d/tripleo-incubator-scripts.sh"
fi

# sudo run from nova rootwrap complains about no tty
sudo sed -i "s/Defaults    requiretty/# Defaults    requiretty/" /etc/sudoers
# need to be able to pass in a modified $PATH for sudo for dib-elements to work
sudo sed -i "s/Defaults    secure_path/# Defaults    secure_path/" /etc/sudoers

# Exclude some elements if it appears that we're running this script on top of
# a control node.  We use the existence of /opt/stack/novnc to determine that.
if [ -d /opt/stack/novnc ]; then
    EXCLUDE_ELEMENTS="novnc stackuser"
else
    EXCLUDE_ELEMENTS=
fi

# This blacklists the script that removes grub2.  Obviously, we don't want to
# do that in this scenario.
dib-elements -p diskimage-builder/elements/ tripleo-puppet-elements/elements/ \
    -e fedora openstack-m-repo \
    -k extra-data pre-install \
    -b 15-fedora-remove-grub \
    -x yum \
    -i
dib-elements -p diskimage-builder/elements/ tripleo-puppet-elements/elements/ \
    -e source-repositories nova-baremetal bm-dnsmasq neutron-network-node \
    -k extra-data \
    -x yum $EXCLUDE_ELEMENTS \
    -i
# rabbitmq-server does not start with selinux enforcing.
# https://bugzilla.redhat.com/show_bug.cgi?id=998682
dib-elements -p diskimage-builder/elements/ tripleo-puppet-elements/elements/ \
                undercloud-live/elements \
    -e nova-baremetal bm-dnsmasq neutron-network-node \
       stackuser heat-cfntools \
       undercloud-leaf-config undercloud-environment \
       selinux-permissive \
    -k install \
    -x yum $EXCLUDE_ELEMENTS \
    -i

popd

# the current user needs to always connect to the system's libvirt instance
# when virsh is run
if [ ! -e /etc/profile.d/virsh.sh ]; then
    sudo su -c "cat >> /etc/profile.d/virsh.sh <<EOF

# Connect to system's libvirt instance
export LIBVIRT_DEFAULT_URI=qemu:///system

EOF
"
fi

source /opt/stack/undercloud-live/bin/custom-network.sh

# These variables are meant to be overridden if they need to be changed.
# If you're testing on a vm that is running on a host with the default
# 192.168.122.1 network already defined, you will want to set environment
# variables to override these.
NETWORK=${NETWORK:-192.168.122.1}
LIBVIRT_IP_ADDRESS=${LIBVIRT_IP_ADDRESS:-192.168.122.1}
LIBVIRT_NETWORK_RANGE_START=${LIBVIRT_NETWORK_RANGE_START:-192.168.122.2}
LIBVIRT_NETWORK_RANGE_END=${LIBVIRT_NETWORK_RANGE_END:-192.168.122.254}

sudo sed -i "s/192.168.122.1/$LIBVIRT_IP_ADDRESS/g" /etc/libvirt/qemu/networks/default.xml
sudo sed -i "s/192.168.122.2/$LIBVIRT_NETWORK_RANGE_START/g" /etc/libvirt/qemu/networks/default.xml
sudo sed -i "s/192.168.122.254/$LIBVIRT_NETWORK_RANGE_END/g" /etc/libvirt/qemu/networks/default.xml

# Need to get a patch upstream for this, but for now, just fix it locally
# Run os-config-applier earlier in the os-refresh-config configure.d phase
sudo mv /opt/stack/os-config-refresh/configure.d/50-os-config-applier \
        /opt/stack/os-config-refresh/configure.d/40-os-config-applier

touch /opt/stack/undercloud-live/.install-leaf
