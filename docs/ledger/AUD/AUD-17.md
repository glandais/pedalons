---
id: AUD-17
title: "Index en double retirés"
status: done
done: 2026-09-30
---

## Livré

| ID | Thème | Audit | Gravité | Livré |
|---|---|---|---|---|
| `AUD-17` | Backend | B15 | Mineur | **Index en double retirés** (2026-09-30) — V5 déclarait `device_code_hash` et `user_code` `UNIQUE`, ce qui crée déjà un index pour chacune (`device_codes_device_code_hash_key`, `device_codes_user_code_key`), puis ajoutait `idx_device_codes_device_code_hash` et `idx_device_codes_user_code` par-dessus. `V46__drop_redundant_device_codes_indexes.sql` les supprime (`DROP INDEX IF EXISTS`) ; `idx_device_codes_expires_at`, qui sert au ménage, reste. Ne pas les recréer : l'unicité suffit aux recherches par hash et par code. Pas de test : les tests backend montent le schéma en `drop-and-create` depuis les entités, sans Flyway, donc la migration n'y passe pas ; elle joue au prochain démarrage en production (`validate`, qui ne regarde pas les index) |
