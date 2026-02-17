#!/bin/bash
# VMBuilder - Automated version with config file support
# 
# Usage: 
#   Interactive mode: ./vmbuilder-auto.sh
#   Automated mode:   ./vmbuilder-auto.sh config.conf
#   Batch mode:       ./vmbuilder-auto.sh batch-configs/

set -e

CONFIG_FILE="$1"

# Function to load config from file
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        echo "ERRORE: File di configurazione '$config_file' non trovato!"
        exit 1
    fi
    
    echo "Caricamento configurazione da: $config_file"
    
    # Source the config file
    source "$config_file"
    
    # Validate required variables
    local required_vars=(
        "NEWHOSTNAME"
        "USER"
        "PASSWORD"
        "SSH_KEY_PATH"
        "CORES"
        "MEMORY"
        "DISKSIZE"
        "IPADDRESS"
        "GATEWAY"
        "MACADDRESS"
        "CLOUD_IMAGE"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "ERRORE: Variabile '$var' non definita nel file di configurazione!"
            exit 1
        fi
    done
    
    echo "✓ Configurazione caricata con successo"
    echo ""
}

# Function to show config summary
show_config_summary() {
    echo "=========================================="
    echo "RIEPILOGO CONFIGURAZIONE VM"
    echo "=========================================="
    echo "Hostname:        $NEWHOSTNAME"
    echo "VM ID:           ${VMID:-auto}"
    echo "User:            $USER"
    echo "SSH Key:         $SSH_KEY_PATH"
    echo "Cores:           $CORES"
    echo "Memory:          $MEMORY MB"
    echo "Disk:            $DISKSIZE GB"
    echo "IP Address:      $IPADDRESS"
    echo "Gateway:         $GATEWAY"
    echo "MAC Address:     $MACADDRESS"
    echo "Cloud Image:     $CLOUD_IMAGE"
    echo "Storage:         ${VMSTORAGE:-local}"
    echo "Bridge:          ${VMBRIDGE:-vmbr0}"
    echo "Nameserver:      ${NAMESERVER:-213.186.33.99}"
    echo "Search Domain:   ${SEARCHDOMAIN:-local}"
    echo "Auto Start:      ${AUTOSTART:-Y}"
    echo "Protection:      ${PROTECTVM:-N}"
    [ -n "$MIGRATENODE" ] && echo "Migrate to Node: $MIGRATENODE"
    echo "=========================================="
    echo ""
}

