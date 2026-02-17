# Guida: convert-to-integrated-cloudinit.sh

## Cosa fa questo script

Converte le VM Proxmox esistenti che usano **file YAML esterni** (`/var/lib/vz/snippets/`) al sistema **cloud-init integrato** di Proxmox, dove tutta la configurazione viene salvata direttamente nel file della VM (`/etc/pve/qemu-server/<VMID>.conf`).

```
PRIMA                                  DOPO
─────────────────────────────────────────────────────────
/etc/pve/qemu-server/123.conf          /etc/pve/qemu-server/123.conf
  cicustom: local:snippets/123.yaml      ciuser: admin
                                         cipassword: $6$...
/var/lib/vz/snippets/123.yaml            ipconfig0: ip=192.168.1.50/32,...
  #cloud-config                           nameserver: 213.186.33.99
  hostname: myserver                      sshkeys: ssh-rsa AAAA...
  user: admin
  password: $1$...                      /var/lib/vz/snippets/
  ...                                     (nessun file necessario)
```

Il vantaggio principale è che la configurazione cloud-init viene **inclusa automaticamente nei backup PBS**, eliminando la necessità di gestire i file YAML separatamente.

---

## Prerequisiti

- Accesso root al nodo Proxmox
- Script presente sul nodo Proxmox (o su tutti i nodi del cluster)
- File YAML esistenti in `/var/lib/vz/snippets/` con nome `<VMID>.yaml`

```bash
# Verifica che i prerequisiti siano soddisfatti
ls /var/lib/vz/snippets/
# Output atteso: 102.yaml 103.yaml 104.yaml ...

# Controlla che lo script sia eseguibile
chmod +x convert-to-integrated-cloudinit.sh
```

---

## Utilizzo

### Sintassi

```bash
./convert-to-integrated-cloudinit.sh <VMID>
./convert-to-integrated-cloudinit.sh all
```

### Modalità 1 — Singola VM

Converte una sola VM specificando il suo ID:

```bash
./convert-to-integrated-cloudinit.sh 123
```

### Modalità 2 — Tutte le VM

Converte in sequenza tutte le VM che hanno un file YAML in `/var/lib/vz/snippets/`:

```bash
./convert-to-integrated-cloudinit.sh all
```

### Senza argomenti — Messaggio d'uso

```bash
./convert-to-integrated-cloudinit.sh
# Output:
# Uso: ./convert-to-integrated-cloudinit.sh <VMID>
#      ./convert-to-integrated-cloudinit.sh all
# Esempio: ./convert-to-integrated-cloudinit.sh 123
```

---

## Cosa estrae dallo YAML

Lo script legge automaticamente queste informazioni dal file YAML esistente:

| Campo YAML | Parametro Proxmox | Note |
|---|---|---|
| `hostname` | (informativo) | Solo mostrato a video |
| `user` | `--ciuser` | Username principale |
| `password` | `--cipassword` | Usato l'hash già presente |
| `ssh_authorized_keys` | `--sshkeys` | Supporta rsa, ed25519, ecdsa |
| `addresses` (rete) | `--ipconfig0` | IP con subnet |
| `via` (routes) | `--ipconfig0` | Gateway |
| `nameservers` | `--nameserver` | Server DNS |

> **Nota:** Lo script estrae solo i campi supportati dal cloud-init integrato di Proxmox. Configurazioni avanzate presenti nello YAML (come `write_files`, `runcmd` complessi, `packages`) non vengono migrate automaticamente.

---

## Flusso di Esecuzione — Singola VM

Quando esegui lo script su una VM, avviene questo in sequenza:

### Step 1 — Verifica prerequisiti
```
Conversione VM 123
==========================================
```
Lo script controlla che:
- La VM esista in Proxmox (`qm status 123`)
- Il file `/var/lib/vz/snippets/123.yaml` esista

### Step 2 — Avviso VM in esecuzione
Se la VM è accesa, lo script avvisa e chiede conferma:
```
AVVISO: VM 123 è in esecuzione
Vuoi continuare comunque? (y/N):
```
> Puoi procedere con la VM accesa. La configurazione cloud-init aggiornata verrà applicata al prossimo riavvio, non immediatamente.

### Step 3 — Backup automatico
```
Backup creato: /var/lib/vz/snippets-backup-20260217/123.yaml
```
Il file YAML originale viene copiato in una directory di backup con la data odierna. **Il file originale non viene mai toccato in questo step.**

### Step 4 — Estrazione e anteprima
```
Configurazioni estratte:
  Hostname: myserver
  User: admin
  Password: [HASH]
  SSH Key: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB...
  IP: 192.168.1.50/32
  Gateway: 192.168.1.254
  Nameserver: 213.186.33.99
```
Poi mostra la configurazione cloud-init attuale della VM:
```
Configurazione cloud-init attuale della VM:
  cicustom: local:snippets/123.yaml
```

