---
id: API-99
title: "Un membre ne peut plus être inscrit dans deux groupes d'une même sortie par deux inscriptions simultanées"
status: done
group: "Concurrence : constats de la modélisation formelle du 11 octobre 2026"
done: 2026-10-11
---

## Livré

`API-99` **Un membre ne peut plus être inscrit dans deux groupes d'une même sortie par deux inscriptions simultanées** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — le contrôle `findByUserAndRide` de `joinGroup` ne voyait pas l'inscription non encore validée d'une requête concurrente (téléphone et onglet web, deux onglets) vers un autre groupe, et rien en base n'interdit deux lignes (g1,u) et (g2,u) : la place était prise deux fois, `registeredGroup` montrait un groupe au hasard, et « Quitter » laissait l'autre inscription. Le même verrou sur la ligne de la sortie qu'`API-98` (`RideRepository.lockForJoin`) sérialise les inscriptions : la seconde voit la première et reçoit `ALREADY_REGISTERED`. Test : `RideJoinTwoGroupsRaceTest`. **À ne pas défaire** : le verrou porte sur la sortie et non sur le groupe, la règle couvrant tous les groupes de la sortie ; une colonne `ride_id` dénormalisée avec un index unique a été écartée (migration et rétro-remplissage compatibles avec la version précédente pendant un déploiement progressif, et elle ne règle pas `API-98`).
