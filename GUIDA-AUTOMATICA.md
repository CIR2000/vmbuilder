# VMBuilder - Guida Modalità Automatica

## Tre modalità di utilizzo

### 1. Modalità Interattiva (originale)
```bash
./vmbuilder-auto.sh
# Ti chiede tutti i parametri interattivamente
```

### 2. Modalità Automatica - Singola VM
```bash
./vmbuilder-auto.sh vm-config.conf
# Crea una VM dal file di configurazione
```

### 3. Modalità Batch - Multiple VM
```bash
./vmbuilder-auto.sh batch-configs/
# Crea tutte le VM dai file .conf nella directory
```

---

## Quick Start - Singola VM

### 1. Crea file di configurazione

```bash
cat > my-vm.conf <<'EOF'
NEWHOSTNAME="web-server-01"
VMID=""
USER="admin"
PASSWORD="MySecurePassword123!"
SSH_KEY_PATH="/home/vmbuilder/ubuntu_key.pub"
CORES="4"
MEMORY="4096"
DISKSIZE="50"
IPADDRESS="192.168.1.100/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:AA:BB:01"
CLOUD_IMAGE="noble"
EOF
```

### 2. Esegui lo script

```bash
chmod +x vmbuilder-auto.sh
./vmbuilder-auto.sh my-vm.conf
```

### 3. Conferma e aspetta

Lo script:
- Mostra riepilogo configurazione
- Chiede conferma
- Crea la VM automaticamente
- ~2-3 minuti totali

---

## Quick Start - Batch (Multiple VM)

### Opzione A: Usa il generatore

```bash
# 1. Esegui il generatore
chmod +x generate-vm-configs.sh
./generate-vm-configs.sh

# 2. Rispondi alle domande
Quante VM vuoi configurare? 5
Username comune: admin
Password comune: ********
SSH key path: /home/vmbuilder/ubuntu_key.pub
Cores [2]: 4
Memory MB [2048]: 4096
Disk GB [20]: 50
Gateway [192.168.1.254]: 
Cloud Image: 1
Prefisso hostname [vm]: web
Base IP: 192.168.1
Primo numero IP [100]: 10
Base VM ID [vuoto per auto]: 200
Generazione automatica MAC? Y

# 3. Risultato: crea 5 file in batch-configs/
✓ Creato: batch-configs/web-01.conf (192.168.1.10, VMID 200)
✓ Creato: batch-configs/web-02.conf (192.168.1.11, VMID 201)
✓ Creato: batch-configs/web-03.conf (192.168.1.12, VMID 202)
✓ Creato: batch-configs/web-04.conf (192.168.1.13, VMID 203)
✓ Creato: batch-configs/web-05.conf (192.168.1.14, VMID 204)

# 4. Crea tutte le VM
./vmbuilder-auto.sh batch-configs/

# 5. Conferma batch
Found 5 configuration file(s)
Process all 5 VMs? (Y/n): Y

# 6. Aspetta 10-15 minuti
# Lo script crea automaticamente tutte le 5 VM
```

### Opzione B: Crea file manualmente

```bash
# 1. Crea directory
mkdir batch-configs

# 2. Crea file di configurazione
cat > batch-configs/vm-01.conf <<'EOF'
NEWHOSTNAME="app-server-01"
VMID="101"
USER="admin"
PASSWORD="Pass123!"
SSH_KEY_PATH="/home/vmbuilder/ubuntu_key.pub"
CORES="2"
MEMORY="2048"
DISKSIZE="20"
IPADDRESS="192.168.1.101/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:AA:01:01"
CLOUD_IMAGE="noble"
EOF

cat > batch-configs/vm-02.conf <<'EOF'
NEWHOSTNAME="app-server-02"
VMID="102"
USER="admin"
PASSWORD="Pass123!"
SSH_KEY_PATH="/home/vmbuilder/ubuntu_key.pub"
CORES="2"
MEMORY="2048"
DISKSIZE="20"
IPADDRESS="192.168.1.102/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:AA:01:02"
CLOUD_IMAGE="noble"
EOF

# 3. Esegui batch
./vmbuilder-auto.sh batch-configs/
```

---

## Formato File di Configurazione

### Parametri Obbligatori

