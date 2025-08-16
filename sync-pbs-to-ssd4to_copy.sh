#!/bin/bash
set -Eeuo pipefail

### ======= CONFIG =======
PBS_IP="192.168.1.XXX"
SRC="/mnt/datastore/marechal-pbs"      # côté PBS (confirmé)
DST="/mnt/ssd4to/pbs-marechal"         # côté PVE
SSH_KEY="/root/.ssh/id_ed25519"
WEBHOOK="https://discord.com/api/webhooks/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# rsync
RSYNC_BASE_OPTS="-aHAX --numeric-ids --info=progress2 --stats"
RSYNC_SSH_OPTS="-i ${SSH_KEY} -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# log
LOG_DIR="/var/log"
LOG="${LOG_DIR}/sync-pbs-ssd4to_copy_$(date +%F_%H-%M-%S).log"

### ======= FONCTIONS =======
log(){ echo "[$(date -Iseconds)] $*" | tee -a "$LOG"; }

send_discord(){
  local msg="$1" file="$2"
  local content_json; content_json=$(printf "%s" "$msg" | jq -Rs .)
  if [[ -f "$file" ]]; then
    curl -sS -F "payload_json={\"content\":${content_json}}" \
            -F "file=@${file};type=text/plain" "$WEBHOOK" >/dev/null || true
  else
    curl -sS -F "payload_json={\"content\":${content_json}}" "$WEBHOOK" >/dev/null || true
  fi
}

bytes_human(){ numfmt --to=iec --suffix=B --padding=7 "$1"; }

### ======= CHECKS =======
mkdir -p "$LOG_DIR" "$DST"
umask 022
log "▶️ Démarrage COPIE PBS → PVE"
log "PBS_IP=${PBS_IP} | SRC=${SRC} | DST=${DST} | LOG=${LOG}"

# Pré-requis côté PVE
if ! command -v jq >/dev/null 2>&1 || ! command -v rsync >/dev/null 2>&1; then
  log "Installation de jq/rsync (PVE)…"
  apt update -y >>"$LOG" 2>&1
  apt install -y jq rsync >>"$LOG" 2>&1
fi

# Sécurité chemin DST
case "$DST" in
  "/"|"/root"|"/etc"|"/var"|"/home"|"/mnt"|"/mnt/ssd4to"|"")
    log "Chemin DST non sûr: $DST"
    exit 2
  ;;
esac

# Clé SSH
[[ -f "$SSH_KEY" ]] || { log "Clé SSH absente: $SSH_KEY"; exit 3; }

# Connexion SSH
log "Test SSH → PBS…"
ssh -o BatchMode=yes -o ConnectTimeout=8 -i "$SSH_KEY" root@"$PBS_IP" "hostname && whoami" | tee -a "$LOG"

# rsync côté PBS
if ! ssh -i "$SSH_KEY" root@"$PBS_IP" "command -v rsync >/dev/null"; then
  log "Installation de rsync (PBS)…"
  ssh -i "$SSH_KEY" root@"$PBS_IP" "apt update -y && apt install -y rsync" >>"$LOG" 2>&1
fi

# Tailles
SRC_BYTES=$(ssh -i "$SSH_KEY" root@"$PBS_IP" "du -sb \"$SRC\" | cut -f1")
SRC_HUM=$(bytes_human "$SRC_BYTES")
DST_AVAIL_BYTES=$(df -B1 "$DST" | awk 'NR==2{print $4}')
DST_AVAIL_HUM=$(bytes_human "$DST_AVAIL_BYTES")
log "Taille source : ${SRC_HUM} | Espace dispo cible : ${DST_AVAIL_HUM}"

### ======= COPIE UNIQUE (SANS DELETE) =======
log "🟦 Copie (sans --delete)…"
T_START=$(date +%s)
rsync $RSYNC_BASE_OPTS \
  -e "ssh $RSYNC_SSH_OPTS" \
  root@"$PBS_IP":"$SRC"/  "$DST"/ 2>&1 | tee -a "$LOG"
T_END=$(date +%s)
DUR=$((T_END - T_START))
log "✅ Copie terminée en ${DUR}s"

### ======= RÉCAP & DISCORD =======
DST_BYTES=$(du -sb "$DST" | cut -f1)
DST_HUM=$(bytes_human "$DST_BYTES")

SUMMARY=$(
  cat <<EOF
📦 Copie PBS → PVE terminée
• Source : ${PBS_IP}:${SRC}
• Destination : ${DST}
• Taille source : ${SRC_HUM}
• Taille destination : ${DST_HUM}
• Durée : ${DUR}s
• Log : ${LOG}
Horodatage : $(date -Iseconds)

EOF
)
log "Résumé:\n${SUMMARY}"
send_discord "$SUMMARY" "$LOG"
log "🎉 Terminé."
exit 0
