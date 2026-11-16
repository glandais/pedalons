---
id: API-88
title: "La fenêtre du calendrier filtrait sur le départ, pas sur la fin"
status: done
group: "Défauts relevés"
done: 2026-10-11
---

## Livré

`API-88` **La fenêtre du calendrier filtrait sur le départ, pas sur la fin** (2026-10-11, sans
changement de contrat) — `CalendarService` ne gardait qu'un événement **parti** dans
`[from, to]` : un voyage commencé avant `from` (aujourd'hui − 30 jours par défaut, le premier du
mois au mobile) manquait alors qu'il durait encore, avec son étape du jour. Les sorties et les
voyages sont maintenant pris par chevauchement — fin stockée d'`API-85` ≥ `from` (filtre
`notEndedAt` de `PublicationQuery`, avec son repli départ + 3 h) et départ ≤ `to` —, pour
`GET /api/calendar/events`, l'agenda d'équipe et les deux flux ICS. Les étapes d'un voyage retenu
passent le même filtre une à une, ce qui écarte celles déjà finies ; les étapes **retirées** du
voyage (`deleted`), que le calendrier listait jusque-là, en sortent aussi. La description de
`from` / `to` au contrat n'a pas bougé. Un voyage sans étape reste absent (`API-18`). Couvert par
`CalendarResourceTest` (`getEvents_keepsATripStartedBeforeTheWindow_withItsStagesStillUnderWay`,
`getEvents_leavesOutATripOverBeforeTheWindow`). **À ne pas défaire** : la fenêtre du calendrier
se lit sur la fin, jamais sur le seul départ.
