#!/bin/bash
set -e
set -u

MYSQL_PW=${MYSQL_PW:-admin}

usage() {
    echo "Usage: $(basename $0) [WHAT]"

    exit 1
}

remove_horizon() {
    yum remove -y --remove-leaves openstack-dashboard
    rm -rf /etc/openstack-dashboard
}

remove_nova() {
    yum remove -y --remove-leaves openstack-nova openstack-nova-novncproxy
    rm -rf /etc/nova
    rm -rf /var/{log,lib,run}/nova

    mysql -u root --password=$MYSQL_PW <<EOF
#drop user nova@localhost;
drop user nova@'%';
drop database nova;
EOF
}

remove_neutron() {
    yum remove -y --remove-leaves openstack-neutron-ml2 openstack-neutron-linuxbridge openstack-neutron-openvswitch
    rm -rf /etc/neutron
    rm -rf /var/{log,lib,run}/neutron

    mysql -u root --password=$MYSQL_PW <<EOF
#drop user neutron@localhost;
drop user neutron@'%';
drop database neutron;
EOF
}

remove_cinder() {
    yum remove -y --remove-leaves openstack-cinder
    rm -rf /etc/cinder
    rm -rf /var/{log,lib,run}/cinder

    mysql -u root --password=$MYSQL_PW <<EOF
#drop user cinder@localhost;
drop user cinder@'%';
drop database cinder;
EOF
}

remove_glance() {
    yum remove -y --remove-leaves openstack-glance
    rm -rf /etc/glance
    rm -rf /var/{log,lib,run}/glance

    mysql -u root --password=$MYSQL_PW <<EOF
#drop user glance@localhost;
drop user glance@'%';
drop database glance;
EOF
}

remove_keystone() {
    yum remove -y --remove-leaves openstack-keystone
    rm -rf /etc/keystone
    rm -rf /var/{log,lib,run}/keystone

    mysql -u root --password=$MYSQL_PW <<EOF
#drop user keystone@localhost;
drop user keystone@'%';
drop database keystone;
EOF
}

if [ $# != 1 ]; then
    usage
fi

case $1 in
horizon)
    remove_horizon
    ;;

nova)
    remove_nova
    ;;

neutron)
    remove_neutron
    ;;

cinder)
    remove_cinder
    ;;

glance)
    remove_glance
    ;;

keystone)
    remove_keystone
    ;;

*)
    usage
    ;;
esac
