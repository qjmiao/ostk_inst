#!/bin/bash
shopt -s expand_aliases
set -e
set -u

##+++ PREINST +++
## </etc/sysconfig/selinux>
## SELINUX=disabled
##
## lokkit --disabled
##
## </etc/hosts>
##=== PREINST ===

OS_CTL_IP=${OS_CTL_IP:-192.168.56.100}
OS_ADMIN_IF=${OS_ADMIN_IF:-eth1}
OS_PRIV_IF=${OS_PRIV_IF:-eth2}
OS_ADMIN_IP=$(ip addr show dev $OS_ADMIN_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

backup_cfg_file() {
if [! -f $1.orig]; then
    cp $1 $1.orig
fi
}

yum install -y openstack-utils openstack-nova-compute openstack-quantum-linuxbridge

service messagebus start
service libvirtd start

virsh net-destroy default
virsh net-undefine default

alias nova-cfg="openstack-config --set /etc/nova/nova.conf"

backup_cfg_file /etc/nova/nova.conf

nova-cfg DEFAULT libvirt_type qemu
nova-cfg DEFAULT qpid_hostname $OS_CTL_IP
nova-cfg DEFAULT glance_host $OS_CTL_IP

nova-cfg DEFAULT network_api_class nova.network.quantumv2.api.API
nova-cfg DEFAULT security_group_api quantum
nova-cfg DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
nova-cfg DEFAULT quantum_url http://$OS_CTL_IP:9696
nova-cfg DEFAULT quantum_auth_strategy keystone
nova-cfg DEFAULT quantum_admin_auth_url http://$OS_CTL_IP:35357/v2.0
nova-cfg DEFAULT quantum_admin_tenant_name service
nova-cfg DEFAULT quantum_admin_username quantum
nova-cfg DEFAULT quantum_admin_password pass

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

alias Q-cfg="openstack-config --set /etc/quantum/quantum.conf"
alias LB-cfg="openstack-config --set /etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini"

backup_cfg_file /etc/quantum/quantum.conf

Q-cfg DEFAULT rpc_backend quantum.openstack.common.rpc.impl_qpid
Q-cfg DEFAULT qpid_hostname $OS_CTL_IP

backup_cfg_file /etc/quantum/plugins/linuxbridge/linuxbridge_conf.ini

LB-cfg LINUX_BRIDGE physical_interface_mappings physnet1:$PRIV_IF

chkconfig quantum-linuxbridge-agent on
service quantum-linuxbridge-agent start
