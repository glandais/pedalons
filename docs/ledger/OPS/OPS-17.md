---
id: OPS-17
title: "Les originaux orphelins de `tmp/reencode/` expirent en un jour"
status: done
done: 2026-09-30
---

## Livré

`OPS-17` **Les originaux orphelins de `tmp/reencode/` expirent en un jour** (2026-09-30) — au
lieu d'un `mc ilm rule add` à passer à la main sur chaque environnement,
`S3StorageService.init` pose la règle au démarrage, juste après le contrôle du bucket :
expiration à 1 jour sur `REENCODE_PREFIX` (règle `expire-reencode-originals`), si bien que
production, staging, pile locale et pile e2e l'ont sans geste. Elle **remplace** la configuration
de cycle de vie du bucket, qui n'en porte pas d'autre : une règle ajoutée un jour à la main
serait effacée au redémarrage suivant — l'ajouter dans ce code. Un échec est journalisé en WARN,
pas fatal. Vérifié contre le MinIO local (`pgsty/minio`) avec le SDK du backend : règle acceptée,
relue, appel répété idempotent ; puis sur la pile e2e, où le backend reconstruit l'a posée au
démarrage (`mc ilm rule ls`). Pas de test automatisé.
