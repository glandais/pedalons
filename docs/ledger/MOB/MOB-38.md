---
id: MOB-38
title: "Un jeton d'accès refusé, de bout en bout"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-30
---

## Livré

`MOB-38` **Un jeton d'accès refusé, de bout en bout** (30 septembre 2026, contrat inchangé)
— l'app ouverte et connectée reçoit un jeton d'accès que le serveur refuse, le jeton de
rafraîchissement restant valide (`replaceAccessToken` de `patrol_test/common.dart`) : le profil
charge quand même (le badge « Mes sorties à venir », `GET /api/users/me/participations`) avec un
jeton neuf, et « Déconnecter tous les appareils », sous `/api/auth/`, atteint le serveur — la
session d'un autre appareil ne se rafraîchit plus. C'est le cycle 401 → rafraîchissement → nouvel
essai que l'intercepteur fait sur son propre `Dio`, hors de portée des tests unitaires de
08aa46ef. `expired_access_token_test.dart`, lancé sur la pile e2e le 30 septembre 2026 (`fixes`
@ `4d9b4db2`) : vert sur le simulateur iOS (iPhone 17 Pro Max, iOS 26.5) et sur l'émulateur
Android (Pixel 7, API 36), dans les passes Patrol complètes, 57 / 57 sur chacune. *Non couvert : un jeton réellement expiré (signé, `exp` passé) plutôt que
refusé, et plusieurs appels en file pendant un même rafraîchissement.*
