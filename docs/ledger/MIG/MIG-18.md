---
id: MIG-18
title: "Une équipe migrée ne peut plus être retirée de Pédalons"
status: open
group: "Autour de la migration"
verified: 2026-11-16
---

## Reste à faire

`MIG-18` **Une équipe migrée ne peut plus être retirée de Pédalons** — dégradation née de
`MIG-16` : `TeamService.delete` refuse toute équipe issue de biketeam (`MIGRATED_TEAM`,
`MIG-5`), admins de plateforme compris, et le reset, seule voie qui la mettait à la corbeille
(sans passer par `TeamService`), n'existe plus. Une copie faite « pour voir » — avec la
visibilité de l'équipe biketeam, donc possiblement listée dans la découverte — reste tant
qu'on n'intervient pas en base ; `MIG-5` justifiait le refus par les redirections de biketeam,
or une équipe migrée mais **non basculée** n'en reçoit aucune, et Pédalons ne sait pas si
biketeam a basculé. À décider par le propriétaire : laisser ainsi (visibilité `TEAM` à la
main en attendant), autoriser la suppression à un admin de plateforme, ou faire dire à
biketeam qu'une équipe est basculée. La mise de côté d'une équipe migrée déjà à la corbeille
(`BiketeamLiveMigrationWorker.setAside`) reste en place pour ce jour-là et pour les équipes
qui y sont déjà.