```bash
NEWHOSTNAME="nome-host"           # Hostname della VM
VMID=""                           # ID VM (vuoto = auto)
USER="username"                   # Username cloud-init
PASSWORD="password"               # Password (sarà hashata SHA-512)
SSH_KEY_PATH="/path/to/key.pub"  # Path chiave SSH pubblica
CORES="2"                         # Numero core CPU
MEMORY="2048"                     # RAM in MB
DISKSIZE="20"                     # Disco in GB
IPADDRESS="192.168.1.50/32"      # IP con subnet /32
GATEWAY="192.168.1.254"          # Gateway (deve finire .254)
MACADDRESS="52:54:00:AA:BB:CC"   # MAC address (formato xx:xx:xx:xx:xx:xx)
CLOUD_IMAGE="noble"              # Immagine cloud (vedi sotto)
```

### Cloud Images Disponibili

```bash
# Ubuntu
CLOUD_IMAGE="noble"          # Ubuntu 24.04 LTS Noble
CLOUD_IMAGE="jammy"          # Ubuntu 22.04 LTS Jammy
CLOUD_IMAGE="focal"          # Ubuntu 20.04 LTS Focal
CLOUD_IMAGE="focal-minimal"  # Ubuntu 20.04 LTS Minimal
CLOUD_IMAGE="bionic"         # Ubuntu 18.04 LTS Bionic
CLOUD_IMAGE="groovy"         # Ubuntu 20.10 Groovy

# Red Hat Family
CLOUD_IMAGE="almalinux9"     # AlmaLinux 9 Latest
CLOUD_IMAGE="almalinux8"     # AlmaLinux 8 Latest
CLOUD_IMAGE="centos7"        # CentOS 7
CLOUD_IMAGE="centos8"        # CentOS 8

# Debian Family
CLOUD_IMAGE="debian13"       # Debian 13 (Trixie) - Testing
CLOUD_IMAGE="debian12"       # Debian 12 (Bookworm) - Stable
CLOUD_IMAGE="debian10"       # Debian 10 (Buster)
CLOUD_IMAGE="debian9"        # Debian 9 (Stretch)

# Others
CLOUD_IMAGE="fedora32"       # Fedora 32
CLOUD_IMAGE="rancheros"      # Rancher OS
```

### Parametri Opzionali

```bash
# Storage e Network (default: local e vmbr0)
VMSTORAGE="local"                # Storage Proxmox
VMBRIDGE="vmbr0"                 # Bridge di rete

# DNS
NAMESERVER="8.8.8.8 1.1.1.1"    # Server DNS
SEARCHDOMAIN="mydomain.local"    # Dominio di ricerca

# Comportamento VM
AUTOSTART="Y"                    # Auto-start dopo creazione (Y/N)
PROTECTVM="N"                    # Protezione VM (Y/N)

# Cluster (opzionale)
MIGRATENODE="pve2"               # Migra su nodo dopo creazione
```

---

## Esempi Pratici

### Esempio 1: Infrastructure as Code

```bash
# Crea infrastruttura completa con un comando

# 1. Definisci infrastruttura in file
mkdir infra
cat > infra/web-01.conf <<EOF
NEWHOSTNAME="web-01"
VMID="101"
USER="webadmin"
PASSWORD="WebPass123!"
SSH_KEY_PATH="/root/.ssh/id_rsa.pub"
CORES="4"
MEMORY="8192"
DISKSIZE="100"
IPADDRESS="192.168.1.101/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:WE:B0:01"
CLOUD_IMAGE="noble"
MIGRATENODE="pve-web"
EOF

cat > infra/db-01.conf <<EOF
NEWHOSTNAME="db-01"
VMID="201"
USER="dbadmin"
PASSWORD="DbPass456!"
SSH_KEY_PATH="/root/.ssh/id_rsa.pub"
CORES="8"
MEMORY="16384"
DISKSIZE="500"
IPADDRESS="192.168.1.201/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:DB:00:01"
CLOUD_IMAGE="jammy"
PROTECTVM="Y"
MIGRATENODE="pve-db"
EOF

cat > infra/cache-01.conf <<EOF
NEWHOSTNAME="redis-01"
VMID="301"
USER="cacheadmin"
PASSWORD="CachePass789!"
SSH_KEY_PATH="/root/.ssh/id_rsa.pub"
CORES="4"
MEMORY="8192"
DISKSIZE="50"
IPADDRESS="192.168.1.301/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:CA:CH:01"
CLOUD_IMAGE="noble"
MIGRATENODE="pve-cache"
EOF

# 2. Deploy tutto
./vmbuilder-auto.sh infra/

# Risultato: 3 VM create e migrate sui nodi corretti in ~10 minuti
```

