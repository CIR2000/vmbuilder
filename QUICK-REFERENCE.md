################################################################################
# VMBuilder Quick Reference - Tutte le variabili
################################################################################

#==============================================================================
# VARIABILI OBBLIGATORIE (devono essere sempre specificate)
#==============================================================================

NEWHOSTNAME="server-name"        # Nome host VM
VMID=""                          # ID VM ("" = auto) | Esempio: "101"
USER="admin"                     # Username principale
PASSWORD="SecurePass123!"        # Password (hashata con SHA-512)
SSH_KEY_PATH="/path/to/key.pub" # Path chiave SSH pubblica
CORES="4"                        # CPU cores
MEMORY="4096"                    # RAM in MB
DISKSIZE="50"                    # Disco in GB
IPADDRESS="192.168.1.100/32"    # IP/32 (must end /32)
GATEWAY="192.168.1.254"         # Gateway (must end .254)
MACADDRESS="52:54:00:AA:BB:CC"  # MAC address (xx:xx:xx:xx:xx:xx)
CLOUD_IMAGE="noble"              # OS (vedi lista sotto)

#==============================================================================
# VARIABILI OPZIONALI (hanno valori default)
#==============================================================================

# Storage & Network
VMSTORAGE="local"                # Default: local
VMBRIDGE="vmbr0"                 # Default: vmbr0

# DNS
NAMESERVER="213.186.33.99"       # Default: 213.186.33.99 OVH
SEARCHDOMAIN="local"             # Default: local

# Behavior
AUTOSTART="Y"                    # Y/N - Default: Y
PROTECTVM="N"                    # Y/N - Default: N

# Cluster (solo se hai cluster Proxmox)
#MIGRATENODE="pve2"              # Commentato = no migration


#==============================================================================
# CLOUD_IMAGE - Opzioni disponibili
#==============================================================================

# === UBUNTU ===
# noble          - Ubuntu 24.04 LTS (più recente)
# jammy          - Ubuntu 22.04 LTS  
# focal          - Ubuntu 20.04 LTS
# focal-minimal  - Ubuntu 20.04 Minimal
# bionic         - Ubuntu 18.04 LTS (EOL)
# groovy         - Ubuntu 20.10 (EOL)

# === ENTERPRISE (RHEL/CentOS family) ===
# almalinux9     - AlmaLinux 9 (RHEL 9 clone)
# almalinux8     - AlmaLinux 8 (RHEL 8 clone)
# centos7        - CentOS 7 (EOL 2024)
# centos8        - CentOS 8 (EOL 2021)

# === DEBIAN ===
# debian13       - Debian 13 Trixie (Testing)
# debian12       - Debian 12 Bookworm (Stable)
# debian10       - Debian 10 Buster
# debian9        - Debian 9 Stretch (EOL)

# === ALTRI ===
# fedora32       - Fedora 32 (EOL)
# rancheros      - Rancher OS (deprecato)

# NAMESERVER COMUNI:
#   Google: 8.8.8.8 8.8.4.4
#   Cloudflare: 1.1.1.1 1.0.0.1
#   Quad9: 9.9.9.9
#   OVH: 213.186.33.99
