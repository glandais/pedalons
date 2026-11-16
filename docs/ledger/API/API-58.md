---
id: API-58
title: "La colonne `auth_tokens.pending_password_hash` est supprimée"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-01
---

## Livré

`API-58` **La colonne `auth_tokens.pending_password_hash` est supprimée** (2026-10-01, migration
`V54__drop_pending_password_hash.sql`, contrat inchangé) — livrée une release après `API-57`,
une fois 10.0.0 déployée en prod et en staging : pendant le recouvrement start-first, la release
précédente (10.0.0) ne mappe plus la colonne. Les tests ne passent pas par Flyway (schéma
généré depuis les entités) : la migration a été vérifiée sur la base locale, dans une
transaction annulée. **À ne pas défaire** : ne pas réintroduire de mot de passe stocké avant la
vérification de l'e-mail (`SEC-24`).
