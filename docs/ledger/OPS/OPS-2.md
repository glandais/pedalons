---
id: OPS-2
title: "Retiré du ledger : c'est une règle permanente, pas une tâche"
status: done
done: 2026-10-16
---

## Livré

`OPS-2` **Retiré du ledger : c'est une règle permanente, pas une tâche** (2026-10-16) — les tests
backend sont lancés par le propriétaire du dépôt, jamais par Claude ; la règle est dans
`CLAUDE.md` (« Critical Prohibitions »), avec l'invariant des recherches par page. Le
16 octobre 2026, le propriétaire indique que tous les tests passent. Les gardes sont actives,
aucune n'est `@Disabled` : les classes `…QueryCountTest` (sur `AbstractQueryCountTest`, dont
`GpsRouteSyncPlannerQueryCountTest`, arrivée avec `API-120`) et
`RideGroupLeaderTest.groupLeader_isNotTheRideCreator`. **À ne pas défaire** : ne jamais désactiver
l'une de ces gardes pour faire passer un build — elles échouent si quelqu'un réintroduit une
requête par ligne ou un repli du chef de groupe sur `createdBy`.
