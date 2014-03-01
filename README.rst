===========================
Install OpenStack on CentOS
===========================

Overview
========
This document describes how to install OpenStack Havana release on CentOS-6.5.

The installation can be (1) single controller node plus multiple compute nodes
or (2) all-in-one single node.

Controller node also acts as storage node and network node.

Neutron setup uses (ML2 plugin + OVS) combination.

Install and Setup CentOS
========================
During CentOS installation, please (1) reserve one disk partition or
(2) reverve free space on system LVM2 volume group.

After CentOS-6.5/x86_64 is installed (on either controller node or compute node),
please do the following setup:

1. Disable SELinux::

    # edit /etc/sysconfig/selinux
    SELINUX=disabled

2. Disable firewall::

    $ lokkit --disabled

3. Add static host entries::

    # edit /etc/hosts
    X.X.X.X os-controller
    X.X.X.X os-compute1
    X.X.X.X os-compute2

4. Reboot

If one disk partition is dedicated for Cinder Service volume group::

  $ pvcreate /dev/sdX
  $ vgcreate cinder-volumes /dev/sdX

Setup YUM Repositories
======================
Please refer to ``ctos6-repo.sh`` also.

1. EPEL-6 Repo::

    $ rpm -i http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

2. RDO Repo::

    $ rpm -i http://repos.fedorapeople.org/repos/openstack/openstack-havana/rdo-release-havana-7.noarch.rpm

3. Update OS::

    $ yum update

Deployment Settings
===================
Example <os.cfg> file::

  OS_CTL_IP=192.168.1.1

  OS_ADMIN_IF=eth0
  OS_DATA_IF=eth1
  OS_ISCSI_IF=eth0
  OS_ISCSI_VG=cinder-volumes
  OS_NET_VLANS=100:199

  MYSQL_PW=admin
  OS_ADMIN_PW=admin
  OS_GLANCE_PW=glance
  OS_CINDER_PW=cinder
  OS_NEUTRON_PW=neutron
  OS_NOVA_PW=nova

Controller Node
===============
<ctos6-controller-inst.sh>::

  $ ctos6-controller-inst.sh os.cfg mysql
  $ ctos6-controller-inst.sh os.cfg qpid
  $ ctos6-controller-inst.sh os.cfg ostk-all

  # edit /etc/openstack-dashboard/local_settings
  ALLOWED_HOSTS = ['*']

  $ service httpd restart

If you want controller node to run hypervisor and VMs::

  $ ctos6-controller-inst.sh os.cfg nova-compute

Compute Node
============
<ctos6-compute-inst.sh>::

  $ ctos6-compute-inst.sh os.cfg all

Uninstallation and Cleanups
===========================

Uninstall and cleanup compute node::

  $ ctos6-compute-uninst.sh all

Uninstall and cleanup controller node::

  $ ctos6-controller-uninst.sh all
