#!/bin/bash
set -e
set -u

MYSQL_PW=${MYSQL_PW:-admin}

usage() {
    cat <<EOF
Usage: $(basename $0) <all|horizon|nova|neutron|cinder|glance|keystone>
EOF

    exit 1
}

remove_horizon() {
    yum remove -y openstack-dashboard
    rm -rf /etc/openstack-dashboard
}

remove_nova() {
    yum remove -y libvirt openstack-nova-common
    rm -rf /etc/libvirt
    rm -rf /var/{log,lib,run}/libvirt
    rm -rf /etc/nova
    rm -rf /var/{log,lib,run}/nova

    mysql -u root --password=$MYSQL_PW <<EOF
drop user nova@'%';
drop database nova;
EOF
}

remove_neutron() {
    yum remove -y openvswitch openstack-neutron
    rm -rf /etc/openvswitch
    rm -rf /var/{log,lib,run}/openvswitch
    rm -rf /etc/neutron
    rm -rf /var/{log,lib,run}/neutron

    mysql -u root --password=$MYSQL_PW <<EOF
drop user neutron@'%';
drop database neutron;
EOF
}

remove_cinder() {
    yum remove -y openstack-cinder
    rm -rf /etc/cinder
    rm -rf /var/{log,lib,run}/cinder

    mysql -u root --password=$MYSQL_PW <<EOF
drop user cinder@'%';
drop database cinder;
EOF
}

remove_glance() {
    yum remove -y openstack-glance
    rm -rf /etc/glance
    rm -rf /var/{log,lib,run}/glance

    mysql -u root --password=$MYSQL_PW <<EOF
drop user glance@'%';
drop database glance;
EOF
}

remove_keystone() {
    yum remove -y openstack-keystone
    rm -rf /etc/keystone
    rm -rf /var/{log,lib,run}/keystone

    mysql -u root --password=$MYSQL_PW <<EOF
drop user keystone@'%';
drop database keystone;
EOF
}

if [ $# != 1 ]; then
    usage
fi

case $1 in
all)
    remove_horizon
    remove_nova
    remove_neutron
    remove_cinder
    remove_glance
    remove_keystone
    ;;

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
