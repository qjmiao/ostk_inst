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

alias keystone-cfg="openstack-config --set /etc/keystone/keystone.conf"
alias glance-api-cfg="openstack-config --set /etc/glance/glance-api.conf"
alias glance-reg-cfg="openstack-config --set /etc/glance/glance-registry.conf"
alias cinder-cfg="openstack-config --set /etc/cinder/cinder.conf"
alias neutron-cfg="openstack-config --set /etc/neutron/neutron.conf"
alias N_meta-cfg="openstack-config --set /etc/neutron/metadata_agent.ini"
alias N_dhcp-cfg="openstack-config --set /etc/neutron/dhcp_agent.ini"
alias N_l3-cfg="openstack-config --set /etc/neutron/l3_agent.ini"
alias N_ml2-cfg="openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini"
alias N_lb-cfg="openstack-config --set /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini"
alias nova-cfg="openstack-config --set /etc/nova/nova.conf"

usage() {
    echo "Usage: $(basename $0) <CFG_FILE> <WHAT>"

    exit 1
}

backup_cfg_file() {
if [ ! -f $1.orig ]; then
    cp $1 $1.orig
fi
}

##
## Install MySQL server
##
install_mysql()
{
yum install -y mysql-server

chkconfig mysqld on
service mysqld start

mysqladmin -u root password $MYSQL_PW

mysql -u root --password=$MYSQL_PW <<EOF
drop user ''@localhost;
drop user ''@$(hostname);
EOF
}

##
## Install Qpid server
##
install_qpid()
{
yum install -y qpid-cpp-server

chkconfig qpidd on
service qpidd start
}