### Step 5 — Conferma
```
Procedere con la conversione? (y/N):
```
Digita `y` per procedere. Con `N` o Invio lo script esce senza modificare nulla.

### Step 6 — Applicazione configurazione
```
Applicazione configurazioni cloud-init integrate...
  Configurazione utente: admin
  Configurazione password
  Configurazione SSH key
  Configurazione rete: IP=192.168.1.50/32, GW=192.168.1.254
  Configurazione DNS: 213.186.33.99
  Rimozione riferimento a snippet custom
```
Vengono eseguiti in ordine:
- `qm set 123 --ciuser "admin"`
- `qm set 123 --cipassword "$HASH"`
- `qm set 123 --sshkeys /tmp/sshkey-123.tmp`
- `qm set 123 --ipconfig0 "ip=192.168.1.50/32,gw=192.168.1.254"`
- `qm set 123 --nameserver "213.186.33.99"`
- `qm set 123 --delete cicustom`

### Step 7 — Riepilogo finale
```
Conversione completata per VM 123!
==========================================
Configurazione finale:
cipassword: $6$rounds=5000$...
ciuser: admin
ipconfig0: ip=192.168.1.50/32,gw=192.168.1.254
nameserver: 213.186.33.99
sshkeys: ssh-rsa%20AAAA...
```

### Step 8 — Rimozione YAML (opzionale)
```
Vuoi rimuovere il file YAML snippet ora? (y/N):
```
- `y` → elimina `/var/lib/vz/snippets/123.yaml`
- `N` → il file rimane, puoi eliminarlo manualmente dopo aver verificato

---

## Flusso di Esecuzione — Modalità `all`

Con `./convert-to-integrated-cloudinit.sh all` lo script:

1. Cerca tutti i file con pattern `/var/lib/vz/snippets/<numero>.yaml`
2. Mostra la lista trovata e il numero totale
3. Chiede conferma globale prima di iniziare
4. Per ogni VM esegue la conversione singola (stesso flusso descritto sopra)
5. Dopo ogni VM, aspetta che tu prema **Invio** prima di passare alla successiva
6. Se una conversione fallisce, lo segnala e continua con la prossima
7. Al termine, mostra il riepilogo con la directory di backup

```bash
# Esempio output modalità all
Ricerca di tutte le VM con snippet YAML...
File YAML trovati:
/var/lib/vz/snippets/102.yaml
/var/lib/vz/snippets/103.yaml
/var/lib/vz/snippets/104.yaml
...

Trovate 10 VM con snippet YAML
Procedere con la conversione di tutte? (y/N): y

# Poi elabora una VM per volta, attendendo Invio tra una e l'altra
```

---

## Backup

I file YAML originali vengono copiati **prima** di qualsiasi modifica in:

```
/var/lib/vz/snippets-backup-YYYYMMDD/
```

Dove `YYYYMMDD` è la data del giorno in cui esegui lo script.

```bash
# Esempio: eseguito il 17 febbraio 2026
/var/lib/vz/snippets-backup-20260217/
  ├── 102.yaml
  ├── 103.yaml
  ├── 104.yaml
  └── ...

# Per ripristinare un backup
cp /var/lib/vz/snippets-backup-20260217/123.yaml /var/lib/vz/snippets/123.yaml
```

> **Nota:** Se esegui lo script due volte nello stesso giorno, i backup vengono sovrascritti nella stessa directory.

---

## Rollback

Se qualcosa va storto dopo la conversione, puoi tornare al sistema YAML in pochi comandi:

```bash
# 1. Ripristina il file YAML dal backup
cp /var/lib/vz/snippets-backup-20260217/123.yaml /var/lib/vz/snippets/123.yaml

# 2. Rimuovi la configurazione cloud-init integrata
qm set 123 --delete ciuser
qm set 123 --delete cipassword
qm set 123 --delete sshkeys
qm set 123 --delete nameserver

# 3. Ripristina il riferimento allo snippet custom
qm set 123 --cicustom "user=local:snippets/123.yaml"

# 4. Verifica
qm config 123 | grep cicustom
# cicustom: local:snippets/123.yaml
```

---

## Limitazioni Importanti

### Configurazioni non migrate automaticamente

Lo script migra solo i campi base. Se i tuoi file YAML contengono configurazioni avanzate, queste **non vengono trasferite**:

```yaml
# Questi blocchi NON vengono migrati dallo script
packages:
  - qemu-guest-agent
  - nginx

runcmd:
  - systemctl restart qemu-guest-agent
  - netplan apply

write_files:
  - path: /etc/netplan/50-cloud-init.yaml
    content: |
      network:
        version: 2
        ...
```

> Se le tue VM dipendono da `runcmd` o `write_files` per funzionare correttamente, **non eliminare il file YAML** finché non hai verificato che la VM funzioni dopo il riavvio.

