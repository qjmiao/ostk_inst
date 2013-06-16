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
## pvcreate /dev/sdc
## vgcreate cinder-volumes /dev/sdc
##=== PREINST ===

OS_MY_IF=${OS_ADMIN_IF:-eth1}
OS_FLAT_IF=${OS_FLAT_IF:-eth2}
OS_MY_IP=$(ip addr show dev $OS_MY_IF | awk '/inet / {split($2, a, "/"); print a[1]}')

alias keystone-cfg="openstack-config --set /etc/keystone/keystone.conf"
alias glance-api-cfg="openstack-config --set /etc/glance/glance-api.conf"
alias glance-registry-cfg="openstack-config --set /etc/glance/glance-registry.conf"
alias cinder-cfg="openstack-config --set /etc/cinder/cinder.conf"
alias nova-cfg="openstack-config --set /etc/nova/nova.conf"

export OS_SERVICE_TOKEN=1234567890
export OS_SERVICE_ENDPOINT=http://OS_MY_IP:35357/v2.0

##
## Install MySQL server
##
install_mysql()
{
yum install -y mysql-server

chkconfig mysqld on
service mysqld start

mysqladmin -u root password pass

mysql -u root --password=pass <<EOF
create database keystone;
grant all on keystone.* to 'keystone'@'%' identified by 'pass';
grant all on keystone.* to 'keystone'@'localhost' identified by 'pass';
EOF

mysql -u root --password=pass <<EOF
create database glance;
grant all on glance.* to 'glance'@'%' identified by 'pass';
grant all on glance.* to 'glance'@'localhost' identified by 'pass';
EOF

mysql -u root --password=pass <<EOF
create database cinder;
grant all on cinder.* to 'cinder'@'%' identified by 'pass';
grant all on cinder.* to 'cinder'@'localhost' identified by 'pass';
EOF

mysql -u root --password=pass <<EOF
create database nova;
grant all on nova.* to 'nova'@'%' identified by 'pass';
grant all on nova.* to 'nova'@'localhost' identified by 'pass';
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
yum install openstack-keystone

keystone-cfg DEFAULT admin_token 1234567890
keystone-cfg sql connection mysql://keystone:pass@$OS_MY_IP/keystone

keystone-manage db_sync
keystone-manage pki_setup
chown -R keystone.keystone /etc/keystone/ssl

chkconfig openstack-keystone on
service openstack-keystone start

keystone user-create --name admin --pass pass
keystone user-create --name glance --pass pass
keystone user-create --name cinder --pass pass
keystone user-create --name nova --pass pass

keystone tenant-create --name admin
keystone tenant-create --name service

keystone role-create --name admin

keystone user-role-add --user admin --role admin --tenant admin
keystone user-role-add --user glance --role admin --tenant service
keystone user-role-add --user cinder --role admin --tenant service
keystone user-role-add --user nova --role admin --tenant service

keystone service-create --name keystone --type identity --description "Identity Service"
keystone service-create --name glance   --type image    --description "Image Service"
keystone service-create --name cinder   --type volume   --description "Volume Service"
keystone service-create --name nova     --type compute  --description "Compute Service"

KEYSTONE_SID=$(keystone service-list | awk '/keystone/ {print $2}')
GLANCE_SID=$(keystone service-list | awk '/glance/ {print $2}')
CINDER_SID=$(keystone service-list | awk '/cinder/ {print $2}')
NOVA_SID=$(keystone service-list | awk '/nova/ {print $2}')

keystone endpoint-create \
    --region Region1 --service-id $KEYSTONE_SID \
    --publicurl http://$OS_MY_IP:5000/v2.0 \
    --internalurl http://$OS_MY_IP:5000/v2.0 \
    --adminurl http://$OS_MY_IP:35357/v2.0

keystone endpoint-create \
    --region Region1 --service-id $GLANCE_SID \
    --publicurl http://$OS_MY_IP:9292 \
    --internalurl http://$OS_MY_IP:9292 \
    --adminurl http://$OS_MY_IP:9292

keystone endpoint-create \
    --region Region1 --service-id $CINDER_SID \
    --publicurl http://$OS_MY_IP:8776/v1/$\(tenant_id\)s \
    --internalurl http://$OS_MY_IP:8776/v1/$\(tenant_id\)s \
    --adminurl http://$OS_MY_IP:8776/v1/$\(tenant_id\)s

keystone endpoint-create \
    --region Region1 --service-id $NOVA_SID \
    --publicurl http://$OS_MY_IP:8774/v2/$\(tenant_id\)s \
    --internalurl http://$OS_MY_IP:8774/v2/$\(tenant_id\)s \
    --adminurl http://$OS_MY_IP:8774/v2/$\(tenant_id\)s
}

