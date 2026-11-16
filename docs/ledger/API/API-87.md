---
id: API-87
title: "Supprimer ou restaurer un parcours ne recalculait pas la fin des sorties qui le citent"
status: done
group: "Défauts relevés"
done: 2026-10-11
---

## Livré

`API-87` **Supprimer ou restaurer un parcours ne recalculait pas la fin des sorties qui le
citent** (2026-10-11, sans changement de contrat) — `PublicationEndCalculator` traite un parcours
supprimé comme absent (départ + 3 h), mais seul le remplacement du GPX relançait le calcul : après
une suppression ou une restauration, la fin stockée restait l'ancienne jusqu'au prochain
enregistrement, et une sortie pouvait quitter « À venir » trop tôt ou trop tard. `refreshUsersOf`
est désormais appelé par les quatre chemins qui changent le drapeau `deleted` d'un parcours :
`RouteService.deleteRoute` et `undeleteRoute`, le retrait par la modération
(`ModerationService.remove`) et la suppression relayée par la migration biketeam. Couvert par
`PublicationEndStoredTest.deletingThenRestoringARoute_movesTheEndOfEveryRideGroupAndStageOnIt`.
**À ne pas défaire** : tout nouveau chemin qui supprime ou restaure un parcours appelle
`refreshUsersOf`, comme celui qui remplace son tracé.
