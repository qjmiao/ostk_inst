#!/bin/bash
set -e
set -u

if !(rpm -q epel-release); then
    yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
fi

if !(rpm -q rdo-release); then
    yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-grizzly/rdo-release-grizzly-3.noarch.rpm
fi

yum upgrade -y
