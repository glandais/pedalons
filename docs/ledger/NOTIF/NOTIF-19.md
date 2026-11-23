---
id: NOTIF-19
title: "Activation du push proposée seulement dans la boîte de notifications"
status: open
size: "S"
group: "Onboarding : recherche du 22 novembre 2026"
verified: 2026-11-23
---

## Reste à faire

`NOTIF-19` **Activation du push proposée seulement dans la boîte de notifications** — dans l'app,
la permission de notification n'est jamais demandée au lancement (à garder), et le seul endroit qui
la propose est `PushActivationBanner`, dans la boîte de notifications (`notifications_page.dart`).
Sur le site, c'est un réglage du profil (`WebPushSettings.tsx`). Une personne qui ne passe par
aucun des deux ne reçoit jamais de push, y compris pour une sortie à laquelle elle participe.

À faire : proposer l'activation au moment où elle sert, juste après une première participation à
une sortie (« Recevoir les changements de cette sortie »), par le même bandeau maison, qui précède
l'invite système.

À ne pas défaire :

- l'invite système ne part que sur un geste dans le bandeau : iOS ne la montre qu'une fois,
  Android deux, alors que fermer le bandeau ne consomme rien ;
- un bandeau fermé ne revient pas avant deux semaines ; après un refus de l'invite système, il
  renvoie aux réglages du téléphone ;
- pas de demande au premier lancement ni sur un écran d'accueil : la CNIL recommande la demande en
  contexte.

La localisation est déjà demandée en contexte (`location_service.dart`), rien à faire de ce côté.
