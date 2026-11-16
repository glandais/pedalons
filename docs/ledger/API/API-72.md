---
id: API-72
title: "Contraintes CHECK des enums vérifiées contre Flyway"
status: open
size: "S"
group: "Extension Karoo : ce que le découpage de novembre 2026 a figé sans le corriger"
verified: 2026-11-16
---

## Reste à faire

`API-72` **Contraintes CHECK des enums vérifiées contre Flyway (S)** — les tests construisent
le schéma depuis les entités (`%test.quarkus.flyway.migrate-at-start=false`) : un enum persisté
en `varchar` qui gagne une valeur sans migration passe toute la suite et casse en prod (`API-71`).
Un test qui applique `db/migration` sur une base PostGIS vierge (TestContainers) et compare chaque
contrainte `…_check` aux valeurs de l'enum Java correspondant (`AuthTokenType`, `AssetType`,
`GpsSyncError`, `service_type`, `platform_role`, `unit_system`, `theme`, `visibility`,
`status`…) supprimerait cette classe de défaut. Elle s'étend : V71 a ajouté
`ck_gps_route_syncs_last_error` (`GpsSyncError`), et `API-103` tomberait dans ce piège. Au
16 octobre 2026, les CHECK de la prod sont alignés sur les enums Java.
