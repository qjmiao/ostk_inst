===========================
Install OpenStack on CentOS
===========================

Overview
========
Steps on how to install OpenStack Havana release on CentOS-6.5.

Install and Setup CentOS
========================
After CentOS-6.5/x86_64 is installed (on either controller node or compute node),
please do the following setup:

1. Disable SELinux::

   </etc/sysconfig/selinux>
   SELINUX=disabled

2. Disable Firewall::

   $ lokkit --disabled

3. Add static host entries::

   </etc/hosts>
   X.X.X.X os-controller
   X.X.X.X os-compute1
   X.X.X.X os-compute2

4. Reboot

Setup YUM Repositories
======================
Please refer to ``ctos6-repo.sh`` also

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
``ctos6-controller-inst.sh``::

  $ ctos6-controller-inst.sh os.cfg mysql
  $ ctos6-controller-inst.sh os.cfg qpid
  $ ctos6-controller-inst.sh os.cfg ostk-all

Compute Node
============
``ctos6-compute-inst.sh``::

  $ ctos6-compute-inst.sh os.cfg all
