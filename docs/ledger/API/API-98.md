---
id: API-98
title: "Des inscriptions simultanées ne dépassent plus `maxParticipants`"
status: done
group: "Concurrence : constats de la modélisation formelle du 11 octobre 2026"
done: 2026-10-11
---

## Livré

`API-98` **Des inscriptions simultanées ne dépassent plus `maxParticipants`** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean) — `RideService.joinGroup` vérifiait la capacité (`RideGroup.hasCapacity()`, taille de la collection) puis insérait sans aucun verrou : deux membres rejoignant la dernière place en même temps voyaient chacun N-1 < N et validaient tous deux, l'index unique `(ride_group_id, user_id)` ne couvrant pas deux utilisateurs distincts et le `@Version` du groupe n'étant pas incrémenté par une collection `mappedBy`. `joinGroup` verrouille maintenant la ligne de la sortie (`RideRepository.lockForJoin`, `refresh` en `PESSIMISTIC_WRITE`, soit `SELECT … FOR UPDATE`) avant de lire le groupe et de charger ses participations : les inscriptions à une même sortie passent l'une après l'autre et la seconde reçoit `GROUP_FULL`. Sous ce verrou, `joinGroup` revérifie aussi que la sortie est toujours publiée (403 sinon) : une annulation validée entre le contrôle d'accès et le verrou ne laisse plus passer d'inscription. Pas de migration. Test : `RideGroupCapacityRaceTest`. **À ne pas défaire** : le verrou est pris avant toute lecture des participations (une collection chargée avant lui compterait des lignes périmées), et c'est un `refresh` et non un `lock()`, pour qu'une modification de la sortie par un organisateur entre-temps ne fasse pas échouer l'inscription sur le contrôle de version.
