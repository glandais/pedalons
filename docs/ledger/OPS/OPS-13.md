---
id: OPS-13
title: "Sauvegardes chiffrées au repos"
status: done
done: 2026-09-29
---

## Livré

`OPS-13` **Sauvegardes chiffrées au repos** (2026-09-29, relevé avec `LEGAL-12`) — les 30 copies
nocturnes étaient en clair sur l'hôte de sauvegarde, au domicile du responsable, `ENCRYPTION_KEY`
comprise dans le même lot que la base : un vol du matériel était une violation à notifier à
chaque membre (art. 34). Deux couches, retenues ensemble :
- **à la source** : `scripts/backup.sh` chiffre `postgres.dump.age` et `secrets.tar.gz.age` en
  flux avec `age` vers une clé publique (`BACKUP_AGE_RECIPIENT`, obligatoire : sans elle, pas de
  sauvegarde plutôt qu'une sauvegarde en clair) ; la clé privée est hors ligne et
  `scripts/restore.sh` l'exige (`BACKUP_AGE_IDENTITY`). Le gpg symétrique optionnel, jamais
  activé en production, est retiré. Pas de compatibilité avec les anciennes copies ;
- **sur l'hôte** : `<backup-root>` est le point de montage d'un conteneur LUKS2 (fichier sur le
  SSD, déverrouillé à la main par SSH après redémarrage, jamais par TPM ni fichier de clé local),
  qui protège `minio/`. Le point de montage sous-jacent est `chattr +i` : conteneur fermé, les
  sauvegardes échouent au lieu d'écrire en clair. Les copies en clair ont été recopiées
  (`rsync -aH`), supprimées, et le SSD trimé.

`minio/` n'est **pas** chiffré à la source : ça casserait l'incrémental `--link-dest`, c'est le
rôle de LUKS — ne pas « compléter » le chiffrement age en y passant MinIO. §6 et §9 de la
politique réécrits, ainsi que la phrase du runbook qui prétendait que la production ne peut pas
supprimer son historique (elle le peut : `SEC-16`). Pas de rotation des secrets déjà exposés :
`OPS-18`. Pas de test automatisé (scripts d'exploitation) : vérifié à la main le 29 septembre
2026 — copie de la production écrite dans le volume chiffré, taille inchangée (liens durs
conservés).
