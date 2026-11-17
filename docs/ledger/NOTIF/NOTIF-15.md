---
id: NOTIF-15
title: "Une notification datée reste non lue après le rendez-vous"
status: open
size: "M"
group: "Notifications datées : expiration"
verified: 2026-11-17
---

## Reste à faire

`NOTIF-15` **Une notification datée reste non lue après le rendez-vous** — le rappel d'une sortie
partie samedi, son annonce ou son changement d'horaire restent comptés dans la cloche
(`NotificationRepository.count`, `NotificationService.unreadCount`) jusqu'à ce que la personne les
ouvre ou que la rétention globale de 90 jours les supprime (`NotificationRetentionService`). Le
filtre `live()` de `NotificationRecipientResolver` n'agit qu'à la diffusion : rien ne revient sur
une notification déjà créée.

À faire :

- Une colonne `notifications.expires_at`, nullable et indexée avec `recipient_id`, remplie à la
  diffusion (`NotificationDispatchService`) à partir du type et de `effectiveSubjectDateTime()` :
  le départ pour `RIDE_REMINDER`, `RIDE_PUBLISHED`, `RIDE_UPDATED`, `RIDE_CANCELLED`,
  `RIDE_GROUP_REMOVED`, `RIDE_JOINED`, `TRIP_PUBLISHED`, `TRIP_CANCELLED` ; null pour les posts et
  les commentaires. La règle vit sur `NotificationType`, avec un `switch` exhaustif comme
  `isRendezvous`. Migration rétrocompatible : les anciennes lignes à null n'expirent pas
  (déploiement progressif).
- « Non lu » devient `readAt is null and (expiresAt is null or expiresAt > now)` dans `count`,
  `page(unreadOnly)` et le compteur. `readAt` garde son sens, « vue par la personne » : pas de job
  qui le pose, pas d'écriture de masse.
- `NotificationDto` expose `expired` (ou `expiresAt`) pour `NOTIF-17` ; bump du contrat.
- `RIDE_REMINDER` expiré est **supprimé**, sans valeur comme historique : une règle par type dans
  `NotificationRetentionService` (par exemple 24 h après l'échéance), en tranches comme la purge
  existante. Les autres types restent dans l'historique jusqu'aux 90 jours.
- `NotificationDeliveryService` et le digest abandonnent une livraison **e-mail** en attente
  (relance, digest du matin) dont la notification a expiré, au lieu de l'envoyer — le push le fait
  déjà (`NOTIF-16`, dans `NotificationDeliveryService.load`). Réutiliser
  `NotificationType.expiresAt`, posée par `NOTIF-16`, pour remplir la colonne.

Décision à écrire au moment de livrer : l'échéance est figée à la diffusion, comme
`subjectDateTime`. Une sortie repoussée fait expirer trop tôt son ancienne `RIDE_PUBLISHED`, ce qui
est acceptable puisque `RIDE_UPDATED` porte la nouvelle date ; relire la date vivante de la sortie
coûterait une jointure par page.
