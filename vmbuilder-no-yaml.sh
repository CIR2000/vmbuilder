#!/bin/bash
# MODIFIED VERSION - Uses integrated cloud-init (no external YAML files)
# DEFAULT VALUES
# vmstorage local
# isostorage /var/lib/vz/template/iso/
# vmbr vmbr0

clear
echo "#############################################################################################"
echo "###"
echo "# Welcome to the Proxmox Virtual Machine Builder script that uses Cloud Images"
echo "# This will automate so much and make it so easy to spin up a VM machine from a cloud image."
echo "# A VM Machine typically will be spun up and ready in less then 3 minutes."
echo "#"
echo "# MODIFIED: Uses integrated cloud-init (no external YAML snippets needed)"
echo "#"
echo "# Original by Francis Munch - Modified for integrated cloud-init"
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
echo "user: $USER"
echo
while true; do
    read -s -p "Please enter password for the user : " PASSWORD
    PASSWORD=$PASSWORD
    echo
    read -s -p "Please repeat password for the user : " PASSWORD1
    echo
    [ "$PASSWORD" = "$PASSWORD1" ] && break
    echo
    echo "Please try again passwords did not match"
    echo
done

# This block is see if they want to add a key to the VM
# and then it checks the path to it and checks to make sure it exists
while true; do
    echo
    read -p "Enter the path and key name (path/to/key.pub) [default: /home/vmbuilder/ubuntu_key.pub]: " path_to_ssh_key
    path_to_ssh_key=${path_to_ssh_key:-/home/vmbuilder/ubuntu_key.pub}
    echo
    [ -f "$path_to_ssh_key" ] && echo "It appears to be a good key path." && SSHAUTHKEYS=$(cat "$path_to_ssh_key") && break || echo && echo "Does not exist, try again please."
done

# Hash password for cloud-init
HASHED_PASSWORD=$(openssl passwd -6 "$PASSWORD")

# set variable to default value
vmstorage=local
isostorage=/var/lib/vz/template/iso/
vmbrused=vmbr0
AUTOSTART=Y
PROTECTVM=N
# end set

echo
read -p "Enter number of cores for VM $VMID: " CORES
echo
read -p "Enter how much memory for the VM $VMID (example 2048 is 2Gb of memory): " MEMORY
echo
read -p "Enter DISK size in Gb's (example 20 is 20Gb of disk): " DISKSIZE

echo
# This block of code is for picking which node to have the VM on.
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
    read -p "Enter IP address to use (format example 192.168.1.50/32): " IPADDRESS
    echo
    read -p "Please repeat IP address to use (format example 192.168.1.50/32): " IPADDRESS2
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
        echo
        echo "Gateway IP in OVH is made fom the first three block of baremetal IP + .254"
        echo
    read -p "Enter gateway IP address to use (format example 192.168.1.254): " GATEWAY
    echo
    read -p "Please repeat gateway IP address to use (format example 192.168.1.254): " GATEWAY2
    echo
    if [[ $GATEWAY != *.254 ]];then
        echo
        echo "Please try again, gateway must end with .254"
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
    read -p "Enter MAC address to use (format example xx:xx:xx:xx:xx:xx): " MACADDRESS
    echo
    read -p "Please repeate MAC address to use (format example xx:xx:xx:xx:xx:xx): " MACADDRESS2
    echo
    [ "$MACADDRESS" = "$MACADDRESS2" ] && break
    echo
    echo "Please try again MAC addresses did not match"
    echo
done

echo "Please select the cloud image you would like to use"
PS3='Select an option and press Enter: '
options=("Ubuntu Noble 24.04 LTS Cloud Image" "Ubuntu Jammy 22.04 LTS Cloud Image" "Ubuntu Groovy 20.10 Cloud Image" "Ubuntu Focal 20.04 Cloud Image" "Ubuntu Minimal Focal 20.04 Cloud Image" "AlmaLinux 9 Latest Cloud Image"  "AlmaLinux 8 Latest Cloud Image" "CentOS 7 Cloud Image" "Debian 10 Cloud Image" "Debian 9 Cloud Image" "Ubuntu 18.04 Bionic Image" "CentOS 8 Cloud Image" "Fedora 32 Cloud Image" "Rancher OS Cloud Image")
select osopt in "${options[@]}"
do
  case $osopt in
        "Ubuntu Noble 24.04 LTS Cloud Image")
          [ -f "$isostorage/noble-server-cloudimg-amd64.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img -P $isostorage && break
          ;;
        "Ubuntu Jammy 22.04 LTS Cloud Image")
          [ -f "$isostorage/jammy-server-cloudimg-amd64.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -P $isostorage && break
          ;;
        "Ubuntu Groovy 20.10 Cloud Image")
          [ -f "$isostorage/groovy-server-cloudimg-amd64-disk-kvm.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/daily/server/groovy/current/groovy-server-cloudimg-amd64-disk-kvm.img -P $isostorage && break
          ;;
        "Ubuntu Focal 20.04 Cloud Image")
          [ -f "$isostorage/focal-server-cloudimg-amd64.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -P $isostorage && break
          ;;
        "Ubuntu Minimal Focal 20.04 Cloud Image")
          [ -f "$isostorage/ubuntu-20.04-minimal-cloudimg-amd64.img" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img -P $isostorage && break
          ;;
        "AlmaLinux 9 Latest Cloud Image")
          [ -f "$isostorage/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://raw.repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2 -P $isostorage && break
          ;;
        "AlmaLinux 8 Latest Cloud Image")
          [ -f "$isostorage/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2" ] && echo && echo "Moving on you have this cloud image" && break || echo && echo "You do not have this cloud image file so we are downloading it now" && echo && wget -N https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2 -P $isostorage && break
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
elif [ "$osopt" == "Ubuntu Noble 24.04 LTS Cloud Image" ];
then
   cloudos=$isostorage'noble-server-cloudimg-amd64.img'
