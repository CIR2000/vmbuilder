#!/bin/bash
# DEFAULT VALUES
# vmstorage local
# isostorage /var/lib/vz/template/iso/
# snipstorage local
# snippetstorage /var/lib/vz/snippets/
# vmbr vmbr0

clear
echo "#############################################################################################"
echo "###"
echo "# Welcome to the Proxmox Virtual Machine Builder script that uses Cloud Images"
echo "# This will automate so much and make it so easy to spin up a VM machine from a cloud image."
echo "# A VM Machine typically will be spun up and ready in less then 3 minutes."
echo "#"
echo "# Written by Francis Munch"
echo "# email: francismunch@tuta.io"
echo "# github: https://github.com/francismunch/vmbuilder"
echo "###"
echo "#############################################################################################"
echo
echo
# Going to ask questions for VM number, hostname, vlan tag
echo
while true; do
   read -r -p "Enter desired hostname for the Virutal Machine: " NEWHOSTNAME
   if [[ ! $NEWHOSTNAME == *['!'@#\$%^\&*()\_+\']* ]];then
      break;
   else
      echo "Contains a character not allowed for a hostname, please try again"
   fi
done
echo
echo "*** Taking a 5-7 seconds to gather information ***"
echo
#Picking VM ID number
vmidnext=$(pvesh get /cluster/nextid)
declare -a vmidsavail=$(pvesh get /cluster/resources | awk '{print $2}' | sed '/storage/d' | sed '/node/d' | sed '/id/d' | sed '/./,/^$/!d' | cut -d '/' -f 2 | sed '/^$/d')

#echo ${vmidsavail[@]}

for ((i=1;i<=99;i++));
do
   systemids+=$(echo " " $i)
done

USEDIDS=("${vmidsavail[@]}" "${systemids[@]}")
declare -a all=( echo ${USEDIDS[@]} )

function get_vmidnumber() {
    read -p "${1} New VM ID number: " number
    if [[ " ${all[*]} " != *" ${number} "* ]]
    then
        VMID=${number:-$vmidnext}
    else
        get_vmidnumber 'Enter a different number because either you are using it or reserved by the sysem'
    fi
}
echo "Enter desired VM ID number or press enter to accept default of $vmidnext: "
get_vmidnumber ''

echo "The VM number will be $VMID"

echo
read -p "Enter desired VM username: " USER
echo
while true; do
    read -s -p "Please enter password for the user: " PASSWORD
    echo
    read -s -p "Please repeat password for the user: " PASSWORD1
    echo
    [ "$PASSWORD" = "$PASSWORD1" ] && break
    echo
    echo "Please try again passwords did not match"
    echo
done
echo
# really just hashing the password so its not in plain text in the usercloud.yaml
# that is being created during the process
# really should do keys for most secure
kindofsecure=$(openssl passwd -1 -salt SaltSalt $PASSWORD)

# set variable to default value
vmstorage=local
isostorage=/var/lib/vz/template/iso/
snipstorage=local
snippetstorage=/var/lib/vz/snippets/
vmbrused=vmbr0
# sshpassallow=True
sshpassallow=False
AUTOSTART=Y
PROTECTVM=N
# end set

 echo
 read -p "Enter number of cores for VM $VMID: " CORES
 echo
 read -p "Enter how much memory for the VM $VMID (example 2048 is 2Gb of memory): " MEMORY
echo
read -p "Enter DISK size in Gb's (example 20 is 2oGb of disk): " DISKSIZE
# This block is see if they want to add a key to the VM
# and then it checks the path to it and checks to make sure it exists
 while true; do
 echo
 read -p "Enter the path and key name (path/to/key.pub): " path_to_ssh_key
 echo
 [ -f "$path_to_ssh_key" ] && echo "It appears to be a good key path." && SSHAUTHKEYS=$(cat "$path_to_ssh_key") && break || echo && echo "Does not exist, try again please."
 done

echo
# This block of code is for picking which node to have the VM on.
# Couple things it creates the VM on the current node, then migrate's
# to the node you selected, so must have shared storage (at least for
# what I have tested or storages that are the same).  I run
# ceph on my cluster, so its easy to migrate them.
echo
echo "   PLEASE READ - THIS IS FOR PROXMOX CLUSTERS "
echo "   This will allow you to pick the Proxmox node for the VM to be on once it is completed "
echo "   BUT "
echo "   It will start on the proxmox node you are on and then it will use "
echo "   qm migrate to the target node (JUST FYI) "
echo


if [ -f "/etc/pve/corosync.conf" ];
then
localnode=$(cat '/etc/hostname')
while true
do
 read -p "Enter Yes/y to pick the node to install the virtual machine onto OR enter No/n to use current node of $localnode : " NODESYESNO

 case $NODESYESNO in
     [yY][eE][sS]|[yY])
 echo "Please select the NODE to migrate the Virtual Machine to after creation (current node $localnode)"
 nodesavailable=$(pvecm nodes | awk '{print $3}' | sed '/Name/d')
 nodesavailabe2=$(echo "${nodesavailable[@]}")
 declare -a NODESELECTION=( ${nodesavailabe2[@]} )
 total_num_nodes=${#NODESELECTION[@]}
 echo $total_num_nodes

 select option in $nodesavailabe2; do
 if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $total_num_nodes ];
 then
         migratenode=$option
         break;
 else
         echo "Incorrect Input: Select a number 1-$total_num_nodes"
 fi
 done

 echo
 echo "The Virtual Machine $VMID with be on $migratenode after it is created and moved"
 echo
 NODESYESNO=y
 break
 ;;
     [nN][oO]|[nN])
 NODESYESNO=n
 break
        ;;
     *)
 echo "Invalid input, please enter Y/n or yes/no"
 ;;
 esac
