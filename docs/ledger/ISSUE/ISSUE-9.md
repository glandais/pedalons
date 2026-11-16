---
id: ISSUE-9
title: "Le worker n'écrase plus les compteurs qu'un `reportError` concurrent vient d'écrire"
status: done
done: 2026-10-11
---

## Livré

`ISSUE-9` **Le worker n'écrase plus les compteurs qu'un `reportError` concurrent vient d'écrire** (2026-10-11, contrat inchangé, constat de la modélisation formelle TLA+/Lean). Avant, `ErrorSignature` n'avait ni `@Version` ni `@DynamicUpdate`, et chaque transaction du worker lisait la ligne par un simple `findById` : marque CREATED, essais, réouverture, résumé, `markClosed`. Son UPDATE de toutes les colonnes réécrivait donc `occurrence_count`, `last_seen_at`, `versions` et `regression_version` tels qu'il les avait lus, et perdait l'occurrence qu'un `reportError` (verrouillé `FOR UPDATE`) avait commitée entre-temps. `markClosed` pouvait en plus figer un `versions_at_close` sans cette version et rater la régression. Désormais `ErrorSignature` porte `@DynamicUpdate`, si bien que chaque écrivain n'écrit que les colonnes qu'il a changées. Toute écriture du worker passe aussi par `ErrorSignatureRepository.lock` (PESSIMISTIC_WRITE, le verrou que prend `lockOrCreate`), et `markClosed` verrouille la ligne avant de lire les occurrences. Couvert par `ErrorSignatureWorkerLostUpdateRaceTest`. **À ne pas défaire** : garder `@DynamicUpdate` sur `ErrorSignature` (deux écrivains se partagent la ligne), verrouiller avant toute lecture-modification-écriture du worker, ne pas remplacer ces protections par un `@Version` qui ferait seulement échouer le worker.
