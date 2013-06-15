#!/bin/bash
shopt -s expand_aliases
set -e
set -u

##+++ PREINST +++
## </etc/sysconfig/selinux>
## SELINUX=disabled
##
## lokkit --disabled
##=== PREINST ===

OS_CTL_IP=${OS_CTL_IP:-192.168.56.100}
OS_ADMIN_IF=${OS_ADMIN_IF:-eth1}
OS_FLAT_IF=${OS_FLAT_IF:-eth2}
OS_ADMIN_IP=$(ip addr show dev $OS_ADMIN_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

yum install -y openstack-utils openstack-nova-compute

service messagebus start
service libvirtd start

virsh net-destroy default
virsh net-undefine default

alias nova-cfg="openstack-config --set /etc/nova/nova.conf"

cp /etc/nova/nova.conf /etc/nova/nova.conf.orig

nova-cfg DEFAULT libvirt_type qemu
nova-cfg DEFAULT qpid_hostname $OS_CTL_IP
nova-cfg DEFAULT glance_host $OS_CTL_IP
nova-cfg DEFAULT flat_interface $OS_FLAT_IF
nova-cfg DEFAULT vncserver_listen 0.0.0.0
nova-cfg DEFAULT vncserver_proxyclient_address $OS_ADMIN_IP
nova-cfg DEFAULT novncproxy_base_url http://$OS_CTL_IP:6080/vnc_auto.html
nova-cfg DEFAULT auth_strategy keystone

nova-cfg keystone_authtoken admin_tenant_name service
nova-cfg keystone_authtoken admin_user nova
nova-cfg keystone_authtoken admin_password pass
nova-cfg keystone_authtoken auth_host $OS_CTL_IP

chkconfig openstack-nova-compute on
service openstack-nova-compute start
