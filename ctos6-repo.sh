#!/bin/bash
set -e
set -u

if !(rpm -q epel-release); then
    rpm -i http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
fi

if !(rpm -q rdo-release); then
    rpm -i http://repos.fedorapeople.org/repos/openstack/openstack-havana/rdo-release-havana-6.noarch.rpm
fi

yum update -y
