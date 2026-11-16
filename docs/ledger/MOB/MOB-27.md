---
id: MOB-27
title: "Sorties passées et annulées"
status: done
group: "Couverture e2e Patrol"
done: 2026-09-29
---

## Livré

`MOB-27` **Sorties passées et annulées** (29 septembre 2026) — une sortie de la veille, restée
`PUBLISHED`, affiche « Terminée » et aucun de ses deux groupes ne propose « Rejoindre », « Quitter »
ni « Complet » ; une sortie annulée derrière l'app (PUT du `RideRequest` complet, statut
`CANCELLED`, comme l'éditeur web) affiche son bandeau, et la carte du groupe n'offre rien, pas même
« Quitter » à un inscrit que l'API compte toujours comme tel — `ride_past_cancelled_test.dart`.
*Non couvert : le refus `409 RIDE_PAST` de l'API (couvert côté web), la carte « Ma prochaine sortie »
d'une sortie annulée.*
