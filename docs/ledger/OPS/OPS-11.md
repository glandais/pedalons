---
id: OPS-11
title: "`BACKUP_KEEP` retiré de `.env.example`"
status: done
done: 2026-09-30
---

## Livré

`OPS-11` **`BACKUP_KEEP` retiré de `.env.example`** (2026-09-30) — le modèle de
`/root/pedalons-backup.env` décrivait une variable que rien ne lit : la rétention est le second
argument de `scripts/backup-prune.sh` (30 par défaut), sur l'hôte de sauvegarde, comme le dit
[`OPERATIONS.md`](../../OPERATIONS.md). Pas de test : `grep -rn BACKUP_KEEP` ne trouve plus que ce
ledger.
