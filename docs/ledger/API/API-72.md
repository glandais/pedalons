---
id: API-72
title: "Contraintes CHECK des enums vérifiées contre Flyway"
status: done
size: "S"
group: "Extension Karoo : ce que le découpage de novembre 2026 a figé sans le corriger"
done: 2026-11-17
---

## Livré

`API-72` **Contraintes CHECK des enums vérifiées contre Flyway (S)** — les tests construisent le schéma depuis les
entités (`%test.quarkus.flyway.migrate-at-start=false`) : un enum stocké en texte qui gagnait une valeur sans
migration passait toute la suite et cassait en prod (`API-71`). `EnumCheckConstraintsTest` applique désormais
`db/migration` sur une base PostGIS vierge (Testcontainers, l'image `postgres` du compose), lit chaque contrainte
CHECK à une colonne qui liste des valeurs (`pg_constraint`), et la compare à l'enum que Hibernate associe à cette
colonne — table et colonne lues dans le métamodèle (`SessionFactoryImplementor.getMappingMetamodel`), pas
devinées. Une valeur Java absente de la contrainte fait échouer le test, avec la colonne, l'enum et les valeurs
manquantes. Éprouvé à l'envers : une valeur ajoutée à `ThemePreference` sans migration le fait échouer sur
`users.theme`. Au 17 novembre 2026, toutes les contraintes migrées sont alignées. Pas de changement de contrat.

À ne pas défaire :

- **Une valeur que la contrainte garde après que l'enum l'a perdue ne fait pas échouer** : pendant un déploiement
  roulant, la version précédente peut encore l'écrire, et des lignes la portent encore.
- **Le test se garde lui-même** : il exige d'avoir comparé `auth_tokens.token_type`, `gps_route_syncs.last_error`,
  `users.unit_system` et `users.theme`, pour qu'une lecture faussée du métamodèle ne passe pas en ne comparant rien.
- Un enum en `@ElementCollection` n'est pas couvert (il n'y en a aucun aujourd'hui).
