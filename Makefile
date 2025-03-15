# Makefile
wDir    ?=${PWD}

# NIC in host to use the same network address with guest, host, its neighbors.
nic  ?=br0

# distr:  controled term to select prebuild guest image,  one in `virt-builder -l`, used by virt-builder command
# osinfo: controled term to optimize the guest VM, one in `osinfo-query os`, used by virt-install command
distr   ?=debian-12
osinfo  ?=debian12
base    ?=debian12-base
vFormat ?=qcow2

# account in VM
rootPass ?=root
uID      ?=$(shell id -u)
uName    ?=$(shell id -u -n)
uPass    ?=${uName}

# default connection for libvirt
#conn ?=qemu:///session
conn  ?=qemu:///system

export
LIBVIRT_DEFAULT_URI=${conn}

#connOpt ?=--connect=${conn}
connOpt ?=

# params for guest VM
n   ?=0
mac ?=08:00:27:00:00:0${n}
cpu ?=1
mem ?=1024

vName       ?=vm0${n}
img         ?=${wDir}/${vName}.${vFormat}
conf        ?=${wDir}/${vName}.xml
mDir        ?=/mnt/virtfs/${vName}

# base number of last octet in guest_ip when assigning staticIP
guest_ip_starts ?= 90
# make NIC config for guest based on host
nameservers ?=$(shell cat /etc/resolv.conf | grep -v ^# | grep nameserver | awk '{print $$2}' | paste -sd " " - )
gateway     ?=$(shell ip route | grep " ${nic}"  | grep ^default  | awk '{print $$3}' )
address     ?=$(shell ip addr show ${nic} | grep ' inet ' | awk '{print $$2}' | awk -F '[./]' -v n=${n} -v b=${guest_ip_starts} 'BEGIN {OFS="."} {print $$1,$$2,$$3,b+n "/"$$5}')
guest_ip_mode ?=static
#guest_ip_mode ?=dhcp

pkgs_base    ?=ifupdown,openresolv,net-tools,openssh-server,vim,bash-completion,sudo,curl,keyboard-configuration
pkgs_extra   ?=locales-all,git,make,screen,inxi
pkgs         ?=${pkgs_base}


# build guest image from virt-builder-repository, such as libguestfs.org etc.
build: echo ${img}
${img}:
	virt-builder ${distr} -o ${img} --format ${vFormat} \
	--hostname ${vName} \
	--root-password password:${rootPass} \
	--install ${pkgs} \
	--uninstall inetutils-telnet,systemd-resolved \
	--upload ${wDir}/custom.sh:/tmp \
	--run-command "/tmp/custom.sh uid=${uID} uname=${uName} passwd=${uPass}" \
	--upload ${wDir}/custom-nic.sh:/tmp \
	--run-command "/tmp/custom-nic.sh prefix='' mode=${guest_ip_mode} address=${address} gateway=${gateway} nameservers=\"'${nameservers}'\" " \
	--delete /etc/resolv.conf  --delete /run/systemd/resolve/resolv.conf

# build guest image from qcow2 provided by https://cloud.debian.org/images/cloud/ etc.
#  first: curl -sL https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2 >  ${img}
rebuild: ${img}
	virt-customize -a ${img} \
	--hostname ${vName} \
	--root-password password:${rootPass} \
	--install ${pkgs} \
	--uninstall inetutils-telnet,systemd-resolved \
	--upload ${wDir}/custom.sh:/tmp \
	--run-command "/tmp/custom.sh uid=${uID} uname=${uName} passwd=${uPass}" \
	--upload ${wDir}/custom-nic.sh:/tmp \
	--run-command "/tmp/custom-nic.sh prefix='' mode=${guest_ip_mode} address=${address} gateway=${gateway} nameservers=\"'${nameservers}'\" " \
	--delete /etc/resolv.conf  --delete /run/systemd/resolve/resolv.conf

# list up supported os by virt-build
list-supported-os-for-build:
	virt-builder -l

# cf. https://qiita.com/nekakoshi/items/55fae55ab51163ea867c
install-vm: ${img}
	virt-install ${connOpt} \
	--disk path=${img} --name ${vName} --memory ${mem} --vcpu ${cpu} --network bridge=${nic},model=virtio,mac=${mac} \
	--osinfo ${osinfo}  \
	--noautoconsole  --noreboot \
	--boot hd \
	--import

#cf. https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-guest_virtual_machine_installation_overview-creating_guests_with_virt_install
#cf. https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/8/html-single/configuring_and_managing_virtualization/index#proc_booting-virtual-machines-using-pxe-and-a-virtual-network_assembly_booting-virtual-machines-from-a-pxe-server
# use NAT mode
install-vm-nat: ${img}
	virt-install ${connOpt} \
	--disk path=${img} --name ${vName} --memory ${mem} --vcpu ${cpu} --network network=default,model=virtio,mac=${mac} \
	--osinfo ${osinfo}  \
	--noautoconsole  --noreboot \
	--boot hd \
	--import


# clone VM, virt-clone can change mac but others. so configure cpu and memory in additional.
clone-vm::
	virt-clone --original ${base} --name ${vName} --mac ${mac} --file ${img}
	sudo chown ${uName}:${uName} ${img}
clone-vm:: config-vm-cpu config-vm-memory config-vm-nic show-vm-config


# configure cpu, memory, mac and nic(IP)
config-vm: config-vm-cpu config-vm-memory config-vm-mac config-vm-nic show-vm-config

# configure num of CPU for VM instance. set maximum and also assignment
# https://www.ibm.com/docs/en/linux-on-systems?topic=cpus-modifying-number-virtual
config-vm-cpu:
	-virsh ${connOpt} setvcpus ${vName} ${cpu} --config --maximum 
	-virsh ${connOpt} setvcpus ${vName} ${cpu} --config

# configure memory for VM instance. set maximum and also assignment
# https://www.ibm.com/docs/en/linux-on-systems?topic=resources-virtual-memory
config-vm-memory:
	-virsh ${connOpt} setmaxmem ${vName} ${mem}M --config
	-virsh ${connOpt} setmem    ${vName} ${mem}M --config

# configure mac for VM instance. it requires XML processing because virsh has no subcommand.
#   pick   by xmlstarlet:   cat dom.xml | xmlstarlet sel               -t -v '/domain/devices/interface[@type="bridge"]/source[@bridge="${nic}"]/../mac/@address' -nl
#   update by xmlstarlet:   cat dom.xml | xmlstarlet edit --inplace --update '/domain/devices/interface[@type="bridge"]/source[@bridge="${nic}"]/../mac/@address' --value "newMac"
# backup config into XML => updaye XML => reload(unload once)
config-vm-mac:: backup-vm-config
	# update MAC in XML
	xmlstarlet edit --inplace --update '/domain/devices/interface[@type="bridge"]/source[@bridge="${nic}"]/../mac/@address' --value "${mac}" ${conf}
config-vm-mac:: unload-vm load-vm

config-vm-nic:
	virt-customize -a ${img} \
	--hostname ${vName} \
	--upload ${wDir}/custom-nic.sh:/tmp \
	--run-command "/tmp/custom-nic.sh prefix='' mode=${guest_ip_mode} address=${address} gateway=${gateway} nameservers=\"'${nameservers}'\" "

# dump VM config into file(xml).
backup-vm-config:
	virsh ${connOpt} dumpxml ${vName} | tee ${conf}

# load VM config file into libvirt.
load-vm::
	virsh define ${conf}
load-vm:: list-vm

# print VM config in console.
show-vm-config:
	virsh ${connOpt} dominfo   ${vName}
	virsh ${connOpt} domiflist ${vName}
	virsh ${connOpt} vcpucount ${vName}

# list current VMs
list-vm:
	virsh ${connOpt} list --all

# start VM instance.
start-vm::
	-virsh ${connOpt} start ${vName}
start-vm:: list-vm

start-vm-auto::
	-virsh ${connOpt} autostart ${vName}
	-ls /etc/libvirt/qemu/autostart

# shutdown VM instance.
shutdown-vm::
	-virsh ${connOpt} shutdown ${vName} 
shutdown-vm:: list-vm

# unload VM from libvirt, but keep disk image
unload-vm:: shutdown-vm backup-vm-config
	-virsh ${connOpt} undefine ${vName}
unload-vm:: list-vm

# purge VM config from libvirt, remove disk image and config file.
purge-vm:: shutdown-vm
	-virsh ${connOpt} undefine ${vName} --remove-all-storage --wipe-storage
	-rm -f ${img} ${conf}
purge-vm:: list-vm

qcow2-mount-ro:
	mkdir -p ${mDir}
	guestmount -a ${img} -i --ro ${mDir}
qcow2-mount:
	mkdir -p ${mDir}
	guestmount -a ${img} -i ${mDir}
qcow2-unmount:
	guestunmount ${mDir}
	rmdir ${mDir}

echo:
	@echo "guest_ip:    ${address}"
	@echo "router_ip:   ${gateway}"
	@echo "nameservers: ${nameservers}"
	@echo "uID:         ${uID}"
	@echo "uName:       ${uName}"