##
## Install OpenStack Glance
##
install_glance()
{
yum install -y openstack-glance

glance-api-cfg DEFAULT sql_connection mysql://glance:pass@$OS_MY_IP/glance
glance-api-cfg keystone_authtoken auth_host $OS_MY_IP
glance-api-cfg keystone_authtoken admin_tenant_name service
glance-api-cfg keystone_authtoken admin_user glance
glance-api-cfg keystone_authtoken admin_password pass
glance-api-cfg paste_deploy flavor keystone

glance-registry-cfg DEFAULT sql_connection mysql://glance:pass@$OS_MY_IP/glance
glance-registry-cfg keystone_authtoken auth_host $OS_MY_IP
glance-registry-cfg keystone_authtoken admin_tenant_name service
glance-registry-cfg keystone_authtoken admin_user glance
glance-registry-cfg keystone_authtoken admin_password pass
glance-registry-cfg paste_deploy flavor keystone

glance-manage db_sync

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
yum install -y openstack-cinder

cinder-cfg DEFAULT iscsi_ip_address $OS_MY_IP
cinder-cfg DEFAULT sql_connection mysql://cinder:pass@$OS_MY_IP/cinder
cinder-cfg DEFAULT auth_strategy keystone
cinder-cfg keystone_authtoken auth_host $OS_MY_IP
cinder-cfg keystone_authtoken admin_tenant_name service
cinder-cfg keystone_authtoken admin_user cinder
cinder-cfg keystone_authtoken admin_password pass

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
## Install OpenStack Nova
##
install_nova()
{
yum install -y openstack-nova openstack-nova-novncproxy

service messagebus start
service libvirtd start

virsh net-destroy default
virsh net-undefine default

nova-cfg DEFAULT force_dhcp_release False
nova-cfg DEFAULT sql_connection mysql://nova:pass@$OS_MY_IP/nova
nova-cfg DEFAULT flat_interface eth2
nova-cfg DEFAULT metadata_host $OS_MY_IP
nova-cfg DEFAULT auth_strategy keystone

nova-cfg keystone_authtoken auth_host $OS_MY_IP
nova-cfg keystone_authtoken admin_tenant_name service
nova-cfg keystone_authtoken admin_user nova
nova-cfg keystone_authtoken admin_password pass

nova-manage db sync

chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-consoleauth on
chkconfig openstack-nova-network on
chkconfig openstack-nova-novncproxy on
chkconfig openstack-nova-scheduler on

service openstack-nova-api start
service openstack-nova-cert start
service openstack-nova-conductor start
service openstack-nova-consoleauth start
service openstack-nova-network start
service openstack-nova-novncproxy start
service openstack-nova-scheduler start
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

##+++ POSTINST +++
## export OS_TENANT_NAME=admin
## export OS_USERNAME=admin
## export OS_PASSWORD=pass
## export OS_AUTH_URL=http://$OS_MY_IP:35357/v2.0
##
## nova flavor-create --is-public 1 m1.pico 6 128 0 1
##
## nova network-create --fixed-range-v4 10.10.10.0/24 --gateway 10.10.10.1 --bridge br100 --dns1 8.8.8.8 net1
##
## http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-disk.img
##=== POSTINST ===
