#!/usr/bin/env bash

#
# load params for build-args from cmd line args like: this-script.sh key1=val1 key2=val2
for _ARG in "$@"
do
   echo "parsing _ARG: ${_ARG}"
   eval $_ARG
done

set -eux

# grub
sed -i '/^GRUB_CMDLINE_LINUX=/c GRUB_CMDLINE_LINUX="biosdevname=0 net.ifnames=0"' /etc/default/grub
update-grub2
