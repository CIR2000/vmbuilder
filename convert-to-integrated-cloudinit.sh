#!/bin/bash
# Script per convertire VM esistenti da YAML snippet a cloud-init integrato
# 
# ATTENZIONE: Testa prima su una VM non critica!
#
# Uso: ./convert-to-integrated-cloudinit.sh [VMID]
#       ./convert-to-integrated-cloudinit.sh all (converte tutte le VM con snippet)

set -e

SNIPPETS_DIR="/var/lib/vz/snippets"
BACKUP_DIR="/var/lib/vz/snippets-backup-$(date +%Y%m%d)"

# Funzione per estrarre valori da YAML
get_yaml_value() {
    local file=$1
    local key=$2
    grep "^${key}:" "$file" | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

# Funzione per convertire una singola VM
convert_vm() {
    local VMID=$1
    local YAML_FILE="$SNIPPETS_DIR/${VMID}.yaml"
    
    echo "=========================================="
    echo "Conversione VM $VMID"
    echo "=========================================="
    
    # Verifica che la VM esista
    if ! qm status $VMID &>/dev/null; then
        echo "ERRORE: VM $VMID non esiste"
        return 1
    fi
    
    # Verifica che il file YAML esista
    if [ ! -f "$YAML_FILE" ]; then
        echo "AVVISO: Nessun file YAML trovato per VM $VMID"
        return 1
    fi
    
    echo "File YAML trovato: $YAML_FILE"
    
    # Verifica che la VM sia spenta (opzionale, ma consigliato)
    VM_STATUS=$(qm status $VMID | awk '{print $2}')
    if [ "$VM_STATUS" == "running" ]; then
        echo "AVVISO: VM $VMID è in esecuzione"
        read -p "Vuoi continuare comunque? (y/N): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            echo "Conversione annullata"
            return 1
        fi
    fi
    
    # Backup del file YAML
    mkdir -p "$BACKUP_DIR"
    cp "$YAML_FILE" "$BACKUP_DIR/"
    echo "Backup creato: $BACKUP_DIR/${VMID}.yaml"
    
    # Estrai configurazioni dal YAML
    echo "Estrazione configurazioni dal YAML..."
    
    HOSTNAME=$(get_yaml_value "$YAML_FILE" "hostname")
    USER=$(get_yaml_value "$YAML_FILE" "user")
    PASSWORD=$(get_yaml_value "$YAML_FILE" "password")
    
    # Estrai SSH key (può essere su più righe)
    SSH_KEY=$(awk '/ssh_authorized_keys:/,/chpasswd:/' "$YAML_FILE" | grep -E "ssh-rsa|ssh-ed25519|ecdsa-sha2" | sed 's/^[[:space:]]*-[[:space:]]*//' | head -1)
    
    # Estrai configurazione di rete (se presente)
    IP_ADDRESS=$(grep -A 20 "addresses:" "$YAML_FILE" | grep -E "^[[:space:]]*-[[:space:]]*[0-9]" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//')
    GATEWAY=$(grep -A 30 "routes:" "$YAML_FILE" | grep "via:" | head -1 | awk '{print $2}')
    NAMESERVER=$(grep -A 30 "nameservers:" "$YAML_FILE" | grep -E "^[[:space:]]*-[[:space:]]*[0-9]" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*//')
    
    echo "Configurazioni estratte:"
    echo "  Hostname: $HOSTNAME"
    echo "  User: $USER"
    echo "  Password: [HASH]"
    [ -n "$SSH_KEY" ] && echo "  SSH Key: ${SSH_KEY:0:50}..."
    [ -n "$IP_ADDRESS" ] && echo "  IP: $IP_ADDRESS"
    [ -n "$GATEWAY" ] && echo "  Gateway: $GATEWAY"
    [ -n "$NAMESERVER" ] && echo "  Nameserver: $NAMESERVER"
    
    # Verifica configurazione attuale
    echo ""
    echo "Configurazione cloud-init attuale della VM:"
    qm config $VMID | grep -E "^(ciuser|cipassword|sshkeys|ipconfig|nameserver|searchdomain|cicustom)" || echo "  Nessuna configurazione cloud-init integrata trovata"
    
    echo ""
    read -p "Procedere con la conversione? (y/N): " PROCEED
    if [[ ! $PROCEED =~ ^[Yy]$ ]]; then
        echo "Conversione annullata"
        return 1
    fi
    
    # Applica configurazioni cloud-init integrate
    echo ""
    echo "Applicazione configurazioni cloud-init integrate..."
    
    # User
    if [ -n "$USER" ]; then
        echo "  Configurazione utente: $USER"
        qm set $VMID --ciuser "$USER"
    fi
    
    # Password (già hashata nel YAML)
    if [ -n "$PASSWORD" ]; then
        echo "  Configurazione password"
        qm set $VMID --cipassword "$PASSWORD"
    fi
    
    # SSH Keys
    if [ -n "$SSH_KEY" ]; then
        echo "  Configurazione SSH key"
        TEMP_KEY="/tmp/sshkey-${VMID}.tmp"
        echo "$SSH_KEY" > "$TEMP_KEY"
        qm set $VMID --sshkeys "$TEMP_KEY"
        rm -f "$TEMP_KEY"
    fi
    
    # Network configuration
    if [ -n "$IP_ADDRESS" ] && [ -n "$GATEWAY" ]; then
        echo "  Configurazione rete: IP=$IP_ADDRESS, GW=$GATEWAY"
        qm set $VMID --ipconfig0 "ip=${IP_ADDRESS},gw=${GATEWAY}"
    fi
    
    # DNS
    if [ -n "$NAMESERVER" ]; then
        echo "  Configurazione DNS: $NAMESERVER"
        qm set $VMID --nameserver "$NAMESERVER"
    fi
    
    # Rimuovi riferimento al custom snippet
    echo "  Rimozione riferimento a snippet custom"
    qm set $VMID --delete cicustom 2>/dev/null || true
    
    echo ""
    echo "=========================================="
    echo "Conversione completata per VM $VMID!"
    echo "=========================================="
    echo ""
    echo "Configurazione finale:"
    qm config $VMID | grep -E "^(ciuser|cipassword|sshkeys|ipconfig|nameserver|searchdomain)"
    
    echo ""
    echo "IMPORTANTE:"
    echo "1. Verifica che la configurazione sia corretta"
    echo "2. Testa la VM prima di rimuovere il file YAML"
    echo "3. Il file YAML originale è stato salvato in: $BACKUP_DIR/${VMID}.yaml"
    echo ""
    
    # Chiedi se eliminare il file YAML
    read -p "Vuoi rimuovere il file YAML snippet ora? (y/N): " DELETE_YAML
    if [[ $DELETE_YAML =~ ^[Yy]$ ]]; then
        rm "$YAML_FILE"
        echo "File $YAML_FILE rimosso"
    else
        echo "File YAML mantenuto. Puoi rimuoverlo manualmente dopo aver verificato che tutto funzioni"
    fi
    
    echo ""
}

# Funzione per convertire tutte le VM
convert_all() {
    echo "Ricerca di tutte le VM con snippet YAML..."
    
    local yaml_files=$(ls -1 "$SNIPPETS_DIR"/*.yaml 2>/dev/null | grep -E '/[0-9]+\.yaml$' || true)
    
    if [ -z "$yaml_files" ]; then
        echo "Nessun file YAML snippet trovato in $SNIPPETS_DIR"
        exit 0
    fi
    
    echo "File YAML trovati:"
    echo "$yaml_files"
    echo ""
    
    local count=0
    for yaml_file in $yaml_files; do
        local vmid=$(basename "$yaml_file" .yaml)
        count=$((count + 1))
    done
    
    echo "Trovate $count VM con snippet YAML"
    read -p "Procedere con la conversione di tutte? (y/N): " PROCEED_ALL
    
    if [[ ! $PROCEED_ALL =~ ^[Yy]$ ]]; then
        echo "Operazione annullata"
        exit 0
    fi
    
    for yaml_file in $yaml_files; do
        local vmid=$(basename "$yaml_file" .yaml)
        echo ""
        convert_vm "$vmid" || echo "Conversione fallita per VM $vmid, continuo..."
        echo ""
        read -p "Premi INVIO per continuare con la prossima VM..."
    done
    
    echo ""
    echo "=========================================="
    echo "Conversione completata!"
    echo "=========================================="
    echo "Backup di tutti i file YAML: $BACKUP_DIR/"
}

# Main script
if [ "$#" -eq 0 ]; then
    echo "Uso: $0 <VMID>"
    echo "     $0 all       (converti tutte le VM con snippet)"
    echo ""
    echo "Esempio: $0 123"
    exit 1
fi

if [ "$1" == "all" ]; then
    convert_all
else
    convert_vm "$1"
fi
