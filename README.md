# undercloud-live

Tools and scripts to build an undercloud Live CD and configure an already
running Fedora 19 x86_64 system into an undercloud.  The script is meant to be run on
physical hardware.  However, it can also be used on a vm.  When using a vm you need to make
sure that the vm you intend to configure as a undercloud has been configured to
use nested kvm (see [References](#references)).

To get started, clone this repo to your home directory:

    $ cd
    $ git clone https://github.com/agroup/undercloud-live.git

## bin/undercloud.sh
This script is run as the current user to configure the current system into an
undercloud.

The undercloud makes use of the default libvirtd network of 192.168.122.0/24.
If you want to change the network (e.g., you're running the script on a vm
whose host is already using 192.168.122.0/24), edit
undercloud-live/bin/custom.sh, and then source that file:

    # Edit undercloud-live/bin/custom-network.sh, and set the environment
    # variables in the file to your desired settings.
    $ vi undercloud-live/bin/custom-network.sh
    $ source undercloud-live/bin/custom-network.sh

Run the undercloud script itself:

    $ undercloud-live/bin/undercloud.sh

The script logs to ~/.undercloud-live/undercloud.log.  If there is an error
applying one of the diskimage-builder elements, you will see a prompt to
continue or not.  This is for debugging purposes.

Once the script has completed, you should have a functioning undercloud.  At
this point, you would move onto the next steps of building images and
deploying an overcloud.  These steps are also scripted in the
images.sh and deploy-overcloud.sh scripts.  You can
just run these scripts if you prefer to do that instead:

    $ undercloud-live/bin/images.sh
    $ undercloud-live/bin/deploy-overcloud.sh

NOTE: undercloud-images.sh will not build images if the files already exist under
/opt/stack/images.  If you already have image files you want to use on the
undercloud, just copy them into /opt/stack/images.


### Prerequisites
* Only works on Fedora 19 x86_64
* sudo as root ability

### Caveats
* undercloud.sh deploys software from git repositories and directly from PyPi.
  This will be updated to use rpm's at a later date.
* The git repositories that are checked out under /opt/stack are set to
  checkout specific hashes.  Some of these hashes are specified in
  bin/install.sh.  Others are specified in an undercloud-live branch
  of a fork of tripleo-image-elements at
  https://github.com/slagle/tripleo-image-elements.git.  The undercloud-live
  branch there sets specific hashes to use via the source-repository interface.
* If you reboot the undercloud system, you will need to rerun
  bin/network.sh
* The system is configured to use the iptables service instead of the firewalld
  service.
* SELinux is set to Permissive mode.  Otherwise, rabbitmq-server will not
  start.
  See: https://bugzilla.redhat.com/show_bug.cgi?id=998682
  Note: we will be switching to use qpid soon

## kickstarts
The kickstart files can be used with livecd-tools to build live images.

1. install spin-kickstarts and livecd-tools if needed

They produce iso's in the current directory from which the below commands are
run.  To test the isos you can do something like:

    qemu-kvm -m 2048 Fedora-Undercloud-LiveCD.iso

### fedora-undercloud-livecd.ks
kickstart file that can be used to build an Undercloud Live CD.

1. livecd-creator --debug --verbose  --fslabel=Fedora-Undercloud-LiveCD --cache=/var/cache/yum/x86_64/19 --releasever=19 --config=/path/to/undercloud-live/kickstart/fedora-undercloud-livecd.ks -t /tmp/

### fedora-undercloud-control-livecd.ks
kickstart file that can be used to build an Undercloud Control Live CD.

1. livecd-creator --debug --verbose --title "Fedora Undercloud Control" --fslabel=Fedora-Undercloud-Control-LiveCD --cache=/var/cache/yum/x86_64/19 --releasever=19 --config /path/to/undercloud-live/kickstart/fedora-undercloud-control-livecd.ks -t /tmp/

### fedora-undercloud-leaf-livecd.ks
kickstart file that can be used to build an Undercloud Leaf Live CD.

1. livecd-creator --debug --verbose --title "Fedora Undercloud Leaf" --fslabel=Fedora-Undercloud-Leaf-LiveCD --cache=/var/cache/yum/x86_64/19 --releasever=19 --config /path/to/undercloud-live/kickstart/fedora-undercloud-leaf-livecd.ks -t /tmp/

## Live CD

The Live CD provides a full working undercloud environment.  Note that the [Caveats](#caveats) from the section above
apply to the Live CD as well as it is built using the same installation scripts.

Also keep in mind that any changes made to the filesystem while running the Live CD are lost after you reboot
or use the install to disk method.  Therefore, if you plan to install, I recommend doing this first before
building images on your undercloud, etc.

Currently the Live CD uses an XFCE based desktop for no particular reason other than that it builds faster, uses
less disk space, and has a much more responsive desktop when testing from within a vm.  It can be switched to Gnome
later.

### Requirements
1. RAM
 * >= 8GB if you plan to immediately install the live cd to disk
 * >= 16GB if you plan to just run the live cd and immediately start building images, etc.
1. Disk (if you plan to install)
 * >= 25GB (the bigger the better obviously if you plan to upload/build many images)
1. Nested KVM (if you plan to use a vm for the Live CD itself)
 * setup up Nested KVM (see [References](#references)  below)
 * if you don't want to use Nested KVM, make sure you switch all your vm's to use just
   qemu virtualization in their libvirt xml.

### Running/Installing (All-in-One)
To use the live cd, follow the steps below.

1. Boot the live cd.
 * The default account is liveuser.  However, you can use stack/stack for ssh access, etc.
 * If you plan to install to disk, do so after the boot is finished. Use the icon on the desktop, or ssh in with
   X forwarding and run /sbin/liveinst.
 * Once the install has finished, reboot and continue on with the next step. After rebooting, you
   will need to use stack/stack to login as liveuser no longer exists.
1. Open a terminal and switch to the stack user (if you aren't already):

        su -
        su - stack
1. Source the undercloud configuration

        source /etc/sysconfig/undercloudrc

From here, you can use all the normal openstack clients to interact with the
running undercloud services.

To get going on deploying an overcloud, you will want to build images and start
the overcloud.  There are scripts to do these pieces as well, but we may change
that into just documentation instructions so that users get the full experience
of setting up an overcloud themselves.  The scripts are here:

    /opt/stack/undercloud-live/bin/images.sh
    /opt/stack/undercloud-live/bin/deploy-overcloud.sh

After the overcloud is deployed, you can do the following to interact with
it's services:

    export OVERCLOUD_IP=$(nova list | grep notcompute.*ctlplane | sed  -e "s/.*=\\([0-9.]*\\).*/\1/")
    source /opt/stack/tripleo-incubator/overcloudrc

### Running/Installing (2-node)
The 2-node (control and leaf) version of undercloud-live uses the host's
libvirt instance for the baremetal nodes.  This makes it easier to use vm's for
everythng, but, there is some host setup that needs to be done.

Each step below (where applicable) is prefaced with what system to run it on.
 * HOST - the virtualization host you're using to run vm's
 * CONTROL - undercloud control node
 * LEAF - undercloud leaf node

Commands on the Host can be run as your normal user.

Commands on the Control and Leaf nodes should be run as the stack user unless
specified otherwise.

1. [HOST] Define and use a $TRIPLEO_ROOT directory

        mkdir tripleo
        export TRIPLEO_ROOT=/full/path/to/tripleo
        cd $TRIPLEO_ROOT

1. [HOST] Clone the repositories for tripleo-incubator and undercloud-live.

        git clone https://github.com/openstack/tripleo-incubator
        git clone https://github.com/agroup/undercloud-live
        pushd undercloud-live
        git checkout slagle/package
        popd

1. [HOST] Add the tripleo scripts to your path.

        export PATH=$TRIPLEO_ROOT/tripleo-incubator/scripts:$PATH

1. [HOST] Define environment variables for the baremetal nodes.

        export NODE_CPU=1
        export NODE_MEM=2048
        export NODE_DISK=20 
        export NODE_ARCH=amd64

1. [HOST] Ensure that openvswitch is started

        sudo service openvswitch start

1. [HOST] Setup the brbm openvswitch bridge and libvirt network.

        setup-network

1. [HOST] Create the baremetal nodes.  Specify the path to your undercloud-live 
   checkout as needed.  Save the output of this command, you will need it later.

        undercloud-live/bin/nodes.sh

1. [HOST] Create a vm for the control node, and one for the leaf node.  There
   are libvirt templates called ucl-control-live and ucl-leaf-live in the
   undercloud-live checkout in the templates directory to *help* with this.
   Review the templates and make any changes you'd like (to increate ram, etc).
   
1. [HOST] Before starting the vm for the leaf node, edit it's libvirt xml and
   add the following as an additional network interface (this is already added
   in the templates above, so if you used those, you don't need to do this
   step).

        <interface type='network'>
            <source network='brbm'/>
            <model type='e1000'/>
        </interface>

1. [HOST] Boot the vm's for the control and leaf nodes from their respective
   iso images.

1. [CONTROL],[LEAF] Install the images to disk.
   There is a kickstart file included on the images to make this easier.
   However, before using the kickstart file, first make sure that a network
   configuration script exists for every network interface (this might be
   a Fedora bug).  Here are some example commands that copy network scripts for 
   a system with 1 interface, and a system with 2 interfaces

        # System with 1 interface called ens3
        sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-ens3

        # System with 2 interfaces, ens3 and ens6
        sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-ens3
        sudo cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-ens6
   
1. [CONTROL],[LEAF] Make any needed changes to the kickstart file and then run
   (This should be run as liveuser, not root):

        liveinst --kickstart /opt/stack/undercloud-live/kickstart/anaconda-ks.cfg

1. [CONTROL],[LEAF] Once the install has finished, reboot the control and leaf
   vm's.  Make sure when they reboot, they boot from disk, not iso.  You can
   login with either stack/stack or root/root.

1. [CONTROL] Edit /etc/sysconfig/undercloud-live-config and set all
   the defined environment variables in the file.  Rememver to set
   $UNDERCLOUD_MACS based on the output from when nodes.sh was run earlier.  
   Refer to
   https://github.com/agroup/undercloud-live/blob/slagle/package/elements/undercloud-environment/install.d/02-undercloud-metdata
   for documentation of the environment variables (documentation was added to
   the file directly in a later commit).
   Once edited,  run undercloud-metadata
   on the control node to refresh the configuration.

        sudo undercloud-metadata

   Use the command in the output from undercloud-metadata to watch/tail the log
   of os-collect-config.  Make sure it runs successfully once.  You'll be able
   to tell when you see "Completed phase post-configure" in the log.

1. [LEAF] Edit /etc/sysconfig/undercloud-live-config and set all
   the defined environment variables in the file.  
   Refer to
   https://github.com/agroup/undercloud-live/blob/slagle/package/elements/undercloud-environment/install.d/02-undercloud-metdata
   for documentation of the environment variables (documentation was added to
   the file directly in a later commit).
   Once edited,  run undercloud-metadata
   on the control node to refresh the configuration.

        sudo undercloud-metadata

   Use the command in the output from undercloud-metadata to watch/tail the log
   of os-collect-config.  Make sure it runs successfully once.  You'll be able
   to tell when you see "Completed phase post-configure" in the log.

1. Copy over images, or build them on the control node for the deploy kernel
   and overcloud images.  If you don't provide the images, the next step will
   attempt to create them for you.  You will need the following images to exist
   on the control node.  

        /opt/stack/images/overcloud-control.qcow2
        /opt/stack/images/overcloud-compute.qcow2
        /opt/stack/images/deploy-ramdisk.initramfs
        /opt/stack/images/deploy-ramdisk.kernel

1. [CONTROL] Load the images into glance.

        /opt/stack/undercloud-live/bin/images.sh

1. [CONTROL] Run the script to setup the baremetal nodes, and define
   the baremetal flavor.

        /opt/stack/undercloud-live/bin/baremetal-2node.sh

1. [HOST] Add the configured virtual power host key to ~/.ssh/authorized_keys
   on the host.  Define $LEAF_IP as needed for your environment.

        export LEAF_IP=192.168.122.101
        ssh stack@$LEAF_IP "cat /opt/stack/boot-stack/virtual-power-key.pub" >> ~/.ssh/authorized_keys

1. [CONTROL] Deploy an Overcloud.  If you're deploying the Overcloud to
   baremetal, first edit deploy-overcloud.sh and update $OVERCLOUD_LIBVIRT_TYPE
   to "kvm" instead.  This script writes out the tripleo-overcloud-passwords
   file, so I suggest running it from the stack user's home dir.

        /opt/stack/undercloud-live/bin/deploy-overcloud.sh

1. [CONTROL] To use any of the OpenStack clients, source the undercloudrc file
   first:

        source /etc/sysconfig/undercloudrc

### Live Image Additional Info

1. You can use the Install to Hard Drive shortcut on the desktop to install the
   live cd to disk.  When you do this, any changes that you had made, will be
   lost and you'll need to start over with image building, etc when you boot
   the now installed undercloud.
1. When running the live cd there is only 512mb worth of changes that can be
   applied to the root filesystem and this fills up rather quickly with just
   logs, etc.  As such, the following directories are all tmpfs mounted:
 1. /home/stack/.cache/image-create/ccache
 1. /home/stack/.cache/image-create/yum
 1. /opt/stack/images
 1. /var/lib/glance/images
 1. /var/lib/libvirt/images
 1. /var/lib/nova/instances



# References

## Nested KVM Setup Help
1. http://www.server-world.info/en/note?os=Fedora_19&p=kvm&f=8
1. https://fedoraproject.org/wiki/QA:Testcase_KVM_nested_virt
