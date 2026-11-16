---
id: OPS-53
title: "Chaque environnement basculé sur PostgreSQL 18"
status: done
done: 2026-10-25
---

## Livré

`OPS-53` **Chaque environnement basculé sur PostgreSQL 18** (scindé d'`OPS-19`, 2026-10-25) —
`scripts/postgres-upgrade.sh` lancé sur `tribly-local` (5 bases, 156 tables), en staging (5 bases,
166 tables) puis en production (base `goatcounter` comprise), chacun après une sauvegarde. Vérifié
le jour même : PostgreSQL 18.1, PostGIS 3.6.1, `data_checksums` à `on`, 78 migrations Flyway
réussies, tous les services healthy, aucune erreur dans les logs, `/q/health/ready` à `UP`. Les
volumes 17 (`pedalons-prod_postgres_data`, `pedalons-staging_postgres_data`,
`tribly_postgres_data`) sont supprimés : le retour arrière par le commit précédent n'existe plus,
seules les sauvegardes restent. En staging, le ménage final de `deploy.sh` a échoué sur une vieille
build encore tenue par le backend arrêté pendant la copie, après une bascule pourtant réussie :
`deploy.sh` garde désormais une telle image au lieu d'échouer. `tribly-e2e_postgres_data`, encore
monté par une pile e2e en marche, se supprime à la main après `scripts/e2e.sh down` : le
`down -v` de `reset` ne retire que les volumes que le fichier déclare encore.
