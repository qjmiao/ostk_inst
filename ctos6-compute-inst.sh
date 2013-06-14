#!/bin/bash
set -e
set -u

##
## </etc/sysconfig/selinux>
## SELINUX=disabled
##
## lokkit --disabled
##

OS_CTL_IP=${OS_CTL_IP:-192.168.56.100}
OS_ADMIN_IF=${OS_ADMIN_IF:-eth1}
OS_FLAT_IF=${OS_FLAT_IF:-eth2}
OS_ADMIN_IP=$(ip addr show dev $OS_ADMIN_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

if !(rpm -q epel-release); then
    yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
fi

if !(rpm -q rdo-release); then
    yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-grizzly/rdo-release-grizzly-3.noarch.rpm
fi

yum install -y openstack-utils openstack-nova-compute

virsh net-destroy default
virsh net-undefine default

alias nova-cfg="openstack-config --set /etc/nova/nova.conf"

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

service messagebus start
service libvirtd start

chkconfig openstack-nova-compute on
service openstack-nova-compute start
