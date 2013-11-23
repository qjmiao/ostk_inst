#!/bin/bash
set -e
set -u

usage() {
    cat <<EOF
Usage: $(basename $0) <all|nova-compute|ovs-agent>
EOF

    exit 1
}

remove_nova-compute() {
    yum remove -y libvirt openstack-nova-common
    rm -rf /etc/libvirt
    rm -rf /var/{log,lib,run}/libvirt
    rm -rf /etc/nova
    rm -rf /var/{log,lib,run}/nova
}

remove_ovs-agent() {
    yum remove -y openvswitch openstack-neutron
    rm -rf /etc/openvswitch
    rm -rf /var/{log,lib,run}/openvswitch
    rm -rf /etc/neutron
    rm -rf /var/{log,lib,run}/neutron
}

if [ $# != 1 ]; then
    usage
fi

case $1 in
all)
    remove_ovs-agent
    remove_nova-compute
    ;;

nova-compute)
    remove_nova-compute
    ;;

ovs-agent)
    remove_ovs-agent
    ;;

*)
    usage
    ;;
esac
