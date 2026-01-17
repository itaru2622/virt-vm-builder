#!/usr/bin/env bash

# required args: uid  uname passwd
#
# load params for build-args from cmd line args like: this-script.sh key1=val1 key2=val2
for _ARG in "$@"
do
   echo "parsing _ARG: ${_ARG}"
   eval $_ARG
done

set -eux

addgroup --system --gid ${uid} ${uname}
adduser  --system --gid ${uid} --uid ${uid} --shell /bin/bash --home /home/${uname} ${uname}
echo "${uname}:${passwd}" | chpasswd
(cd /etc/skel; find . -type f -print | tar cf - -T - | tar xvf - -C/home/${uname} ) ; \
echo "set mouse-=a" > /home/${uname}/.vimrc
echo "escape ^t^t"  > /home/${uname}/.screenrc

echo '
# ----------
if [ -d ${HOME}/profile.d ]; then
  for i in ${HOME}/profile.d/*.sh; do
    if [ -r $i ]; then
      . $i
    fi
  done
  unset i
fi' >> /home/${uname}/.bashrc

# sudo config
mkdir -p /etc/sudoers.d
tee /etc/sudoers.d/local-admin <<EOS
Defaults env_keep="http_proxy"
Defaults env_keep+="https_proxy"
Defaults env_keep+="no_proxy"

${uname} ALL=(ALL) NOPASSWD: ALL
EOS
chmod 600 /etc/sudoers.d/local-admin

# set owner
chown -R ${uname}:${uname} /home/${uname}
