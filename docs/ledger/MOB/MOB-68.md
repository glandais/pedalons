---
id: MOB-68
title: "Recette de la page d'un groupe de sortie : fermée, portée par `MOB-135`"
status: done
done: 2026-11-16
---

## Livré

`MOB-68` **Recette de la page d'un groupe de sortie : fermée, portée par `MOB-135`** (16 novembre 2026) — l'entrée demandait de recetter les onglets, la barre d'inscription et une pastille pluie bleue ; `MOB-134` (10 novembre 2026) a retiré les trois (plus de `PdlFamily.blue` dans `features/rides`). Ce qui restait à regarder — `?tab=weather` depuis un lien profond à froid, puces de groupe, cibles de 44 px — est dans la recette de `MOB-135`.

### `MOB-68` Page d'un groupe de sortie : tests Patrol et suite complète lancés (16 octobre 2026, contrat inchangé)

`MOB-68` **Les tests Patrol de la page d'un groupe et la suite `flutter test` complète sont
verts** — part livrée de l'entrée ; la recette sur appareil (sorties à un et à plusieurs groupes)
et la décision sur la couleur de la pastille pluie restent ouvertes sous le même ID. Les Patrol
`ride_group_page_test.dart` (nouveau avec `MOB-67`), `ride_participants_map_test.dart`
(`selectGroup` ouvre la page du groupe puis revient) et `ride_solo_group_test.dart` (`MOB-69`),
écrits le 13 octobre 2026 sans avoir été lancés, passent désormais, comme toute la suite
`flutter test` qui avait calé lors d'un passage groupé. **À ne pas défaire** : `selectGroup` du
module Patrol `ride` ouvre la page du groupe puis revient au détail ; il ne se contente plus de
désigner une carte.