# Function for interactive mode (original behavior)
interactive_mode() {
    echo "#############################################################################################"
    echo "###"
    echo "# Welcome to the Proxmox Virtual Machine Builder script"
    echo "# INTERACTIVE MODE"
    echo "#"
    echo "# Per modalità automatica: $0 <config-file>"
    echo "###"
    echo "#############################################################################################"
    echo
    
    # Original interactive prompts here
    while true; do
       read -r -p "Enter desired hostname for the Virtual Machine: " NEWHOSTNAME
       if [[ ! $NEWHOSTNAME == *['!'@#\$%^\&*()\_+\']* ]];then
          break;
       else
          echo "Contains a character not allowed for a hostname, please try again"
       fi
    done
    
    # Get VM ID
    vmidnext=$(pvesh get /cluster/nextid)
    declare -a vmidsavail=$(pvesh get /cluster/resources | awk '{print $2}' | sed '/storage/d' | sed '/node/d' | sed '/id/d' | sed '/./,/^$/!d' | cut -d '/' -f 2 | sed '/^$/d')
    
    for ((i=1;i<=99;i++)); do
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
            get_vmidnumber 'Enter a different number because either you are using it or reserved by the system'
        fi
    }
    echo "Enter desired VM ID number or press enter to accept default of $vmidnext: "
    get_vmidnumber ''
    
    # Continue with other prompts...
    read -p "Enter desired VM username: " USER
    
    while true; do
        read -s -p "Please enter password for the user: " PASSWORD
        echo
        read -s -p "Please repeat password for the user: " PASSWORD1
        echo
        [ "$PASSWORD" = "$PASSWORD1" ] && break
        echo "Please try again passwords did not match"
        echo
    done
    
    while true; do
        echo
        read -p "Enter the path and key name (path/to/key.pub) [default: /home/vmbuilder/ubuntu_key.pub]: " SSH_KEY_PATH
        SSH_KEY_PATH=${SSH_KEY_PATH:-/home/vmbuilder/ubuntu_key.pub}
        echo
        [ -f "$SSH_KEY_PATH" ] && echo "It appears to be a good key path." && break || echo && echo "Does not exist, try again please."
    done
    
    read -p "Enter number of cores for VM: " CORES
    read -p "Enter how much memory for the VM (example 2048 is 2Gb of memory): " MEMORY
    read -p "Enter DISK size in Gb's (example 20 is 20Gb of disk): " DISKSIZE
    
    # Network config
    while true; do
        read -p "Enter IP address to use (format example 192.168.1.50/32): " IPADDRESS
        read -p "Please repeat IP address to use (format example 192.168.1.50/32): " IPADDRESS2
        if [[ $IPADDRESS != */32 ]];then
            echo "Please try again, subnet must be /32"
        else
            [ "$IPADDRESS" = "$IPADDRESS2" ] && break
            echo "Please try again IP addresses did not match"
        fi
    done
    
    while true; do
        read -p "Enter gateway IP address to use (format example 192.168.1.254): " GATEWAY
        read -p "Please repeat gateway IP address to use (format example 192.168.1.254): " GATEWAY2
        if [[ $GATEWAY != *.254 ]];then
            echo "Please try again, gateway must end with .254"
        else
            [ "$GATEWAY" = "$GATEWAY2" ] && break
            echo "Please try again IP addresses did not match"
        fi
    done
    
    while true; do
        read -p "Enter MAC address to use (format example xx:xx:xx:xx:xx:xx): " MACADDRESS
        read -p "Please repeat MAC address to use (format example xx:xx:xx:xx:xx:xx): " MACADDRESS2
        [ "$MACADDRESS" = "$MACADDRESS2" ] && break
        echo "Please try again MAC addresses did not match"
    done
    
    # Cloud image selection
    echo "Please select the cloud image you would like to use"
    PS3='Select an option and press Enter: '
    options=(
        "Ubuntu Noble 24.04 LTS Cloud Image" 
        "Ubuntu Jammy 22.04 LTS Cloud Image" 
        "Ubuntu Groovy 20.10 Cloud Image" 
        "Ubuntu Focal 20.04 Cloud Image" 
        "Ubuntu Minimal Focal 20.04 Cloud Image" 
        "Ubuntu 18.04 Bionic Image"
        "AlmaLinux 9 Latest Cloud Image"  
        "AlmaLinux 8 Latest Cloud Image" 
        "CentOS 8 Cloud Image" 
        "CentOS 7 Cloud Image"
        "Debian 13 Trixie Cloud Image"
        "Debian 12 Bookworm Cloud Image"
        "Debian 10 Buster Cloud Image" 
        "Debian 9 Stretch Cloud Image" 
        "Fedora 32 Cloud Image" 
        "Rancher OS Cloud Image"
    )
    select osopt in "${options[@]}"; do
        case $osopt in
            "Ubuntu Noble 24.04 LTS Cloud Image")
                CLOUD_IMAGE="noble"
                break
                ;;
            "Ubuntu Jammy 22.04 LTS Cloud Image")
                CLOUD_IMAGE="jammy"
                break
                ;;
            "Ubuntu Groovy 20.10 Cloud Image")
                CLOUD_IMAGE="groovy"
                break
                ;;
            "Ubuntu Focal 20.04 Cloud Image")
                CLOUD_IMAGE="focal"
                break
                ;;
            "Ubuntu Minimal Focal 20.04 Cloud Image")
                CLOUD_IMAGE="focal-minimal"
                break
                ;;
            "Ubuntu 18.04 Bionic Image")
                CLOUD_IMAGE="bionic"
                break
                ;;
            "AlmaLinux 9 Latest Cloud Image")
                CLOUD_IMAGE="almalinux9"
                break
                ;;
            "AlmaLinux 8 Latest Cloud Image")
                CLOUD_IMAGE="almalinux8"
                break
                ;;
            "CentOS 8 Cloud Image")
                CLOUD_IMAGE="centos8"
                break
                ;;
            "CentOS 7 Cloud Image")
                CLOUD_IMAGE="centos7"
                break
                ;;
            "Debian 13 Trixie Cloud Image")
                CLOUD_IMAGE="debian13"
                break
                ;;
            "Debian 12 Bookworm Cloud Image")
                CLOUD_IMAGE="debian12"
                break
                ;;
            "Debian 10 Buster Cloud Image")
                CLOUD_IMAGE="debian10"
                break
                ;;
            "Debian 9 Stretch Cloud Image")
                CLOUD_IMAGE="debian9"
                break
                ;;
            "Fedora 32 Cloud Image")
                CLOUD_IMAGE="fedora32"
                break
                ;;
            "Rancher OS Cloud Image")
                CLOUD_IMAGE="rancheros"
                break
                ;;
            *) echo "invalid option";;
        esac
    done
    
    # Set defaults
    VMSTORAGE=${VMSTORAGE:-local}
    VMBRIDGE=${VMBRIDGE:-vmbr0}
    NAMESERVER=${NAMESERVER:-213.186.33.99}
    SEARCHDOMAIN=${SEARCHDOMAIN:-local}
    AUTOSTART=${AUTOSTART:-Y}
    PROTECTVM=${PROTECTVM:-N}
}

