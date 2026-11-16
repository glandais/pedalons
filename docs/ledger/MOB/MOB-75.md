---
id: MOB-75
title: "`patrol_test/README.md` en retard sur la suite"
status: open
size: "XS"
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
verified: 2026-11-16
---

## Reste à faire

`MOB-75` **`patrol_test/README.md` en retard sur la suite (XS)** — la table
« Coverage » n'a pas de ligne pour `ride_group_page_test` (`MOB-67`, `MOB-68`), alors que
`ride_solo_group_test` et `ride_participants_map_test` en ont une ; « Not covered yet » cite
encore le jeton d'accès expiré (`MOB-38`), couvert par `expired_access_token_test.dart`.
