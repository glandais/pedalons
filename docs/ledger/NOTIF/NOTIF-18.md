---
id: NOTIF-18
title: "Une invitation acceptée ou un signalement traité reste non lu"
status: open
size: "S"
group: "Notifications datées : expiration"
verified: 2026-11-17
---

## Reste à faire

`NOTIF-18` **Une invitation acceptée ou un signalement traité reste non lu** — l'autre axe
d'obsolescence, qui dépend de l'état du sujet et non d'une date : une `TEAM_INVITATION` acceptée,
refusée ou expirée, un `CONTENT_REPORTED` déjà traité par une autre personne de la modération
restent comptés dans la cloche jusqu'à ce que la personne les ouvre.

À faire : quand l'invitation change d'état, ou quand le signalement est tranché, poser l'échéance
(`expires_at` de `NOTIF-15`) à maintenant sur les notifications de ce sujet — une mise à jour par
`event_id`, depuis les services d'invitation et de modération. Pour le signalement, ce sont les
notifications de toute la modération de l'équipe, pas seulement de qui l'a traité. Dépend de
`NOTIF-15`.
