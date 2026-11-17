---
id: NOTIF-16
title: "Un push daté peut arriver après le rendez-vous"
status: done
size: "S"
group: "Notifications datées : expiration"
done: 2026-11-17
---

## Livré

`NOTIF-16` **Un push daté peut arriver après le rendez-vous** (2026-11-17, contrat inchangé) —
`FcmClient` ne fixait ni `android.ttl` (FCM gardait alors le message 4 semaines) ni
`apns-expiration`, et un téléphone éteint jusqu'au dimanche recevait en se rallumant le rappel de
la sortie de samedi.

- La règle d'échéance vit sur `NotificationType.expiresAt(subjectDateTime)`, `switch` exhaustif :
  le départ (celui du groupe de la personne, `NOTIF-13`) pour les types de sortie et de voyage,
  rien pour les posts, les commentaires, les invitations et les signalements. `NOTIF-15` la
  reprendra pour la boîte de réception. `NotificationMessage.expiresAt()` la lit.
- `FcmClient.message` la traduit par plateforme : `android.ttl` (borné au plafond de 28 jours de
  FCM), `apns-expiration` en temps UNIX absolu, `TTL` web au plus tôt de l'échéance et d'un jour.
  Sans échéance, rien ne change. Jamais un TTL de 0, qui veut dire « maintenant ou jamais » pour
  FCM, pas « expiré ».
- `NotificationDeliveryService` passe en `SKIPPED` une livraison **push** due après son échéance
  (relance passé le départ, file en retard) au lieu de l'envoyer. L'e-mail continue d'envoyer :
  c'est la part de `NOTIF-15`.

Couvert par `FcmMessageTest` (TTL Android, plafond, `apns-expiration`, TTL web, échéance dépassée)
et `PushNotificationTest#theMessageExpiresAtTheRidesStart`,
`#aPushDueAfterTheRendezvous_isSkipped_notSent`.

Hors périmètre : retirer un push déjà affiché sur le téléphone, qui demanderait un push silencieux
et du code dans l'isolat de fond.