# Function to create VM (works for both modes)
create_vm() {
    local isostorage="/var/lib/vz/template/iso/"
    local vmstorage="${VMSTORAGE:-local}"
    local vmbridge="${VMBRIDGE:-vmbr0}"
    local nameserver="${NAMESERVER:-213.186.33.99}"
    local searchdomain="${SEARCHDOMAIN:-local}"
    local autostart="${AUTOSTART:-Y}"
    local protectvm="${PROTECTVM:-N}"
    
    # Read SSH key
    if [ ! -f "$SSH_KEY_PATH" ]; then
        echo "ERRORE: SSH key non trovata: $SSH_KEY_PATH"
        exit 1
    fi
    SSHAUTHKEYS=$(cat "$SSH_KEY_PATH")
    
    # Hash password
    HASHED_PASSWORD=$(openssl passwd -6 "$PASSWORD")
    
    # Auto-assign VMID if not specified
    if [ -z "$VMID" ]; then
        VMID=$(pvesh get /cluster/nextid)
        echo "Auto-assigned VM ID: $VMID"
    fi
    
    # Determine cloud image file and URL
    case $CLOUD_IMAGE in
        "noble")
            cloudfile="noble-server-cloudimg-amd64.img"
            cloudurl="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            ;;
        "jammy")
            cloudfile="jammy-server-cloudimg-amd64.img"
            cloudurl="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
            ;;
        "groovy")
            cloudfile="groovy-server-cloudimg-amd64-disk-kvm.img"
            cloudurl="https://cloud-images.ubuntu.com/daily/server/groovy/current/groovy-server-cloudimg-amd64-disk-kvm.img"
            ;;
        "focal")
            cloudfile="focal-server-cloudimg-amd64.img"
            cloudurl="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
            ;;
        "focal-minimal")
            cloudfile="ubuntu-20.04-minimal-cloudimg-amd64.img"
            cloudurl="https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img"
            ;;
        "almalinux9")
            cloudfile="AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            cloudurl="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
            ;;
        "almalinux8")
            cloudfile="AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            cloudurl="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
            ;;
        "centos7")
            cloudfile="CentOS-7-x86_64-GenericCloud.qcow2"
            cloudurl="http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2"
            ;;
        "debian10")
            cloudfile="debian-10-openstack-amd64.qcow2"
            cloudurl="https://cdimage.debian.org/cdimage/openstack/current-10/debian-10-openstack-amd64.qcow2"
            ;;
        "debian9")
            cloudfile="debian-9-openstack-amd64.qcow2"
            cloudurl="https://cdimage.debian.org/cdimage/openstack/current-9/debian-9-openstack-amd64.qcow2"
            ;;
        "bionic")
            cloudfile="bionic-server-cloudimg-amd64.img"
            cloudurl="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
            ;;
        "centos8")
            cloudfile="CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2"
            cloudurl="https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.2.2004-20200611.2.x86_64.qcow2"
            ;;
        "fedora32")
            cloudfile="Fedora-Cloud-Base-32-1.6.x86_64.qcow2"
            cloudurl="https://download.fedoraproject.org/pub/fedora/linux/releases/32/Cloud/x86_64/images/Fedora-Cloud-Base-32-1.6.x86_64.qcow2"
            ;;
        "rancheros")
            cloudfile="rancheros-openstack.img"
            cloudurl="https://github.com/rancher/os/releases/download/v1.5.5/rancheros-openstack.img"
            ;;
        "debian13")
            cloudfile="debian-13-generic-amd64.qcow2"
            cloudurl="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
            ;;
        "debian12")
            cloudfile="debian-12-generic-amd64.qcow2"
            cloudurl="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
            ;;
        *)
            echo "ERRORE: Cloud image non riconosciuta: $CLOUD_IMAGE"
            exit 1
            ;;
    esac
    
    cloudos="$isostorage$cloudfile"
    
    # Download cloud image if not exists
    if [ ! -f "$cloudos" ]; then
        echo "Downloading cloud image: $cloudfile"
        wget -N "$cloudurl" -P "$isostorage"
    else
        echo "Cloud image already exists: $cloudfile"
    fi
    
    echo ""
    echo "============================================"
    echo "Creating VM $VMID..."
    echo "============================================"
    
    # Create VM
    qm create $VMID --name $NEWHOSTNAME --cores $CORES --onboot 1 --memory $MEMORY --agent 1,fstrim_cloned_disks=1
    
    # Set network
    qm set $VMID --net0 virtio,bridge=$vmbridge,macaddr=$MACADDRESS,firewall=1
    
    # Import disk
    if [[ $vmstorage == "local" ]]; then
       qm importdisk $VMID $cloudos $vmstorage -format qcow2
       qm set $VMID --scsihw virtio-scsi-pci --scsi0 /var/lib/vz/images/$VMID/vm-$VMID-disk-0.qcow2,discard=on
    else
       qm importdisk $VMID $cloudos $vmstorage
       qm set $VMID --scsihw virtio-scsi-pci --scsi0 $vmstorage:vm-$VMID-disk-0,discard=on
    fi
    
    # Cloud-init drive
    qm set $VMID --ide2 $vmstorage:cloudinit
    
    # Boot config
    qm set $VMID --boot c --bootdisk scsi0
    qm set $VMID --serial0 socket --vga serial0
    
    # Resize disk
    qm resize $VMID scsi0 "${DISKSIZE}G"
    
    # Disable tablet
    qm set $VMID --tablet 0
    
    # Protection
    if [[ "$protectvm" =~ ^[Yy]$ || "$protectvm" =~ ^[yY][eE][sS]$ ]]; then
        qm set "$VMID" --protection 1
    else
        qm set "$VMID" --protection 0
    fi
    
    echo "============================================"
    echo "Configuring integrated cloud-init..."
    echo "============================================"
    
    # Configure cloud-init
    qm set $VMID --ciuser "$USER"
    qm set $VMID --cipassword "$HASHED_PASSWORD"
    
    # SSH keys
    TEMP_SSH_KEY="/tmp/sshkey-$VMID.tmp"
    echo "$SSHAUTHKEYS" > "$TEMP_SSH_KEY"
    qm set $VMID --sshkeys "$TEMP_SSH_KEY"
    rm -f "$TEMP_SSH_KEY"
    
    # Network
    qm set $VMID --ipconfig0 ip=$IPADDRESS,gw=$GATEWAY
    qm set $VMID --nameserver "$nameserver"
    qm set $VMID --searchdomain "$searchdomain"
    
    # Force cloud-init on first boot
    qm set $VMID --ciupgrade 1
    
    echo "✓ Cloud-init configuration completed!"
    echo ""
    
    # Start VM
    if [[ $autostart =~ ^[Yy]$ || $autostart =~ ^[yY][eE][sS]$ ]]; then
        echo "Starting VM $VMID..."
        qm start $VMID
    fi
    
    # Migrate if specified
    if [ -n "$MIGRATENODE" ]; then
        echo "Migrating VM $VMID to node $MIGRATENODE..."
        sleep 5  # Wait for VM to fully start
        qm migrate $VMID $MIGRATENODE --online
    fi
    
    echo ""
    echo "============================================"
    echo "✓ VM $VMID ($NEWHOSTNAME) created successfully!"
    echo "============================================"
    echo "IP: $IPADDRESS"
    echo "Gateway: $GATEWAY"
    echo "User: $USER"
    echo "Configuration: /etc/pve/qemu-server/$VMID.conf"
    echo "============================================"
    echo ""
}

