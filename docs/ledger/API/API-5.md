---
id: API-5
title: "Capacité de la sortie sur les lignes de liste"
status: done
group: "Petites évolutions d'API"
done: 2026-09-30
---

## Livré

| ID | Livré | Écrans |
|---|---|---|
| `API-5` | **Capacité de la sortie sur les lignes de liste** (2026-09-30) — **API 5.11.0** : `RideDto.maxParticipants`, nullable, la **somme des `maxParticipants` des groupes**, **nulle dès qu'un groupe est sans limite** (ou sans groupe) : la sortie n'a alors pas de plafond. C'est exactement l'ensemble des sorties pour lesquelles `full` peut être vrai — ne pas sommer les seuls groupes plafonnés, un « 12/20 » sur une sortie qui a un groupe illimité serait faux. `full` reste la vérité sur « complet » (il compare groupe par groupe). Même règle sur le détail (repli sur `ride.getGroups()`) et sur la liste, où elle est calculée dans `RideSummaryRepository.loadListSummaries` à partir des lignes par groupe déjà lues pour `full` : aucune requête de plus. Le mobile rend « N/M » dans le carrousel de l'accueil (`upcomingParticipants`), le nombre seul quand la capacité est nulle ; la carte de fil garde son compteur brut, sans barre. Le web (`PublicationCardProgress`) sommait `ride.groups`, **vide sur une ligne de liste** : sa barre « N/M places » ne s'affichait jamais ; elle lit désormais `maxParticipants` et `full`. Couvert par `RideMeFieldsTest.maxParticipants_sumsTheGroupCapacities_nullWhenOneGroupIsUncapped_listAndDetailAgree` (liste et détail), les `…QueryCountTest` verts, `upcoming_action_test.dart` et `PublicationCardProgress.test.tsx` | 11 |