##
## Install OpenStack Keystone
##
install_keystone()
{
export OS_SERVICE_TOKEN=$(hexdump -e '"%x"' -n 5 /dev/urandom)
export OS_SERVICE_ENDPOINT=http://$OS_CTL_IP:5000/v2.0

local pw=$(hexdump -e '"%x"' -n 5 /dev/urandom)

mysql -u root --password=$MYSQL_PW <<EOF
create database keystone;
grant all on keystone.* to keystone@'%' identified by '$pw';
#grant all on keystone.* to keystone@localhost identified by '$pw';
flush privileges;
EOF

yum install -y openstack-keystone
backup_cfg_file /etc/keystone/keystone.conf

keystone-cfg DEFAULT admin_token $OS_SERVICE_TOKEN
keystone-cfg sql connection mysql://keystone:$pw@$OS_CTL_IP/keystone

keystone-manage db_sync
keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
rm -f /var/log/keystone/*.log

chkconfig openstack-keystone on
service openstack-keystone start

while ! keystone discover &> /dev/null; do
    sleep 1
done

keystone user-create --name admin --pass $OS_ADMIN_PW
keystone user-create --name glance --pass $OS_GLANCE_PW
keystone user-create --name cinder --pass $OS_CINDER_PW
keystone user-create --name neutron --pass $OS_NEUTRON_PW
keystone user-create --name nova --pass $OS_NOVA_PW

keystone tenant-create --name admin
keystone tenant-create --name service

keystone role-create --name admin

local admin_uid=$(keystone user-list | awk '/admin/ {print $2}')
local glance_uid=$(keystone user-list | awk '/glance/ {print $2}')
local cinder_uid=$(keystone user-list | awk '/cinder/ {print $2}')
local neutron_uid=$(keystone user-list | awk '/neutron/ {print $2}')
local nova_uid=$(keystone user-list | awk '/nova/ {print $2}')

local admin_tid=$(keystone tenant-list | awk '/admin/ {print $2}')
local service_tid=$(keystone tenant-list | awk '/service/ {print $2}')

local admin_rid=$(keystone role-list | awk '/admin/ {print $2}')

keystone user-role-add --user-id $admin_uid   --role-id $admin_rid --tenant-id $admin_tid
keystone user-role-add --user-id $glance_uid  --role-id $admin_rid --tenant-id $service_tid
keystone user-role-add --user-id $cinder_uid  --role-id $admin_rid --tenant-id $service_tid
keystone user-role-add --user-id $neutron_uid --role-id $admin_rid --tenant-id $service_tid
keystone user-role-add --user-id $nova_uid    --role-id $admin_rid --tenant-id $service_tid

keystone service-create --name keystone --type identity --description "Identity Service"
keystone service-create --name glance   --type image    --description "Image Service"
keystone service-create --name cinder   --type volume   --description "Volume Service"
keystone service-create --name neutron  --type network  --description "Network Service"
keystone service-create --name nova     --type compute  --description "Compute Service"

local keystone_sid=$(keystone service-list | awk '/keystone/ {print $2}')
local glance_sid=$(keystone service-list | awk '/glance/ {print $2}')
local cinder_sid=$(keystone service-list | awk '/cinder/ {print $2}')
local neutron_sid=$(keystone service-list | awk '/neutron/ {print $2}')
local nova_sid=$(keystone service-list | awk '/nova/ {print $2}')

keystone endpoint-create \
    --region Region1 --service-id $keystone_sid \
    --publicurl http://$OS_CTL_IP:5000/v2.0 \
    --internalurl http://$OS_CTL_IP:5000/v2.0 \
    --adminurl http://$OS_CTL_IP:35357/v2.0

keystone endpoint-create \
    --region Region1 --service-id $glance_sid \
    --publicurl http://$OS_CTL_IP:9292 \
    --internalurl http://$OS_CTL_IP:9292 \
    --adminurl http://$OS_CTL_IP:9292

keystone endpoint-create \
    --region Region1 --service-id $cinder_sid \
    --publicurl http://$OS_CTL_IP:8776/v1/$\(tenant_id\)s \
    --internalurl http://$OS_CTL_IP:8776/v1/$\(tenant_id\)s \
    --adminurl http://$OS_CTL_IP:8776/v1/$\(tenant_id\)s

keystone endpoint-create \
    --region Region1 --service-id $neutron_sid \
    --publicurl http://$OS_CTL_IP:9696 \
    --internalurl http://$OS_CTL_IP:9696 \
    --adminurl http://$OS_CTL_IP:9696

keystone endpoint-create \
    --region Region1 --service-id $nova_sid \
    --publicurl http://$OS_CTL_IP:8774/v2/$\(tenant_id\)s \
    --internalurl http://$OS_CTL_IP:8774/v2/$\(tenant_id\)s \
    --adminurl http://$OS_CTL_IP:8774/v2/$\(tenant_id\)s
}

##
## Install OpenStack Glance
##
install_glance()
{
local pw=$(hexdump -e '"%x"' -n 5 /dev/urandom)

mysql -u root --password=$MYSQL_PW <<EOF
create database glance;
grant all on glance.* to glance@'%' identified by '$pw';
#grant all on glance.* to glance@localhost identified by '$pw';
flush privileges;
EOF

yum install -y openstack-glance
backup_cfg_file /etc/glance/glance-api.conf
backup_cfg_file /etc/glance/glance-registry.conf

glance-api-cfg DEFAULT sql_connection mysql://glance:$pw@$OS_CTL_IP/glance
glance-api-cfg keystone_authtoken auth_host $OS_CTL_IP
glance-api-cfg keystone_authtoken admin_tenant_name service
glance-api-cfg keystone_authtoken admin_user glance
glance-api-cfg keystone_authtoken admin_password $OS_GLANCE_PW
glance-api-cfg paste_deploy flavor keystone

glance-reg-cfg DEFAULT sql_connection mysql://glance:$pw@$OS_CTL_IP/glance
glance-reg-cfg keystone_authtoken auth_host $OS_CTL_IP
glance-reg-cfg keystone_authtoken admin_tenant_name service
glance-reg-cfg keystone_authtoken admin_user glance
glance-reg-cfg keystone_authtoken admin_password $OS_GLANCE_PW
glance-reg-cfg paste_deploy flavor keystone

glance-manage db_sync
rm -f /var/log/glance/*.log

chkconfig openstack-glance-api on
service openstack-glance-api start

chkconfig openstack-glance-registry on
service openstack-glance-registry start
}

##
## Install OpenStack Cinder
##
install_cinder()
{
local pw=$(hexdump -e '"%x"' -n 5 /dev/urandom)

mysql -u root --password=$MYSQL_PW <<EOF
create database cinder;
grant all on cinder.* to cinder@'%' identified by '$pw';
#grant all on cinder.* to cinder@localhost identified by '$pw';
flush privileges;
EOF

yum install -y openstack-cinder
backup_cfg_file /etc/cinder/cinder.conf

cinder-cfg DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
cinder-cfg DEFAULT qpid_hostname $OS_CTL_IP
cinder-cfg DEFAULT iscsi_ip_address $OS_ISCSI_IP
cinder-cfg DEFAULT volume_group $OS_ISCSI_VG
cinder-cfg DEFAULT sql_connection mysql://cinder:$pw@$OS_CTL_IP/cinder
cinder-cfg DEFAULT auth_strategy keystone
cinder-cfg keystone_authtoken auth_host $OS_CTL_IP
cinder-cfg keystone_authtoken admin_tenant_name service
cinder-cfg keystone_authtoken admin_user cinder
cinder-cfg keystone_authtoken admin_password $OS_CINDER_PW

cinder-manage db sync

echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf
chkconfig tgtd on
service tgtd start

chkconfig openstack-cinder-api on
chkconfig openstack-cinder-volume on
chkconfig openstack-cinder-scheduler on

service openstack-cinder-api start
service openstack-cinder-volume start
service openstack-cinder-scheduler start
}

##
## Install OpenStack Quantum
##
install_neutron()
{
local pw=$(hexdump -e '"%x"' -n 5 /dev/urandom)

mysql -u root --password=$MYSQL_PW <<EOF
create database neutron;
grant all on neutron.* to neutron@'%' identified by '$pw';
#grant all on neutron.* to neutron@localhost identified by '$pw';
flush privileges;
EOF

yum install -y openstack-neutron-ml2 openstack-neutron-linuxbridge openstack-neutron-openvswitch
backup_cfg_file /etc/neutron/neutron.conf
backup_cfg_file /etc/neutron/metadata_agent.ini
backup_cfg_file /etc/neutron/dhcp_agent.ini
backup_cfg_file /etc/neutron/l3_agent.ini
backup_cfg_file /etc/neutron/plugins/linuxbridge/ml2_conf.ini
backup_cfg_file /etc/neutron/plugins/linuxbridge/linuxbridge_conf.ini

neutron-cfg DEFAULT core_plugin neutron.plugins.ml2.plugin.Ml2Plugin
neutron-cfg DEFAULT service_plugins neutron.services.l3_router.l3_router_plugin.L3RouterPlugin
neutron-cfg DEFAULT root_helper sudo neutron-rootwrap /etc/neutron/rootwrap.conf
neutron-cfg DEFAULT rpc_backend neutron.openstack.common.rpc.impl_qpid
neutron-cfg DEFAULT qpid_hostname $OS_CTL_IP
neutron-cfg DEFAULT auth_strategy keystone
neutron-cfg keystone_authtoken auth_host $OS_CTL_IP
neutron-cfg keystone_authtoken admin_tenant_name service
neutron-cfg keystone_authtoken admin_user neutron
neutron-cfg keystone_authtoken admin_password $OS_NEUTRON_PW
neutron-cfg securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

N_meta-cfg DEFAULT auth_url http://$OS_CTL_IP:5000/v2.0
N_meta-cfg DEFAULT auth_region Region1
N_meta-cfg DEFAULT admin_tenant_name service
N_meta-cfg DEFAULT admin_user neutron
N_meta-cfg DEFAULT admin_password $OS_NEUTRON_PW
N_meta-cfg DEFAULT metadata_proxy_shared_secret 1234567890

N_dhcp-cfg DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
N_dhcp-cfg DEFAULT auth_url http://$OS_CTL_IP:5000/v2.0
N_dhcp-cfg DEFAULT admin_tenant_name service
N_dhcp-cfg DEFAULT admin_user neutron
N_dhcp-cfg DEFAULT admin_password $OS_NEUTRON_PW

N_l3-cfg DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
N_l3-cfg DEFAULT external_network_bridge ""
N_l3-cfg DEFAULT auth_url http://$OS_CTL_IP:5000/v2.0
N_l3-cfg DEFAULT admin_tenant_name service
N_l3-cfg DEFAULT admin_user neutron
N_l3-cfg DEFAULT admin_password $OS_NEUTRON_PW

N_ml2-cfg ml2 type_drivers vlan
N_ml2-cfg ml2 tenant_network_types vlan
N_ml2-cfg ml2 mechanism_drivers linuxbridge
N_ml2-cfg ml2_type_vlan network_vlan_ranges physnet:$OS_NET_VLANS
N_ml2-cfg database sql_connection mysql://neutron:$pw@$OS_CTL_IP/neutron

N_lb-cfg linux_bridge physical_interface_mappings physnet:$OS_DATA_IF

if [ ! -L /etc/neutron/plugin.ini ]; then
    ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fi

chkconfig neutron-server on
chkconfig neutron-metadata-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-l3-agent on
chkconfig neutron-linuxbridge-agent on

service neutron-server start
service neutron-metadata-agent start
service neutron-dhcp-agent start
service neutron-l3-agent start
service neutron-linuxbridge-agent start
}

##
## Install OpenStack Nova
##
install_nova()
{
local pw=$(hexdump -e '"%x"' -n 5 /dev/urandom)

mysql -u root --password=$MYSQL_PW <<EOF
create database nova;
grant all on nova.* to nova@'%' identified by '$pw';
#grant all on nova.* to nova@localhost identified by '$pw';
flush privileges;
EOF

yum install -y openstack-nova openstack-nova-novncproxy
backup_cfg_file /etc/nova/nova.conf

service messagebus start
service libvirtd start

virsh net-destroy default
virsh net-undefine default

nova-cfg DEFAULT rpc_backend nova.openstack.common.rpc.impl_qpid
nova-cfg DEFAULT qpid_hostname $OS_CTL_IP
nova-cfg DEFAULT sql_connection mysql://nova:$pw@$OS_CTL_IP/nova
nova-cfg DEFAULT metadata_host $OS_CTL_IP
nova-cfg DEFAULT service_neutron_metadata_proxy true
nova-cfg DEFAULT neutron_metadata_proxy_shared_secret 1234567890

nova-cfg DEFAULT network_api_class nova.network.neutronv2.api.API
nova-cfg DEFAULT security_group_api neutron
nova-cfg DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
nova-cfg DEFAULT neutron_url http://$OS_CTL_IP:9696
nova-cfg DEFAULT neutron_auth_strategy keystone
nova-cfg DEFAULT neutron_admin_auth_url http://$OS_CTL_IP:5000/v2.0
nova-cfg DEFAULT neutron_admin_tenant_name service
nova-cfg DEFAULT neutron_admin_username neutron
nova-cfg DEFAULT neutron_admin_password $OS_NEUTRON_PW

nova-cfg DEFAULT auth_strategy keystone
nova-cfg keystone_authtoken auth_host $OS_CTL_IP
nova-cfg keystone_authtoken admin_tenant_name service
nova-cfg keystone_authtoken admin_user nova
nova-cfg keystone_authtoken admin_password $OS_NOVA_PW

nova-manage db sync

chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-consoleauth on
chkconfig openstack-nova-novncproxy on
chkconfig openstack-nova-scheduler on

service openstack-nova-api start
service openstack-nova-cert start
service openstack-nova-conductor start
service openstack-nova-consoleauth start
service openstack-nova-novncproxy start
service openstack-nova-scheduler start
}

##
## Setup nova-compute
##
install_compute()
{
if [ ! -c /dev/kvm ]; then
    nova-cfg DEFAULT libvirt_type qemu
fi

nova-cfg DEFAULT glance_host $OS_CTL_IP

nova-cfg DEFAULT vncserver_listen $OS_CTL_IP
nova-cfg DEFAULT vncserver_proxyclient_address $OS_CTL_IP
nova-cfg DEFAULT novncproxy_base_url http://$OS_CTL_IP:6080/vnc_auto.html

chkconfig openstack-nova-compute on
service openstack-nova-compute start
}

##
## Install OpenStack Horizon
##
install_horizon()
{
yum install -y openstack-dashboard

chkconfig httpd on
service httpd start
}

if [ $# != 2 ]; then
    usage
fi

source $1

OS_CTL_IF=${OS_CTL_IF:-eth0}
OS_DATA_IF=${OS_DATA_IF:-eth1}
OS_ISCSI_IF=${OS_ISCSI_IF:-eth0}
OS_ISCSI_VG=${OS_ISCSI_VG:-cinder-volumes}
OS_NET_VLANS=${OS_NET_VLANS:-100:199}

MYSQL_PW=${MYSQL_PW:-admin}
OS_ADMIN_PW=${OS_ADMIN_PW:-admin}
OS_GLANCE_PW=${OS_GLANCE_PW:-glance}
OS_CINDER_PW=${OS_CINDER_PW:-cinder}
OS_NEUTRON_PW=${OS_NEUTRON_PW:-neutron}
OS_NOVA_PW=${OS_NOVA_PW:-nova}

OS_CTL_IP=$(ip addr show dev $OS_CTL_IF | awk '/inet / {split($2, a, "/"); print a[1]}')
OS_ISCSI_IP=$(ip addr show dev $OS_ISCSI_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

case $2 in
mysql)
    install_mysql
    ;;

qpid)
    install_qpid
    ;;

utils)
    yum install -y openstack-utils
    ;;

keystone)
    install_keystone
    ;;

glance)
    install_glance
    ;;

cinder)
    install_cinder
    ;;

neutron)
    install_neutron
    ;;

nova)
    install_nova
    ;;

horizon)
    install_horizon
    ;;

compute)
    install_compute
    ;;

*)
    usage
    ;;
esac

##+++ POSTINST +++
## http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
##
## neutron net-create ext --shared --provider:network_type flat \
##      --provider:physical_network physext --router:external=True
##=== POSTINST ===
