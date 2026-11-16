---
id: SEC-17
title: "Le jeton du flux ICS meurt après 90 jours de silence"
status: done
done: 2026-09-30
---

## Livré

`SEC-17` **Le jeton du flux ICS meurt après 90 jours de silence** (2026-09-30, contrat
inchangé, migration `V51__calendar_token_last_used`) — il n'expirait jamais. Chaque consultation
du flux (`/api/calendar/ics`, `/api/teams/{slug}/calendar/ics`) note `last_used_at`, au plus une
fois par jour et par une requête `update` qui ne touche pas la version de la ligne (deux
applications qui interrogent le même flux ne se heurtent pas au verrou optimiste) ; un jeton
dont la dernière consultation, ou à défaut la création, date de plus de
`pedalons.calendar.token.inactivity-days` (90) est refusé comme un jeton inconnu (403), effacé
par `AuthCleanupScheduler`, et `GET /api/calendar/token` en crée un neuf plutôt que d'afficher
une adresse morte. Politique choisie par l'utilisateur : **l'inactivité**, pas une durée fixe ni
une rotation — une application de calendrier interroge son abonnement indéfiniment et ne peut
pas apprendre une nouvelle adresse, donc une échéance fixe couperait sans prévenir les
abonnements vivants ; seul le jeton que plus personne ne consulte meurt. Ne pas y revenir sans
prévoir d'avertir l'utilisateur. La migration donne à tout jeton existant une période neuve à la
date du déploiement (aucun abonnement coupé) ; la colonne est nullable pour la version
précédente, et `null` vaut la date de création. Politique de confidentialité (§1, §4, §6) et
`OPERATIONS.md` mises à jour. Tests : `CalendarResourceTest`, bloc « Token inactivity » (jeton
silencieux refusé sur les deux flux, jeton jamais consulté daté de sa création, vieux jeton
toujours consulté vivant et marqué, marquage au plus quotidien, jeton mort remplacé, purge
sélective) — **écrits sans avoir été lancés**.
