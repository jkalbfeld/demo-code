#!/bin/sh

yum -y install epel-release
yum -y install puppet

cat  > /etc/puppet/puppet.conf <<EOF
[main]
logdir = /var/log/puppet
rundir = /var/run/puppet
ssldir = /var/lib/puppet/ssl
server = provision.thoughtwave.net
pluginsync = true
[agent]
classfile = /var/lib/puppet/classes.txt
environment = dev
certname = website.thoughtwave.net
runinterval = 5m
localconfig = /var/lib/puppet/localconfig
EOF

puppet agent --test --waitforcert 60
