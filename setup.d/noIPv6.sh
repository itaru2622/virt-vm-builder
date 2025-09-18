#!/usr/bin/env bash

# required args:
#
# load params for build-args from cmd line args like: this-script.sh key1=val1 key2=val2
for _ARG in "$@"
do
   echo "parsing _ARG: ${_ARG}"
   eval $_ARG
done

set -eux

tee -a  /etc/sysctl.conf <<EOS
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOS
