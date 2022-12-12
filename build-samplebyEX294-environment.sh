#!/usr/bin/env bash
###############################################################
#                       Readme.md                             #
#                                                             #
#     This script has been createed to prepare the same       #
#        for all those, who are trying to complete            #
#               practise exam for RHCE v8.0                   #
#                   prepared for RHEL 7                       #
###############################################################
#set -x

#variables
export LIBVIRT_DEFAULT_URI="qemu:///system"
declare -A HOSTS

HOSTS["ansible2"]="52:54:00:5d:e1:35"
HOSTS["ansible3"]="52:54:00:5d:e1:36"
HOSTS["ansible4"]="52:54:00:5d:e1:37"
HOSTS["ansible5"]="52:54:00:5d:e1:38"
VM_W_EXTRA_DISK=(ansible5)
EXTRA_DISK_SIZE="1G"
VM_W_DVD_IMG=(ansible2 ansible3 ansible4 ansible5)
PREFIX="EX294"

DOMAIN="hl.local"
VMROOT="/home/kvm/"
POOL_DIR="$VMROOT/$PREFIX/virtualdiskpool"
BASE_IMG_FILE="rhel-8.1-update-3-x86_64-kvm.qcow2"
DVD_ISO_FILE="rhel-8.1-x86_64-dvd.iso"
ROOTPWD="password"
SM_POOL="8a85f99b70399fb4017043e872817b1a"
DISK_POOL="${PREFIX}-images"
NET_POOL="${PREFIX}-network"
BACKING_IMAGE=$POOL_DIR/$BASE_IMG_FILE

# set up a variable for the host OS
VERSION=$(uname -r|awk -F'.' '{print $6}')
case $VERSION
in
	el7) 
		VOS="rhel8-unknown"  # for RHEL7
		;;
	*)
		VOS=rhel8.1 # for RHEL8
		;;
esac

# check if VMROOT directory is exists or need to create
[[ ! -d "$VMROOT" ]] && sudo mkdir $VMROOT
# check if PREFIX dir exists
[[ ! -d $VMROOT/$PREFIX ]] && sudo mkdir -p $VMROOT/$PREFIX

#setup virtual network
virsh net-define --file ./${PREFIX}-network.xml
virsh net-autostart --network $NET_POOL
virsh net-start --network $NET_POOL

#setup virtual disk pool
virsh pool-define-as $DISK_POOL dir - - - - $POOL_DIR
virsh pool-build $DISK_POOL
virsh pool-autostart $DISK_POOL
virsh pool-start $DISK_POOL

#move base image into the pool directory
echo "Uploading base OS (RHEL 8.1) image into the storage pool..."
virsh vol-create-as $DISK_POOL $BASE_IMG_FILE --prealloc-metadata --format qcow2 1G
virsh vol-upload --vol $BASE_IMG_FILE --file $BASE_IMG_FILE --pool $DISK_POOL 

#create virtual disk images
for i in ${!HOSTS[@]}
do
	IMAGE=${i}_vda_rhel8.1-x86_64-kvm.qcow2
	virsh vol-create-as $DISK_POOL $IMAGE --format qcow2 --backing-vol ${BACKING_IMAGE} --backing-vol-format qcow2 8G
done

# install new vms
for name in ${!HOSTS[@]}
do
	IMAGE=${DISK_POOL}/${name}_vda_rhel8.1-x86_64-kvm.qcow2
	DOMNAME=${PREFIX}-$name
	VIRTINSTALL="virt-install --name ${DOMNAME} --memory 1536 --vcpus 2 --import --os-variant $VOS --boot hd --noreboot"
	case $VERSION in
		el7)
			# virt-install in EL7 has bus option in --disk section, and mac option in --network section
			VIRTINSTALL=${VIRTINSTALL}" --disk vol=${IMAGE},size=20,format=qcow2,bus=virtio --network network=${NET_POOL},model=virtio,mac=${HOSTS[${name}]}"
			;;
			# newer version of virt-install has target.bus in --disk section and mac.address option in --network section
		*)
			# dvd image attach at define time --cdrom $(pwd)/$DVD_ISO_FILE
			VIRTINSTALL=${VIRTINSTALL}" --disk vol=${IMAGE},size=20,format=qcow2,target.bus=virtio --network network=${NET_POOL},model.type=virtio,mac.address=${HOSTS[${name}]} --install no_install=yes"
			;;
  esac
	VIRTINSTALL=${VIRTINSTALL}" --graphics none --noautoconsole"
	$VIRTINSTALL 2> /dev/null
  VMS+=($DOMNAME)
done
### end of pre_tasks

#add addition disk for $VM_W_EXTRA_DISK
for domname in ${VM_W_EXTRA_DISK[@]}
do
	virsh vol-create-as --name ${domname}-vdb.qcow2 --capacity $EXTRA_DISK_SIZE --format qcow2 --pool $DISK_POOL --prealloc-metadata
	virsh attach-disk --domain ${PREFIX}-${domname} --targetbus virtio --persistent --source ${POOL_DIR}/${domname}-vdb.qcow2 --target vdb
done

#add iso image 
for domname in ${VM_W_DVD_IMG[@]}
do
	case version in 
		el7) 
			virsh attach-disk --domain ${PREFIX}-${domname} --source $(pwd)/$DVD_ISO_FILE --target hda --type cdrom --mode readonly --persistent
		;;
		*)
			virsh attach-disk --domain ${PREFIX}-${domname} --source $(pwd)/$DVD_ISO_FILE --target hdc --type cdrom --targetbus sata --mode readonly --persistent
		;;
	esac
done

#start the vmsstart
for domname in ${VMS[@]}
do
	virsh start $domname
done

echo "We are ready to start. In the virt manager you can find all the vms with $PREFIX prefix"
virsh list --all|grep ${PREFIX}-

