---
id: BILL-10
title: "Limites de l'offre gratuite, déblocage d'une équipe à la main"
status: done
done: 2026-11-12
---

## Livré

`BILL-10` **Limites de l'offre gratuite, déblocage d'une équipe à la main** (2026-11-12, contrat
`14.2.0` à `14.5.0`, migrations `V89` et `V90`) — plan
[`plans/archive/2026-11-11-limites-offre-gratuite.md`](../../plans/archive/2026-11-11-limites-offre-gratuite.md).
- **Paliers** : `Team.tier` FREE | UNLOCKED et une note `tierNote`, que seul l'admin plateforme
  change (`PATCH /api/admin/teams/{id}/attributes`, champs omis = inchangés ; filtre `tier` sur
  `GET /api/admin/teams`, colonne et filtre dans `AdminTeamsPage`, sélecteur dans `TeamForm`).
  `V89` met **toutes les équipes existantes en UNLOCKED** ; une équipe importée de biketeam
  l'est aussi. Une nouvelle équipe naît FREE et **ouverte** (`joinable`, `addMemberAllowed`,
  `enableRoutePlanner` à `true`). `PlanLimits.forTeam` lit les plafonds de
  `pedalons.limits.*` (`LimitsConfig`) sans requête par ligne ; `TeamDetailDto` porte `tier`,
  `memberLimit` et `plannerQuota`, `UserDto` porte `plannerQuota`.
- **25 membres** au plus pour une équipe gratuite, invitations en cours comprises (une
  invitation dont la personne est déjà membre ne compte pas), sur les quatre chemins : rejoindre,
  ajout par un admin, invitation, acceptation. Ligne `teams` verrouillée (`for update`), admin
  plateforme et migration biketeam exemptés, refus `409 TEAM_MEMBER_LIMIT_REACHED` (`limit`,
  `current`). Web : « 24 / 25 », invitation désactivée, « Rejoindre » remplacé par le message ;
  mobile : compteur du tableau de bord, message sur « Rejoindre ».
- **Quotas du planificateur** (journal `planner_saves`, purgé au-delà de 13 mois par
  `PlannerQuotaCleanupScheduler`) : 20 enregistrements d'un tracé dessiné par mois civil (UTC)
  et par équipe gratuite, chaque création et chaque modification comptent ; 10 par mois dans les
  outils GPX pour qui n'est membre d'aucune équipe débloquée du domaine, et la promotion d'un
  aperçu dessiné compte encore dans l'équipe d'arrivée. Une copie ne compte pas (duplication
  `API-179`, aperçu depuis un parcours `API-180`). Refus `403 PLANNER_QUOTA_REACHED` (`scope`
  TEAM | PERSONAL, `limit`, `current`, `resetsOn`, `teamName`) ; `/api/router` refusé à quota
  plein et plafonné à 300 calculs par jour et par utilisateur (`429`). Web : pas de compteur ;
  « Créer un parcours » et « Tracer sur la carte » désactivés à quota plein, et
  `PlannerQuotaModal`, bloquante, qui dit pourquoi (équipe gratuite / aucune équipe débloquée),
  quand le compteur repart et que l'import GPX reste ouvert.
- Tests : `TeamLimitsResourceTest`, `TeamPlannerQuotaResourceTest`,
  `PersonalPlannerQuotaResourceTest`, `AdminTeamResourceTest`, les cas ajoutés à
  `RouteDuplicateResourceTest` et `RoutePreviewFromRouteResourceTest` ; suite backend complète
  verte sur optiplex (4726 tests). Vitest et tests Flutter ciblés. Les e2e sont écrits, pas
  lancés : `BILL-11`.
- **À ne pas défaire** : un client ancien qui omet `tier` ne rétrograde jamais une équipe ; le
  palier se lit sur l'équipe, jamais par une requête par ligne ; un refus ne compte pas, et
  l'inscription se fait dans la même transaction que l'enregistrement ; l'envoi GPS, le webhook
  et l'import GPX restent hors quota.