### Esempio 2: Development Environment

```bash
# Crea ambiente di sviluppo con 3 VM identiche

./generate-vm-configs.sh
# Risposte:
# Quante VM: 3
# Username: developer
# Password: DevPass123!
# Cores: 2
# Memory: 4096
# Disk: 50
# Image: 1 (Ubuntu 24.04)
# Prefix: dev
# IP Base: 192.168.1
# IP Start: 20
# VMID Start: 120

# Crea: dev-01 (192.168.1.20), dev-02 (.21), dev-03 (.22)

./vmbuilder-auto.sh batch-configs/
```

### Esempio 3: Template per Testing

```bash
# File: test-template.conf
cat > test-vm.conf <<'EOF'
NEWHOSTNAME="test-${RANDOM}"
VMID=""
USER="tester"
PASSWORD="TestPass123!"
SSH_KEY_PATH="/home/vmbuilder/ubuntu_key.pub"
CORES="2"
MEMORY="2048"
DISKSIZE="20"
IPADDRESS="192.168.1.${RANDOM_IP}/32"
GATEWAY="192.168.1.254"
MACADDRESS="52:54:00:TE:${RANDOM_MAC1}:${RANDOM_MAC2}"
CLOUD_IMAGE="noble"
AUTOSTART="N"
PROTECTVM="N"
EOF

# Genera VM random per test
RANDOM_IP=$((50 + RANDOM % 50))
RANDOM_MAC1=$(printf "%02X" $((RANDOM % 256)))
RANDOM_MAC2=$(printf "%02X" $((RANDOM % 256)))
envsubst < test-vm.conf > test-current.conf

./vmbuilder-auto.sh test-current.conf
```

### Esempio 4: Disaster Recovery

```bash
# Hai VM di produzione: backup delle config

# 1. Estrai config da VM esistenti
for vmid in 101 102 103 201 202; do
    qm config $vmid > backup-configs/vm-${vmid}.txt
done

# 2. Converti in formato config file (script helper)
cat > convert-qm-to-conf.sh <<'EOF'
#!/bin/bash
VMID=$1
qm config $VMID > /tmp/qm-$VMID.txt

HOSTNAME=$(grep "^name:" /tmp/qm-$VMID.txt | cut -d: -f2 | xargs)
CORES=$(grep "^cores:" /tmp/qm-$VMID.txt | cut -d: -f2 | xargs)
MEMORY=$(grep "^memory:" /tmp/qm-$VMID.txt | cut -d: -f2 | xargs)
IP=$(grep "^ipconfig0:" /tmp/qm-$VMID.txt | cut -d, -f1 | cut -d= -f2)
GW=$(grep "^ipconfig0:" /tmp/qm-$VMID.txt | cut -d, -f2 | cut -d= -f2)
USER=$(grep "^ciuser:" /tmp/qm-$VMID.txt | cut -d: -f2 | xargs)

# Genera file config per re-deploy
cat > dr-configs/${HOSTNAME}.conf <<CONF
NEWHOSTNAME="$HOSTNAME"
VMID="$VMID"
USER="$USER"
PASSWORD="RecoveryPass!"
SSH_KEY_PATH="/root/.ssh/id_rsa.pub"
CORES="$CORES"
MEMORY="$MEMORY"
DISKSIZE="100"
IPADDRESS="$IP"
GATEWAY="$GW"
MACADDRESS="52:54:00:DR:$(printf '%02X:%02X' $((VMID / 256)) $((VMID % 256)))"
CLOUD_IMAGE="noble"
CONF
EOF

chmod +x convert-qm-to-conf.sh

# 3. In caso di disaster, re-deploy rapido
./vmbuilder-auto.sh dr-configs/
```

---

## Integrazione CI/CD

### GitLab CI Example

```yaml
# .gitlab-ci.yml
stages:
  - validate
  - deploy

validate-configs:
  stage: validate
  script:
    - |
      for conf in vm-configs/*.conf; do
        echo "Validating $conf"
        source "$conf"
        [ -n "$NEWHOSTNAME" ] || exit 1
        [ -n "$IPADDRESS" ] || exit 1
      done

deploy-vms:
  stage: deploy
  only:
    - main
  script:
    - scp -r vm-configs root@proxmox:/tmp/
    - scp vmbuilder-auto.sh root@proxmox:/tmp/
    - ssh root@proxmox "cd /tmp && ./vmbuilder-auto.sh vm-configs/"
```

