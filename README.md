# qemu/virt vm ops to build / use / manage

- reference
   - https://libvirt.org/
   - https://libvirt.org/apps.html
   - https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html-single/configuring_and_managing_virtualization/index
- Makefile to make ops easy.
- base VM image is debian-12, defined in Makefile

## install packages and prepare for qemu/virt

```bash
sudo apt install -y virt-manager qemu-system  osinfo-db-tools guestfs-tools bridge-utils
sudo osinfo-db-import --local --latest
sudo usermod -aG kvm,libvirt,libvirt-qemu USER
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

