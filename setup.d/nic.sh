#!/usr/bin/env bash

# required args:  mode(static/dhp) address gateway  nameservers, and prefix
#
# load params for build-args from cmd line args like: this-script.sh key1=val1 key2=val2
for _ARG in "$@"
do
   echo "parsing _ARG: ${_ARG}"
   eval $_ARG
done

set -eux

# NIC
sed -i '/ens/d' ${prefix}/etc/network/interfaces
sed -i 's#^source /etc/network/.*#source /etc/network/interfaces.d/*.enable#' ${prefix}/etc/network/interfaces

tee ${prefix}/etc/network/interfaces.d/eth0.dhcp <<EOS
allow-hotplug eth0
iface eth0 inet dhcp
EOS

tee ${prefix}/etc/network/interfaces.d/eth0.static <<EOS
allow-hotplug eth0
iface eth0 inet static
  address   ${address}
  gateway   ${gateway}
  dns-nameservers ${nameservers}
EOS

(cd ${prefix}/etc/network/interfaces.d; ln -sf eth0.${mode} eth0.enable )

