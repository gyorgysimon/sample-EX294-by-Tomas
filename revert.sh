#!/bin/bash

export LIBVIRT_DEFAULT_URI="qemu:///system"
PREFIX=EX294
#echo "remove hosts fingerprint"
for ip in 35 36 37 38
do
  ssh-keygen -R 10.9.0.$ip
done

for host in ansible2 ansible2.hl.local ansible3 ansible3.hl.local ansible4 ansible4.hl.local ansible5 ansible5.hl.local
do
	ssh-keygen -R $host
done

#echo "destroying vms"
for host in ${PREFIX}-ansible2 ${PREFIX}-ansible3 ${PREFIX}-ansible4 ${PREFIX}-ansible5 
do
  virsh destroy $host
  virsh undefine $host
done

#echo "destroying pool"
virsh pool-destroy ${PREFIX}-images
virsh pool-undefine ${PREFIX}-images

#echo "destroying network"
virsh net-destroy ${PREFIX}-network
virsh net-undefine ${PREFIX}-network

#echo "removing dir"
sudo rm -fr /home/kvm/${PREFIX}

