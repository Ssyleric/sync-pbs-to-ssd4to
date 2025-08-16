# 📦 Sync PBS → PVE vers SSD4To

Ce projet automatise la **synchronisation des backups Proxmox Backup Server (PBS)** vers le disque local `/mnt/ssd4to` de ton hôte **PVE**.

---

## 🚀 Fonctionnement

- **Source** : Datastore PBS `marechal-pbs` (`/mnt/datastore/marechal-pbs`) sur la VM PBS `192.168.1.101`.
- **Destination** : `/mnt/ssd4to/pbs-marechal` sur l’hôte PVE.
- **Méthode** : `rsync` via clé SSH (`/root/.ssh/id_ed25519`).
- **Mode** : copie **sans suppression** → ne copie que les fichiers nouveaux ou modifiés (aucun risque sur les anciens).
- **Reporting** : chaque run envoie un résumé + le log complet en **Discord Webhook**.

---

## 📂 Scripts

- `/home/scripts/sync-pbs-to-ssd4to_copy.sh`→ **Copie réelle** (production).
- `/home/scripts/sync-pbs-to-ssd4to_copy_dryrun.sh`
  → **Simulation** (aucune donnée copiée, permet de voir les deltas).

---

## 📝 Exemple de rapport Discord

```
📦 Copie PBS → PVE terminée
• Source : 192.168.1.101:/mnt/datastore/marechal-pbs
• Destination : /mnt/ssd4to/pbs-marechal
• Taille source :   770GB
• Taille destination :   770GB
• Durée : 1420s
• Log : /var/log/sync-pbs-ssd4to_copy_2025-08-16_14-30-00.log
Horodatage : 2025-08-16T14:59:20
```

*(+ log complet en pièce jointe)*

---

## ⚙️ Crontab

Édite ta crontab (`crontab -e`) :

```cron
# Dry-run le dimanche 07h00
0 7 * * 0 bash /home/scripts/sync-pbs-to-ssd4to_copy_dryrun.sh >/dev/null 2>&1
# Copie réelle le dimanche 08h00
0 8 * * 0 bash /home/scripts/sync-pbs-to-ssd4to_copy.sh >/dev/null 2>&1
```

---

## 📊 Vitesse & Deltas

- **Premier run** : copie complète (longue).
- **Runs suivants** : ne copient **que les nouveaux snapshots** (généralement quelques Go).
- Exemple vitesse : `108 MB/s ≈ 6.5 Go/minute`.

---

## 🔒 Sécurité

- **Pas de suppression** (`--delete` non utilisé).
- **Pas d’arrêt/restart** de services PBS (aucune perturbation).
- **Clé SSH dédiée** déjà installée : `/root/.ssh/id_ed25519`.

---

## 📁 Logs

- Tous les runs sont loggés dans `/var/log/` :
  - `sync-pbs-ssd4to_copy_*.log`
  - `sync-pbs-ssd4to_copy_dryrun_*.log`

---

## ✅ Résumé

- **Facile** : 1 script = copie, 1 script = test.
- **Fiable** : rsync copie seulement ce qui a changé.
- **Sécurisé** : pas de delete, pas de services arrêtés.
- **Supervisé** : rapport + log envoyés automatiquement sur Discord.

---
