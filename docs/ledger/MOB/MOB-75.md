---
id: MOB-75
title: "`patrol_test/README.md` en retard sur la suite"
status: done
size: "XS"
group: "Couverture e2e Patrol — ce que les tests ne couvrent pas encore"
done: 2026-11-17
---

## Livré

`MOB-75` **`patrol_test/README.md` à jour de la suite** (17 novembre 2026, documentation seule) — la
table « Coverage » a une ligne pour `ride_group_page_test` (`MOB-67`, `MOB-68`, `MOB-134`) : ce que le
test vérifie, relu dans le fichier, à côté de `ride_solo_group_test` et `ride_participants_map_test`.
« Not covered yet » ne cite plus le jeton d'accès expiré (`MOB-38`) parmi les manques : il renvoie à
`expired_access_token_test`, qui le couvre.
