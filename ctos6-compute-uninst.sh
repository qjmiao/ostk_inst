#!/bin/bash
set -e
set -u

usage() {
    cat <<EOF
Usage: $(basename $0) <all|nova|neutron>
EOF

    exit 1
}

remove_nova() {
    yum remove -y openstack-nova-common
    rm -rf /etc/nova
    rm -rf /var/{log,lib,run}/nova
}

remove_neutron() {
    yum remove -y openstack-neutron
    rm -rf /etc/neutron
    rm -rf /var/{log,lib,run}/neutron
}

if [ $# != 1 ]; then
    usage
fi

case $1 in
all)
    remove_neutron
    remove_nova
    ;;

nova)
    remove_nova
    ;;

neutron)
    remove_neutron
    ;;

*)
    usage
    ;;
esac
