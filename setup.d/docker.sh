#!/usr/bin/env bash
# cat custom.sh

# required args: uid  uname passwd
#
# load params for build-args from cmd line args like: this-script.sh key1=val1 key2=val2
for _ARG in "$@"
do
   echo "parsing _ARG: ${_ARG}"
   eval $_ARG
done

set -eux

curl -L https://get.docker.com | sh 

usermod -aG docker ${uname}