elif [ "$osopt" == "Ubuntu Jammy 22.04 LTS Cloud Image" ];
then
   cloudos=$isostorage'jammy-server-cloudimg-amd64.img'
elif [ "$osopt" == "Ubuntu Focal 20.04 Cloud Image" ];
then
   cloudos=$isostorage'focal-server-cloudimg-amd64.img'
elif [ "$osopt" == "Ubuntu Minimal Focal 20.04 Cloud Image" ];
then
   cloudos=$isostorage'ubuntu-20.04-minimal-cloudimg-amd64.img'
elif [ "$osopt" == "AlmaLinux 9 Latest Cloud Image" ];
then
   cloudos=$isostorage'AlmaLinux-9-GenericCloud-latest.x86_64.qcow2'
elif [ "$osopt" == "AlmaLinux 8 Latest Cloud Image" ];
then
   cloudos=$isostorage'AlmaLinux-8-GenericCloud-latest.x86_64.qcow2'
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

echo "============================================"
echo "Creating VM with integrated cloud-init..."
echo "============================================"

# create a new VM
qm create $VMID --name $NEWHOSTNAME --cores $CORES --onboot 1 --memory $MEMORY --agent 1,fstrim_cloned_disks=1

# Set network with MAC address
qm set $VMID --net0 virtio,bridge=$vmbrused,macaddr=$MACADDRESS,firewall=1

# import the downloaded disk to storage
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

# Set disk size
qm resize $VMID scsi0 "$DISKSIZE"G

# Disabling tablet mode
qm set $VMID --tablet 0

# VM Protection
if [[ "$PROTECTVM" =~ ^[Yy]$ || "$PROTECTVM" =~ ^[yY][eE][sS] ]]
then
    qm set "$VMID" --protection 1
else
    qm set "$VMID" --protection 0
fi

echo "============================================"
echo "Configuring integrated cloud-init..."
echo "============================================"

# Configure cloud-init directly in VM config (NO YAML FILES!)
qm set $VMID --ciuser "$USER"
qm set $VMID --cipassword "$HASHED_PASSWORD"

# Create temporary file for SSH keys (needed for qm set --sshkeys)
TEMP_SSH_KEY="/tmp/sshkey-$VMID.tmp"
echo "$SSHAUTHKEYS" > "$TEMP_SSH_KEY"
qm set $VMID --sshkeys "$TEMP_SSH_KEY"
rm -f "$TEMP_SSH_KEY"

# Set network configuration
qm set $VMID --ipconfig0 ip=$IPADDRESS,gw=$GATEWAY

# Set DNS nameservers
qm set $VMID --nameserver "213.186.33.99"

# Set search domain
qm set $VMID --searchdomain "local"

# Force cloud-init to run on first boot
qm set $VMID --ciupgrade 1

echo "============================================"
echo "Cloud-init configuration completed!"
echo "All settings stored in /etc/pve/qemu-server/$VMID.conf"
echo "No external YAML files needed - everything is in the VM config!"
echo "============================================"

# Show final cloud-init configuration
echo
echo "Verifying cloud-init configuration:"
qm cloudinit dump $VMID user

## Start the VM after Creation!!!!
if [[ $AUTOSTART =~ ^[Yy]$ || $AUTOSTART =~ ^[yY][eE][sS] ]]
then
    echo
    echo "Starting VM $VMID..."
    qm start $VMID
fi

# Migrating VM to the correct node if selected
if [[ $NODESYESNO =~ ^[Yy]$ || $NODESYESNO =~ ^[yY][eE][sS] ]]
then
    echo
    echo "Migrating VM $VMID to node $migratenode..."
    qm migrate $VMID $migratenode --online
fi

echo
echo "============================================"
echo "VM $VMID ($NEWHOSTNAME) created successfully!"
echo "IP: $IPADDRESS"
echo "Gateway: $GATEWAY"
echo "User: $USER"
echo "============================================"
echo
echo "IMPORTANT: Configuration is stored in /etc/pve/qemu-server/$VMID.conf"
echo "This config is automatically included in Proxmox backups!"
echo "No need to manage external YAML snippet files anymore."
echo
