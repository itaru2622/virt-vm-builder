# qemu/virt vm ops to build / use / manage

- reference
   - https://libvirt.org/
   - https://libvirt.org/apps.html
   - https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/8/html-single/configuring_and_managing_virtualization/index
- Makefile to make ops easy.
- base VM image is debian-12, defined in Makefile

## install packages for qemu/virt

```bash
sudo apt install -y virt-manager qemu-system  osinfo-db-tools guestfs-tools bridge-utils
``` 

## basic ops

```bash
# build vm image  choices:   1st: static IP(assign in Makefile), or 2nd: dhcp
make build
make build guest_ip_mode=dhcp

# install vm  choices:   1st: bridge mode,  2nd: NAT mode
make install-vm
make install-vm-nat

# start/shutdown vm00
make start-vm
make shutdown-vm

# unload/load vm00
make unload-vm
make load-vm

#purge vm00
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
