---
id: MOB-29
title: "Notifications des autres sujets"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-29` **Notifications des autres sujets** (29 septembre 2026) — `RIDE_CANCELLED` : une
sortie annulée par son organisatrice (PUT du `RideRequest`, statut `CANCELLED`) n'atteint que
l'inscrit, jamais le membre non inscrit ; l'entrée dit « Une sortie est annulée » avec le nom de la
sortie, et ouvre la sortie sous son bandeau d'annulation — `notification_ride_cancelled_test.dart`.
`RIDE_JOINED` : un cycliste s'inscrit depuis l'app ; la notification, qui nomme le cycliste et porte
le groupe en `excerpt`, atteint le créateur de la sortie **et** le meneur du groupe
(`RideGroupDto.leader`, distinct du créateur), jamais le cycliste lui-même ; l'entrée lue par le
meneur nomme le cycliste et le groupe, et ouvre la sortie — `notification_ride_joined_test.dart`.
*Non couvert : les autres types du sujet sortie (`RIDE_PUBLISHED`, `RIDE_UPDATED` et ses variantes
de libellé, `RIDE_REMINDER`, `RIDE_GROUP_REMOVED`), `TRIP_*`, `CONTENT_REPORTED` (qui ouvre le web),
et la réception push (FCM absent de la stack e2e).*
