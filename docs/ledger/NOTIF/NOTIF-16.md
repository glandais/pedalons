---
id: NOTIF-16
title: "Un push daté peut arriver après le rendez-vous"
status: open
size: "S"
group: "Notifications datées : expiration"
verified: 2026-11-17
---

## Reste à faire

`NOTIF-16` **Un push daté peut arriver après le rendez-vous** — `FcmClient` ne fixe ni
`android.ttl` (FCM garde alors le message 4 semaines) ni l'en-tête `apns-expiration` ; seul le web
a un TTL, de 24 h (`WEB_TTL_SECONDS`). Un téléphone éteint jusqu'au dimanche reçoit en se
rallumant le rappel de la sortie de samedi.

À faire : faire porter à `NotificationMessage` l'échéance de la notification (la même règle par
type que `NOTIF-15`) et la traduire en `android.ttl` et `apns-expiration` (et en `TTL` web, borné à
l'échéance) pour les types datés ; inchangé pour les autres. Indépendant de `NOTIF-15` pour la
colonne : l'échéance se calcule depuis `subjectDateTime`, déjà dans le message. Un test sur le JSON
construit par `FcmClient`.

Hors périmètre : retirer un push déjà affiché sur le téléphone, qui demanderait un push silencieux
et du code dans l'isolat de fond.
