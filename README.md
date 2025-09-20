# qemu/virt vm ops to build / use / manage

- reference
   - https://libvirt.org/
   - https://libvirt.org/apps.html
   - https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html-single/configuring_and_managing_virtualization/index
   - debian qcow2 images: https://cloud.debian.org/images/cloud/
      - https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2
      - https://cloud.debian.org/images/cloud/trixie/latest/debian-13-nocloud-amd64.qcow2
- Makefile to make ops easy.
- base VM image is debian-12, defined in Makefile

## install packages and prepare for qemu/virt

```bash
sudo apt install -y virt-manager qemu-system  osinfo-db-tools guestfs-tools bridge-utils
sudo osinfo-db-import --local --latest
sudo usermod -aG kvm,libvirt,libvirt-qemu USER
```

## setup network on host

```bash
# enable bridging, just like docker needs.
sudo iptables -I FORWARD -m physdev --physdev-is-bridged -j ACCEPT
# to disable bridging, just like docker needs.
# sudo iptables -D FORWARD -m physdev --physdev-is-bridged -j ACCEPT

# to persist the above, use iptables-save or alternatives.
# for debian,  apt install iptables-persistent ; netfilter-persistant save
```

## basic ops

```bash
# build vm image  choices:   1st: static IP(assign in Makefile, according nic), or 2nd: dhcp
make build
make build guest_ip_mode=dhcp

# install vm  choices:   1st: bridge mode,  2nd: NAT mode
make install-vm
make install-vm-nat

# start/shutdown
make start-vm
make shutdown-vm

# unload/load
make unload-vm
make load-vm

#purge
make purge-vm
```

## others:

```bash
# clone vm00 => vm01
make clone-vm base=vm00 n=1

# start vm01
make start-vm(-nat) n=1
```

## and more...

refer in Makefile itself.

## hasks for NAT mode x port forwarding

references:
- https://wiki.libvirt.org/Networking.html#forwarding-incoming-connections
- https://github.com/libvirt/libvirt/blob/master/docs/hooks.rst
- https://redj.hatenablog.com/entry/2019/02/18/025503
- those say: guest VM needs to have static IP, static VM-name to specify port fowarding rule. orz

refer hooks folder in this repo for the sample of /etc/libvirt/hooks/qemu(python) with its external port forwarding rule(yaml).

```bash
# first check IP/Network on virbr0
ifconfig virbr0
# build and install VM image for static address and NAT mode.
make build install-vm-nat  guest_ip_mode=static address=192.168.122.2/24 gateway=192.168.122.1 nameservers=192.168.122.1 mac=08:00:27:00:00:00 vName=vm00
make start-vm vName=vm00

# deploy port-forwaring rule to /etc/libvirt/hooks/qemu.
# check log
systemctl status libvirtd.service
```

## increase/resize filesystem.partition of VM (qcow2).

- check current size and partition @ inside VM

```bash
sudo df -h
sudo fdisk -l
sudo shutdown -h now
```

- check and resize qcow2 @ VM host

```bash
n=0
# check current size of qcow2
qemu-img info   -f qcow2 vm0${n}.qcow2

# increase size for qcow2.
s=30
qemu-img resize -f qcow2 vm0${n}.qcow2 +${s}G
# start vm
```

- resize partition @ inside VM

```bash
# check current partition size:
sudo fdisk -l

# to resize partion /dev/vda1
sudo growpart /dev/vda 1

# check new partition size:
sudo fdisk -l

# reboot and continue more...
sudo shutdown -r now
```

- resize filesystem  @ inside VM

```bash
# to resize filesystem /dev/vda1
sudo /sbin/resize2fs /dev/vda1
```
