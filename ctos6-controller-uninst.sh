#!/bin/bash
set -e
set -u

MYSQL_PW=${MYSQL_PW:-pass}

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

    mysql -u root --password=$MYSQL_PW <<EOF
drop user nova@localhost;
drop user nova@'%';
drop database nova;
EOF
}

remove_quantum() {
    yum remove -y --remove-leaves openstack-quantum-linuxbridge
    rm -rf /etc/quantum

    mysql -u root --password=$MYSQL_PW <<EOF
drop user quantum@localhost;
drop user quantum@'%';
drop database quantum;
EOF
}

remove_cinder() {
    yum remove -y --remove-leaves openstack-cinder
    rm -rf /etc/cinder

    mysql -u root --password=$MYSQL_PW <<EOF
drop user cinder@localhost;
drop user cinder@'%';
drop database cinder;
EOF
}

remove_glance() {
    yum remove -y --remove-leaves openstack-glance
    rm -rf /etc/glance

    mysql -u root --password=$MYSQL_PW <<EOF
drop user glance@localhost;
drop user glance@'%';
drop database glance;
EOF
}

remove_keystone() {
    yum remove -y --remove-leaves openstack-keystone
    rm -rf /etc/keystone

    mysql -u root --password=$MYSQL_PW <<EOF
drop user keystone@localhost;
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

quantum)
    remove_quantum
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
