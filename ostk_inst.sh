#!/bin/bash
set -e
set -u

EXT_IP=$(ip addr show dev eth0 | awk '/inet / {split($2, a, "/"); print a[1]}')

################################################################################
## Add OpenStack Folsom package source
##
apt-get install -y ubuntu-cloud-keyring

cat > /etc/apt/sources.list.d/ostk.list <<EOF
deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/folsom main
EOF

apt-get update

################################################################################
## Install RabbitMQ
##
apt-get install -y rabbitmq-server

################################################################################
## Install Keystone
##
apt-get install -y keystone

export SERVICE_ENDPOINT=http://localhost:35357/v2.0
export SERVICE_TOKEN=ADMIN

keystone user-create --name admin   --pass 123
keystone user-create --name glance  --pass 123
keystone user-create --name nova    --pass 123
keystone user-create --name cinder  --pass 123
keystone user-create --name quantum --pass 123

keystone tenant-create --name admin
keystone tenant-create --name service

keystone role-create --name admin

## user-id
ADMIN_UID=$(keystone user-list | awk '/admin/ {print $2}')
GLANCE_UID=$(keystone user-list | awk '/glance/ {print $2}')
NOVA_UID=$(keystone user-list | awk '/nova/ {print $2}')
CINDER_UID=$(keystone user-list | awk '/cinder/ {print $2}')
QUANTUM_UID=$(keystone user-list | awk '/quantum/ {print $2}')

## tenant-id
ADMIN_TID=$(keystone tenant-list | awk '/admin/ {print $2}')
SERVICE_TID=$(keystone tenant-list | awk '/service/ {print $2}')

## role-id
ADMIN_RID=$(keystone role-list | awk '/admin/ {print $2}')

keystone user-role-add \
    --user-id $ADMIN_UID   --role-id $ADMIN_RID --tenant-id $ADMIN_TID

keystone user-role-add \
    --user-id $GLANCE_UID  --role-id $ADMIN_RID --tenant-id $SERVICE_TID

keystone user-role-add \
    --user-id $NOVA_UID    --role-id $ADMIN_RID --tenant-id $SERVICE_TID

keystone user-role-add \
    --user-id $CINDER_UID  --role-id $ADMIN_RID --tenant-id $SERVICE_TID

keystone user-role-add \
    --user-id $QUANTUM_UID --role-id $ADMIN_RID --tenant-id $SERVICE_TID

export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=123
export OS_AUTH_URL=http://localhost:35357/v2.0

keystone service-create \
    --name keystone --type identity --description 'OpenStack Identity Service'

keystone service-create \
    --name glance   --type image    --description 'OpenStack Image Service'

keystone service-create \
    --name nova     --type compute  --description 'OpenStack Compute Service'

keystone service-create \
    --name cinder   --type volume   --description 'OpenStack Volume Service'

keystone service-create \
    --name quantum  --type network  --description 'OpenStack Networking Service'

## service-id
KEYSTONE_SID=$(keystone service-list | awk '/keystone/ {print $2}')
GLANCE_SID=$(keystone service-list | awk '/glance/ {print $2}')
NOVA_SID=$(keystone service-list | awk '/nova/ {print $2}')
CINDER_SID=$(keystone service-list | awk '/cinder/ {print $2}')
QUANTUM_SID=$(keystone service-list | awk '/quantum/ {print $2}')

keystone endpoint-create \
    --region Region1 --service-id $KEYSTONE_SID \
    --publicurl 'http://localhost:5000/v2.0' \
    --internalurl 'http://localhost:5000/v2.0' \
    --adminurl 'http://localhost:35357/v2.0'

keystone endpoint-create \
    --region Region1 --service-id $GLANCE_SID \
    --publicurl 'http://localhost:9292' \
    --internalurl 'http://localhost:9292' \
    --adminurl 'http://localhost:9292'

keystone endpoint-create \
    --region Region1 --service-id $NOVA_SID \
    --publicurl 'http://localhost:8774/v2/$(tenant_id)s' \
    --internalurl 'http://localhost:8774/v2/$(tenant_id)s' \
    --adminurl 'http://localhost:8774/v2/$(tenant_id)s'

keystone endpoint-create \
    --region Region1 --service-id $CINDER_SID \
    --publicurl 'http://localhost:8776/v1/$(tenant_id)s' \
    --internalurl 'http://localhost:8776/v1/$(tenant_id)s' \
    --adminurl 'http://localhost:8776/v1/$(tenant_id)s'

keystone endpoint-create \
    --region Region1 --service-id $QUANTUM_SID \
    --publicurl 'http://localhost:9696' \
    --internalurl 'http://localhost:9696' \
    --adminurl 'http://localhost:9696'

################################################################################
## Install Glance
##
apt-get install -y glance

sed -i.orig \
    -e 's/%SERVICE_TENANT_NAME%/service/' -e 's/%SERVICE_USER%/glance/' \
    -e 's/%SERVICE_PASSWORD%/123/' /etc/glance/glance-api.conf

sed -i.orig \
    -e 's/%SERVICE_TENANT_NAME%/service/' -e 's/%SERVICE_USER%/glance/' \
    -e 's/%SERVICE_PASSWORD%/123/' /etc/glance/glance-registry.conf