### Netplan e configurazione di rete

Lo script originale usava `write_files` per scrivere la configurazione netplan. Il cloud-init integrato di Proxmox gestisce la rete in modo nativo, quindi questa parte viene sostituita da `--ipconfig0`. In genere funziona correttamente, ma verifica sempre la connettività di rete dopo la conversione.

### Una sola chiave SSH

Lo script estrae solo la **prima** chiave SSH trovata nel file YAML. Se hai più chiavi configurate, aggiungi le altre manualmente:

```bash
# Verifica chiavi presenti nello YAML
grep -E "ssh-rsa|ssh-ed25519" /var/lib/vz/snippets/123.yaml

# Aggiungi chiave mancante
echo "ssh-rsa AAAA..." >> /tmp/keys-123.pub
qm set 123 --sshkeys /tmp/keys-123.pub
rm /tmp/keys-123.pub
```

### VM sugli altri nodi del cluster

Lo script deve essere eseguito **sul nodo dove si trovano i file YAML** e le configurazioni VM. Se hai un cluster a 5 nodi, i file YAML potrebbero non essere sincronizzati tra i nodi — verifica prima:

```bash
# Sul nodo corrente
ls /var/lib/vz/snippets/

# Controlla dove si trovano le VM
pvesh get /cluster/resources --type vm | grep -E "vmid|node"
```

---

## Procedura Consigliata

### Prima di iniziare

```bash
# 1. Fai un backup manuale completo degli snippet
cp -r /var/lib/vz/snippets/ /root/snippets-backup-manual/

# 2. Elenca le VM con snippet
ls /var/lib/vz/snippets/

# 3. Scegli una VM di test non critica
# (es. una VM di sviluppo)
```

### Test su VM singola

```bash
# 1. Converti una VM di test
./convert-to-integrated-cloudinit.sh 123

# 2. NON eliminare il file YAML quando chiesto (rispondi N)

# 3. Riavvia la VM per applicare la nuova configurazione
qm reboot 123

# 4. Verifica che tutto funzioni
ssh admin@192.168.1.50
ping 8.8.8.8
cat /etc/resolv.conf

# 5. Se tutto OK, elimina il file YAML
rm /var/lib/vz/snippets/123.yaml

# 6. Fai un backup PBS e verifica che includa la config cloud-init
vzdump 123 --storage pbs --mode snapshot
```

### Conversione completa

Una volta verificato il funzionamento su una VM di test:

```bash
# Converti tutte le VM rimanenti
./convert-to-integrated-cloudinit.sh all

# Verifica configurazione di ciascuna VM
for vmid in 102 103 104 112 116 117 119 121 123 124; do
    echo "=== VM $vmid ==="
    qm config $vmid | grep -E "^(ciuser|ipconfig|nameserver)"
done
```

---

## Verifica Post-Conversione

```bash
# Verifica cloud-init integrato di una VM
qm cloudinit dump 123 user

# Verifica configurazione completa
qm config 123

# Controlla che NON ci sia più cicustom
qm config 123 | grep cicustom
# (nessun output = conversione avvenuta correttamente)

# Verifica che il backup PBS ora includa la configurazione
vzdump 123 --storage pbs --mode snapshot --dryrun
```

---

## Troubleshooting

### "ERRORE: VM X non esiste"
La VM non è presente sul nodo corrente. Controlla su quale nodo si trova:
```bash
pvesh get /cluster/resources --type vm | grep "vmid/123"
# Poi esegui lo script dal nodo corretto
```

### "AVVISO: Nessun file YAML trovato"
La VM non ha uno snippet YAML associato, oppure il file ha un nome diverso:
```bash
ls /var/lib/vz/snippets/
# Verifica che esista 123.yaml e non, ad esempio, myserver.yaml
```

### La rete non funziona dopo la conversione
Lo script ha migrato `ipconfig0`, ma potrebbe esserci un conflitto con la configurazione netplan già presente nella VM:
```bash
# Dalla VM
sudo cat /etc/netplan/*.yaml
sudo netplan apply
sudo cloud-init clean && sudo reboot
```

### SSH key non riconosciuta
La chiave potrebbe non essere stata estratta correttamente. Verifica e riapplica:
```bash
# Controlla cosa c'è nel YAML
grep -A 3 "ssh_authorized_keys" /var/lib/vz/snippets-backup-20260217/123.yaml

# Riapplica manualmente
echo "ssh-rsa AAAA..." > /tmp/key.pub
qm set 123 --sshkeys /tmp/key.pub
rm /tmp/key.pub
```

### "Conversione fallita per VM X, continuo..."
In modalità `all`, se una VM fallisce lo script continua con le altre. Esegui poi la VM problematica singolarmente per vedere il messaggio di errore dettagliato:
```bash
./convert-to-integrated-cloudinit.sh 123
```