done
else
 NODESYESNO=n
fi

while true; do
    echo
    read -p "Enter IP address to use (format example 192.168.1.50/24): " IPADDRESS
    echo
    read -p "Please repeat IP address to use (format example 192.168.1.50/24): " IPADDRESS2
    echo
    if [[ $IPADDRESS != */32 ]];then
        echo
        echo "Please try again, subnet must be /32"
        echo
    else
        [ "$IPADDRESS" = "$IPADDRESS2" ] && break
        echo
        echo "Please try again IP addresses did not match"
        echo
    fi
done
echo
while true; do
    read -p "Enter gateway IP address to use (format example 192.168.1.1): " GATEWAY
    echo
    read -p "Please repeate gateway IP address to use (format example 192.168.1.1): " GATEWAY2
    echo
    if [[ $GATEWAY != *.254 ]];then
        echo
        echo "Please try again, gateway must terminate with .254"
        echo
    else
        [ "$GATEWAY" = "$GATEWAY2" ] && break
        echo
        echo "Please try again IP addresses did not match"
        echo
    fi
    echo
    echo "Please try again gateway IP addresses did not match"
    echo
done
while true; do
    read -p "Enter MAC address to use (format example xx.xx.xx.xx.xx.xx): " MACADDRESS
    echo
    read -p "Please repeate MAC address to use (format example xx.xx.xx.xx.xx.xx): " MACADDRESS2
    echo
    [ "$MACADDRESS" = "$MACADDRESS2" ] && break
    echo
    echo "Please try again gateway IP addresses did not match"
    echo
done

