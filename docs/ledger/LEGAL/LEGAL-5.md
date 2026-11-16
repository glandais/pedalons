---
id: LEGAL-5
title: "Services push des navigateurs : destinataires, pas sous-traitants"
status: done
done: 2026-09-29
---

## Livré

`LEGAL-5` **Services push des navigateurs : destinataires, pas sous-traitants** (2026-09-29) —
§4, nouvelle sous-section « Services push des navigateurs » : Google (Chrome), Mozilla (Firefox),
Apple (Safari), Microsoft (Edge) remettent la notification web ; c'est le navigateur qui choisit
le service, qui ne reçoit que le message chiffré (RFC 8291), l'adresse d'abonnement et l'IP de
l'appareil, et agit en responsable de traitement indépendant. Le §5 y renvoie. Ils ne vont **pas**
au tableau des sous-traitants : nous ne les choisissons pas et ils ne lisent pas le contenu. FCM,
qui le lit, y reste.
