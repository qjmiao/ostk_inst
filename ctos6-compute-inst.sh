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

usage() {
echo "Usage: $(basename $0) <CFG_FILE>"
exit 1
}

if [ $# != 1 ]; then
    usage
fi

source $1

OS_CTL_IP=${OS_CTL_IP:-192.168.1.1}
OS_ADMIN_IF=${OS_ADMIN_IF:-eth0}
OS_DATA_IF=${OS_DATA_IF:-eth1}

OS_NEUTRON_PW=${OS_NEUTRON_PW:-neutron}
OS_NOVA_PW=${OS_NOVA_PW:-nova}

OS_MY_IP=$(ip addr show dev $OS_ADMIN_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

alias nova-cfg="openstack-config --set /etc/nova/nova.conf"
alias neutron-cfg="openstack-config --set /etc/neutron/neutron.conf"
alias N_ovs-cfg="openstack-config --set /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini"

backup_cfg_file() {
if [ ! -f $1.orig ]; then
    cp $1 $1.orig
fi
}

yum install -y openstack-utils

##
## openstack-nova-compute
##
yum install -y openstack-nova-compute
backup_cfg_file /etc/nova/nova.conf

service messagebus start
service libvirtd start

virsh net-destroy default
virsh net-undefine default

nova-cfg DEFAULT qpid_hostname $OS_CTL_IP
nova-cfg DEFAULT glance_host $OS_CTL_IP

if [ ! -c /dev/kvm ]; then
    nova-cfg DEFAULT libvirt_type qemu
fi

nova-cfg DEFAULT network_api_class nova.network.neutronv2.api.API
nova-cfg DEFAULT security_group_api neutron
nova-cfg DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
nova-cfg DEFAULT neutron_url http://$OS_CTL_IP:9696
nova-cfg DEFAULT neutron_admin_auth_url http://$OS_CTL_IP:35357/v2.0
nova-cfg DEFAULT neutron_admin_tenant_name service
nova-cfg DEFAULT neutron_admin_username neutron
nova-cfg DEFAULT neutron_admin_password $OS_NEUTRON_PW

nova-cfg DEFAULT vncserver_listen $OS_MY_IP
nova-cfg DEFAULT vncserver_proxyclient_address $OS_MY_IP
nova-cfg DEFAULT novncproxy_base_url http://$OS_CTL_IP:6080/vnc_auto.html

nova-cfg DEFAULT auth_strategy keystone
nova-cfg keystone_authtoken auth_host $OS_CTL_IP
nova-cfg keystone_authtoken admin_tenant_name service
nova-cfg keystone_authtoken admin_user nova
nova-cfg keystone_authtoken admin_password $OS_NOVA_PW

chkconfig openstack-nova-compute on
service openstack-nova-compute start

##
## neutron-openvswitch-agent
##
yum install -y openstack-neutron-linuxbridge openstack-neutron-openvswitch
backup_cfg_file /etc/neutron/neutron.conf
backup_cfg_file /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

chkconfig openvswitch on
service openvswitch start

ovs-vsctl add-br br-int
ovs-vsctl add-br br-$OS_DATA_IF
ovs-vsctl add-port br-$OS_DATA_IF $OS_DATA_IF

neutron-cfg DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
neutron-cfg DEFAULT qpid_hostname $OS_CTL_IP
neutron-cfg agent root_helper "sudo neutron-rootwrap /etc/neutron/rootwrap.conf"
neutron-cfg securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

N_ovs-cfg ovs bridge_mappings physnet:br-$OS_DATA_IF

chkconfig neutron-openvswitch-agent on
service neutron-openvswitch-agent start