echo "Please select the cloud image you would like to use"
PS3='Select an option and press Enter: '
options=("Ubuntu Groovy 20.10 Cloud Image" "Ubuntu Focal 20.04 Cloud Image" "Ubuntu Minimal Focal 20.04 Cloud Image" "CentOS 7 Cloud Image" "Debian 10 Cloud Image" "Debian 9 Cloud Image" "Ubuntu 18.04 Bionic Image" "CentOS 8 Cloud Image" "Fedora 32 Cloud Image" "Rancher OS Cloud Image")
select osopt in "${options[@]}"
do
  case $osopt in
        "Ubuntu Groovy 20.10 Cloud Image")
          [ -f "$isostorage/groovy-server-cloudimg-amd64-disk-kvm.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/daily/server/groovy/current/groovy-server-cloudimg-amd64-disk-kvm.img -P $isostorage && break
          ;;
        "Ubuntu Focal 20.04 Cloud Image")
          [ -f "$isostorage/focal-server-cloudimg-amd64-disk-kvm.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-disk-kvm.img -P $isostorage && break
          ;;
        "Ubuntu Minimal Focal 20.04 Cloud Image")
          [ -f "$isostorage/ubuntu-20.04-minimal-cloudimg-amd64.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img -P $isostorage && break
          ;;
        "CentOS 7 Cloud Image")
          [ -f "$isostorage/CentOS-7-x86_64-GenericCloud.qcow2" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2 -P $isostorage && break
          ;;
        "Debian 10 Cloud Image")
          [ -f "$isostorage/debian-10-openstack-amd64.qcow2" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2 -P $isostorage && break
          ;;
        "Debian 9 Cloud Image")
          [ -f "$isostorage/debian-9-openstack-amd64.qcow2" ] && echo && echo "Moving on you have his cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cdimage.debian.org/cdimage/openstack/current-9/debian-9-openstack-amd64.qcow2 -P $isostorage && break
          ;;
        "Ubuntu 18.04 Bionic Image")
          [ -f "$isostorage/bionic-server-cloudimg-amd64.img" ] && echo && echo "Moving on you have his cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img -P $isostorage && break
          ;;
        "CentOS 8 Cloud Image")
          [ -f "$isostorage/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2" ] && echo && echo "Moving on you have his cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2 -P $isostorage && break
          ;;
        "Fedora 32 Cloud Image")
          [ -f "$isostorage/Fedora-Cloud-Base-32-1.6.x86_64.qcow2" ] && echo && echo "Moving on you have his cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://download.fedoraproject.org/pub/fedora/linux/releases/32/Cloud/x86_64/images/Fedora-Cloud-Base-32-1.6.x86_64.qcow2 -P $isostorage && break
          ;;
        "Rancher OS Cloud Image")
          [ -f "$isostorage/rancheros-openstack.img" ] && echo && echo "Moving on you have his cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://github.com/rancher/os/releases/download/v1.5.5/rancheros-openstack.img -P $isostorage && break
          ;;
        *) echo "invalid option";;
  esac
done
echo
echo "You have selected Cloud Image $osopt"
echo

# setting the Cloud Image for later for qm info
if [ "$osopt" == "Ubuntu Groovy 20.10 Cloud Image" ];
then
   cloudos=$isostorage'groovy-server-cloudimg-amd64-disk-kvm.img'
elif [ "$osopt" == "Ubuntu Focal 20.04 Cloud Image" ];
then
   cloudos=$isostorage'focal-server-cloudimg-amd64-disk-kvm.img'
elif [ "$osopt" == "Ubuntu Minimal Focal 20.04 Cloud Image" ];
then
   cloudos=$isostorage'ubuntu-20.04-minimal-cloudimg-amd64.img'
elif [ "$osopt" == "CentOS 7 Cloud Image" ];
then
   cloudos=$isostorage'CentOS-7-x86_64-GenericCloud.qcow2'
elif [ "$osopt" == "Debian 10 Cloud Image" ];
then
   cloudos=$isostorage'debian-10-openstack-amd64.qcow2'
elif [ "$osopt" == "Debian 9 Cloud Image" ];
then
   cloudos=$isostorage'debian-9-openstack-amd64.qcow2'
elif [ "$osopt" == "Ubuntu 18.04 Bionic Image" ];
then
   cloudos=$isostorage'bionic-server-cloudimg-amd64.img'
elif [ "$osopt" == "CentOS 8 Cloud Image" ];
then
   cloudos=$isostorage'CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2'
elif [ "$osopt" == "Fedora 32 Cloud Image" ];
then
   cloudos=$isostorage'Fedora-Cloud-Base-32-1.6.x86_64.qcow2'
else [ "$osopt" == "Rancher OS Cloud Image" ];
   cloudos=$isostorage'rancheros-openstack.img'
fi
echo

# just in case you are reusing ID's - which most do so...
# next line removes any existing one for this vmid we are setting up
[ -f "$snippetstorage$VMID.yaml" ] && rm $snippetstorage$VMID.yaml