# Main script logic
if [ -z "$CONFIG_FILE" ]; then
    # Interactive mode
    interactive_mode
    show_config_summary
    read -p "Proceed with VM creation? (Y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Nn]$ ]]; then
        create_vm
    else
        echo "VM creation cancelled."
        exit 0
    fi
elif [ -d "$CONFIG_FILE" ]; then
    # Batch mode - process all .conf files in directory
    echo "============================================"
    echo "BATCH MODE - Processing directory: $CONFIG_FILE"
    echo "============================================"
    echo ""
    
    conf_files=$(ls -1 "$CONFIG_FILE"/*.conf 2>/dev/null || true)
    
    if [ -z "$conf_files" ]; then
        echo "No .conf files found in $CONFIG_FILE"
        exit 1
    fi
    
    count=0
    for conf in $conf_files; do
        count=$((count + 1))
    done
    
    echo "Found $count configuration file(s)"
    echo ""
    
    read -p "Process all $count VMs? (Y/n): " CONFIRM
    if [[ $CONFIRM =~ ^[Nn]$ ]]; then
        echo "Batch processing cancelled."
        exit 0
    fi
    
    processed=0
    failed=0
    
    for conf in $conf_files; do
        echo ""
        echo "######################################"
        echo "Processing: $(basename $conf)"
        echo "######################################"
        
        # Reset variables
        unset VMID NEWHOSTNAME USER PASSWORD SSH_KEY_PATH CORES MEMORY DISKSIZE
        unset IPADDRESS GATEWAY MACADDRESS CLOUD_IMAGE VMSTORAGE VMBRIDGE
        unset NAMESERVER SEARCHDOMAIN AUTOSTART PROTECTVM MIGRATENODE
        
        if load_config "$conf"; then
            show_config_summary
            
            if create_vm; then
                processed=$((processed + 1))
                echo "✓ Success: VM from $(basename $conf)"
            else
                failed=$((failed + 1))
                echo "✗ Failed: VM from $(basename $conf)"
            fi
        else
            failed=$((failed + 1))
            echo "✗ Failed to load: $(basename $conf)"
        fi
        
        # Wait between VMs
        if [ $processed -lt $count ]; then
            echo ""
            echo "Waiting 5 seconds before next VM..."
            sleep 5
        fi
    done
    
    echo ""
    echo "============================================"
    echo "BATCH PROCESSING COMPLETED"
    echo "============================================"
    echo "Successfully created: $processed VM(s)"
    echo "Failed: $failed VM(s)"
    echo "============================================"
    
else
    # Single config file mode
    echo "============================================"
    echo "AUTOMATED MODE"
    echo "============================================"
    echo ""
    
    load_config "$CONFIG_FILE"
    show_config_summary
    
    read -p "Proceed with VM creation? (Y/n): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Nn]$ ]]; then
        create_vm
    else
        echo "VM creation cancelled."
        exit 0
    fi
fi