### Ansible Integration

```yaml
# playbook.yml
- name: Deploy Proxmox VMs
  hosts: proxmox
  tasks:
    - name: Copy VM configs
      copy:
        src: "{{ item }}"
        dest: /tmp/vm-configs/
      with_fileglob:
        - "configs/*.conf"
    
    - name: Deploy VMs
      command: /usr/local/bin/vmbuilder-auto.sh /tmp/vm-configs/
```

---

## Tips & Tricks

### 1. Verifica prima di creare

```bash
# Dry-run: controlla file senza creare VM
for conf in batch-configs/*.conf; do
    echo "=== $conf ==="
    grep "^NEWHOSTNAME\|^IPADDRESS\|^VMID" "$conf"
done
```

### 2. Backup automatico config

```bash
# Salva config dopo ogni creazione
cp my-vm.conf backups/my-vm-$(date +%Y%m%d-%H%M%S).conf
```

### 3. Template con variabili

```bash
# Usa envsubst per template
export VM_NUM=5
export IP_LAST=105
envsubst < template.conf > vm-${VM_NUM}.conf
```

### 4. Log creazione

```bash
# Salva output in log
./vmbuilder-auto.sh batch-configs/ 2>&1 | tee deployment-$(date +%Y%m%d).log
```

### 5. Password da file esterno

```bash
# Non mettere password in chiaro nel config
# config.conf:
PASSWORD="$(cat /secure/passwords/vm-password.txt)"
```

---

## Troubleshooting

### Config file non valido

```bash
# Verifica sintassi
bash -n my-vm.conf

# Test caricamento
source my-vm.conf
echo "Hostname: $NEWHOSTNAME"
```

### MAC address duplicati

```bash
# Trova duplicati
grep -h "^MACADDRESS=" batch-configs/*.conf | sort | uniq -d
```

### IP duplicati

```bash
# Trova duplicati
grep -h "^IPADDRESS=" batch-configs/*.conf | sort | uniq -d
```

### VMID già in uso

```bash
# Lista VMID in uso
pvesh get /cluster/resources --type vm | grep vmid

# Lista VMID nei config
grep "^VMID=" batch-configs/*.conf | grep -v 'VMID=""'
```

---

## Variabili di Configurazione - Reference

| Variabile | Tipo | Default | Esempio | Note |
|-----------|------|---------|---------|------|
| NEWHOSTNAME | string | - | "web-01" | Obbligatorio |
| VMID | string | auto | "101" | Vuoto = auto-assign |
| USER | string | - | "admin" | Obbligatorio |
| PASSWORD | string | - | "Pass123!" | Hashato con SHA-512 |
| SSH_KEY_PATH | path | - | "/root/.ssh/id_rsa.pub" | Deve esistere |
| CORES | number | - | "4" | CPU cores |
| MEMORY | number | - | "4096" | MB di RAM |
| DISKSIZE | number | - | "50" | GB di disco |
| IPADDRESS | ip/cidr | - | "192.168.1.100/32" | Deve finire /32 |
| GATEWAY | ip | - | "192.168.1.254" | Deve finire .254 |
| MACADDRESS | mac | - | "52:54:00:AA:BB:CC" | Formato xx:xx:xx:xx:xx:xx |
| CLOUD_IMAGE | string | - | "noble" | Vedi lista sopra |
| VMSTORAGE | string | local | "ceph" | Storage Proxmox |
| VMBRIDGE | string | vmbr0 | "vmbr1" | Bridge di rete |
| NAMESERVER | string | 213.186.33.99 | "8.8.8.8" | DNS server |
| SEARCHDOMAIN | string | local | "mydomain.com" | Search domain |
| AUTOSTART | Y/N | Y | "N" | Start dopo creazione |
| PROTECTVM | Y/N | N | "Y" | Protezione VM |
| MIGRATENODE | string | - | "pve2" | Migra dopo creazione |

---

## Best Practices

1. **Versiona i file di configurazione** (Git)
2. **Usa password manager** per generare password sicure
3. **Testa sempre con una VM** prima del batch
4. **Backup dei config** prima di modifiche massive
5. **Nomenclatura consistente** per hostname e VMID
6. **Documenta** le scelte di configurazione
7. **Automatizza backup** delle configurazioni
