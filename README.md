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
# build vm image  choices:   1st: static IP(assign in Makefile, according nic), or 2nd: dhcp
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

## hasks for NAT mode (port forwarding)

references:
- https://wiki.libvirt.org/Networking.html#forwarding-incoming-connections
- https://github.com/libvirt/libvirt/blob/master/docs/hooks.rst
- https://redj.hatenablog.com/entry/2019/02/18/025503
- those say: guest VM needs to have static IP, static VM-name to specify port fowarding rule. orz

```bash
# first check get IP/Network in virbr0
ifconfig virbr0
# build and install VM image for static address and NAT mode.
make build install-vm-nat  guest_ip_mode=static address=192.168.122.2/24 gateway=192.168.122.1 nameservers=192.168.122.1 mac=08:00:27:00:00:00 vName=myVMname
make start-vm vName=myVMname

# deploy port-forwaring rule to /etc/libvirt/hooks/qemu. when you involve 'echo hi' in script, you see it in log
# check log
systemctl status libvirtd.service
```

```yaml
# port-forwarding.yaml
#
myVMname:
  - bridge: virbr0
    vm_ip: 192.168.122.2
    forwardings:
      - vm_port: 22
        host_port: 22022
#     - vm_port: 80
#       host_port: 10080
vm00:
  - bridge: virbr0
    vm_ip: 192.168.122.3
    forwardings:
      - vm_port: 22
        host_port: 22023
```

```python
#!/usr/bin/env python3

# sample /etc/libvirt/hooks/qemu
import os
import os.path
import sys
import subprocess
import yaml

def run_command(command):
    cmd = command.split(' ')
    print(cmd, file=sys.stderr)
    subprocess.run(cmd)

def entries(entries):
    for entry in entries:
        yield (entry, entry["bridge"], entry["vm_ip"])

def forwardings(entry):
    for forwarding in entry["forwardings"]:
        yield ( str(forwarding["host_port"]),  str(forwarding["vm_port"]) )

def on_libvirt_hook(config, vm_name, operation, sub_operation, extra_argument):

    if vm_name not in config:
        return

    todo=['-D'] # iptable ops (-D or -I)
    if operation in ["start"]:
        todo=['-I']
    elif operation in ["stopped"]:
        todo=['-D']
    elif operation in ["reconnect"]:
        todo=['-D', '-I']
    else:
        return

    for op in todo:
       for entry, bridge, vm_ip in entries(config[vm_name]):
          for host_port, vm_port in forwardings(entry):
               run_command(f"/sbin/iptables {op} FORWARD -o {bridge} -p tcp -d {vm_ip} --dport {vm_port} -j ACCEPT")
               run_command(f"/sbin/iptables -t nat {op} PREROUTING   -p tcp --dport {host_port} -j DNAT --to {vm_ip}:{vm_port}")

if __name__ == '__main__':
    config_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "port-forwarding.yaml")
    with open(config_file) as f:
        config = yaml.load(f, Loader=yaml.SafeLoader)

    if config in [None, {}]:
       exit(0)
    on_libvirt_hook(config, sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
```