service glance-api restart
service glance-registry restart

################################################################################
## Install Cinder
##
apt-get install -y lvm2 cinder-api cinder-volume cinder-scheduler

pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb

sed -i.orig \
    -e 's/%SERVICE_TENANT_NAME%/service/' -e 's/%SERVICE_USER%/cinder/' \
    -e 's/%SERVICE_PASSWORD%/123/' /etc/cinder/api-paste.ini

service cinder-api restart
service cinder-scheduler restart
service cinder-volume restart

################################################################################
## Install Quantum
##
apt-get install -y quantum-server quantum-plugin-openvswitch \
    quantum-plugin-openvswitch-agent quantum-dhcp-agent

sed -i.orig \
    -e 's/%SERVICE_TENANT_NAME%/service/' -e 's/%SERVICE_USER%/quantum/' \
    -e 's/%SERVICE_PASSWORD%/123/' /etc/quantum/api-paste.ini

patch -b /etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini <<EOF
--- ovs_quantum_plugin.ini.orig 2013-02-05 13:59:28.452664114 +0800
+++ ovs_quantum_plugin.ini      2013-02-06 10:20:28.707529223 +0800
@@ -22,6 +22,7 @@
 #
 # Default: tenant_network_type = local
 # Example: tenant_network_type = gre
+tenant_network_type = vlan

 # (ListOpt) Comma-separated list of
 # <physical_network>[:<vlan_min>:<vlan_max>] tuples enumerating ranges
@@ -33,6 +34,7 @@
 #
 # Default: network_vlan_ranges =
 # Example: network_vlan_ranges = physnet1:1000:2999
+network_vlan_ranges = default

 # (BoolOpt) Set to True in the server and the agents to enable support
 # for GRE networks. Requires kernel support for OVS patch ports and
@@ -75,6 +77,7 @@
 #
 # Default: bridge_mappings =
 # Example: bridge_mappings = physnet1:br-eth1
+bridge_mappings = default:br01

 [AGENT]
 # Agent's polling interval in seconds
EOF

service openvswitch-switch restart
ovs-vsctl add-br br-int
ovs-vsctl add-br br01

service quantum-server restart
service quantum-dhcp-agent restart
service quantum-plugin-openvswitch-agent restart

################################################################################
## Install Nova
##
apt-get install -y nova-api nova-cert nova-scheduler nova-consoleauth \
    nova-novncproxy novnc nova-compute nova-compute-qemu

sed -i.orig -e 's/%SERVICE_TENANT_NAME%/service/' -e 's/%SERVICE_USER%/nova/' \
    -e 's/%SERVICE_PASSWORD%/123/' /etc/nova/api-paste.ini

patch -b /etc/nova/nova.conf <<EOF
--- nova.conf.orig      2013-02-03 10:37:28.156071990 +0800
+++ nova.conf   2013-02-08 14:52:36.664601594 +0800
@@ -13,3 +13,18 @@
 ec2_private_dns_show_ip=True
 api_paste_config=/etc/nova/api-paste.ini
 volumes_path=/var/lib/nova/volumes
+
+debug=False
+auth_strategy=keystone
+enabled_apis=ec2,osapi_compute,metadata
+
+network_api_class=nova.network.quantumv2.api.API
+quantum_url=http://localhost:9696
+quantum_admin_auth_url=http://localhost:35357/v2.0
+quantum_admin_tenant_name=service
+quantum_admin_username=quantum
+quantum_admin_password=123
+linuxnet_interface_driver=nova.network.linux_net.LinuxOVSInterfaceDriver
+libvirt_vif_driver=nova.virt.libvirt.vif.LibvirtOpenVswitchVirtualPortDriver
+
+novncproxy_base_url=http://$EXT_IP:6080/vnc_auto.html
EOF

virsh net-destroy default
virsh net-undefine default

service nova-api restart
service nova-cert restart
service nova-compute restart
service nova-consoleauth restart
service nova-novncproxy restart
service nova-scheduler restart

################################################################################
## Install Horizon
##
apt-get install -y openstack-dashboard

horizon_dir=/usr/lib/python2.7/dist-packages/horizon

sed -i.orig 's/usage.quota/usage.quotas/g' \
    $horizon_dir/templates/horizon/common/_quota_summary.html

service memcached restart
service apache2 restart

################################################################################
## Setup networking
##
quantum net-create --tenant-id $ADMIN_TID net01 \
    --provider:network_type flat --provider:physical_network default

quantum subnet-create net01 192.168.200.0/24 \
    --dns_nameservers list=true 8.8.4.4 8.8.8.8

ifconfig br01 192.168.200.1

iptables -t nat -A PREROUTING -s 0.0.0.0/0 -d 169.254.169.254/32 \
    -p tcp --dport 80 -j DNAT --to-destination 192.168.200.1:8775

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

################################################################################
## cirros image
##
wget https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-i386-disk.img

glance image-create --name cirros --disk-format qcow2 --container-format bare \
    --is-public 1 < ./cirros-0.3.0-i386-disk.img
