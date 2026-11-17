---
id: NOTIF-17
title: "Les clients ne distinguent pas une notification expirée"
status: open
size: "S"
group: "Notifications datées : expiration"
verified: 2026-11-17
---

## Reste à faire

`NOTIF-17` **Les clients ne distinguent pas une notification expirée** — une fois `NOTIF-15` livré,
une notification non ouverte mais expirée n'est plus comptée, mais le web
(`frontend/src/components/notification/NotificationItem.tsx`) et le mobile
(`mobile/lib/features/notifications/presentation/notification_display.dart`) l'afficheraient
encore avec la pastille et le style d'une non lue.

À faire : lire le champ d'expiration du `NotificationDto`, afficher l'élément comme lu et
atténué (ni pastille ni mise en avant), et ne pas le compter dans le filtre « non lues ». Le texte
ne change pas : la date est déjà formatée à l'affichage (« Demain · 09:00 » devient une date
passée d'elle-même). Tests Vitest et widget. Dépend de `NOTIF-15`.