#cloud-config data for user
echo "#cloud-config" >> $snippetstorage$VMID.yaml
echo "hostname: $NEWHOSTNAME" >> $snippetstorage$VMID.yaml
echo "manage_etc_hosts: true" >> $snippetstorage$VMID.yaml
echo "user: $USER" >> $snippetstorage$VMID.yaml
echo "password: $kindofsecure" >> $snippetstorage$VMID.yaml
echo "ssh_authorized_keys:" >> $snippetstorage$VMID.yaml
echo "  - $SSHAUTHKEYS" >> $snippetstorage$VMID.yaml
#echo "$SSHAUTHKEYS" >> $snippetstorage$VMID.yaml
echo "chpasswd:" >> $snippetstorage$VMID.yaml
echo "  expire: False" >> $snippetstorage$VMID.yaml
echo "ssh_pwauth: $sshpassallow" >> $snippetstorage$VMID.yaml
echo "users:" >> $snippetstorage$VMID.yaml
echo "  - default" >> $snippetstorage$VMID.yaml
echo "package_upgrade: true" >> $snippetstorage$VMID.yaml
echo "packages:" >> $snippetstorage$VMID.yaml
# Always install Qemu-guest-agent
echo " - qemu-guest-agent" >> $snippetstorage$VMID.yaml
echo "runcmd:" >> $snippetstorage$VMID.yaml
echo " - systemctl restart qemu-guest-agent" >> $snippetstorage$VMID.yaml
# custom settings
echo "write_files:" >> $snippetstorage$VMID.yaml
echo "- content: |" >> $snippetstorage$VMID.yaml|
echo "    network:" >> $snippetstorage$VMID.yaml
echo "      ethernets:" >> $snippetstorage$VMID.yaml
echo "        eth0:" >> $snippetstorage$VMID.yaml
echo "          addresses:" >> $snippetstorage$VMID.yaml
echo "            - $IPADDRESS" >> $snippetstorage$VMID.yaml
echo "          nameservers:" >> $snippetstorage$VMID.yaml
echo "            addresses:" >> $snippetstorage$VMID.yaml
echo "              - 213.186.33.99" >> $snippetstorage$VMID.yaml
echo "            search: []" >> $snippetstorage$VMID.yaml
echo "          optional: true" >> $snippetstorage$VMID.yaml
echo "          routes:" >> $snippetstorage$VMID.yaml
echo "            - to: 0.0.0.0/0" >> $snippetstorage$VMID.yaml
echo "              via: $GATEWAY" >> $snippetstorage$VMID.yaml
echo "              on-link: true" >> $snippetstorage$VMID.yaml
echo "      version: 2" >> $snippetstorage$VMID.yaml
echo "  path: /etc/netplan/50-cloud-init.yaml" >> $snippetstorage$VMID.yaml
echo "runcmd:" >> $snippetstorage$VMID.yaml
echo " - netplan apply " >> $snippetstorage$VMID.yaml
# custom settings end

# create a new VM
qm create $VMID --name $NEWHOSTNAME --cores $CORES --onboot 1 --memory $MEMORY --agent 1,fstrim_cloned_disks=1

    qm set $VMID --net0 virtio,bridge=$vmbrused,macaddr=$MACADDRESS,firewall=1

# import the downloaded disk to local-lvm storage

if [[ $vmstorage == "local" ]]
then
   qm importdisk $VMID $cloudos $vmstorage -format qcow2
else
   qm importdisk $VMID $cloudos $vmstorage
fi

if [[ $vmstorage == "local" ]]
then
   qm set $VMID --scsihw virtio-scsi-pci --scsi0 /var/lib/vz/images/$VMID/vm-$VMID-disk-0.qcow2,discard=on
else
   qm set $VMID --scsihw virtio-scsi-pci --scsi0 $vmstorage:vm-$VMID-disk-0,discard=on
fi

# cd drive for cloudinit info
qm set $VMID --ide2 $vmstorage:cloudinit

# make it boot hard drive only
qm set $VMID --boot c --bootdisk scsi0

qm set $VMID --serial0 socket --vga serial0

#Here we are going to set the network stuff from above
qm set $VMID --ipconfig0 ip=$IPADDRESS,gw=$GATEWAY

# Set disk size selected from above
    qm resize $VMID scsi0 "$DISKSIZE"G

if [[ "$PROTECTVM" =~ ^[Yy]$ || "$PROTECTVM" =~ ^[yY][eE][sS] ]]
then
    qm set "$VMID" --protection 1
else
    qm set "$VMID" --protection 0
fi

# Disabling tablet mode, usually is enabled but don't need it
qm set $VMID --tablet 0

# Setting the cloud-init user information
qm set $VMID --cicustom "user=$snipstorage:snippets/$VMID.yaml"

## Start the VM after Creation!!!!
if [[ $AUTOSTART =~ ^[Yy]$ || $AUTOSTART =~ ^[yY][eE][sS] ]]
then
    qm start $VMID
fi

# Migrating VM to the correct node if selected
if [[ $NODESYESNO =~ ^[Yy]$ || $NODESYESNO =~ ^[yY][eE][sS] ]]
then
    qm migrate $VMID $migratenode --online
fi
