---
id: API-70
title: "Tests backend du résumé du profil lancés"
status: done
group: "Vie privée : les métadonnées retirées à l'import"
done: 2026-10-04
---

## Livré

`API-70` **Tests backend du résumé du profil lancés** (2026-10-04) — `ProfileSummaryResourceTest`,
`ProfileSummaryQueryCountTest`, `GpsResourceTest` et `AdContactResourceTest` (gabarit
`ad-contact.*` réécrit par `WEB-57`) sont passés dans la suite backend complète sur `b954747c`
(3128 tests, 0 échec). Le budget d'entités de `ProfileSummaryQueryCountTest` (3 par ligne ajoutée,
plus 8) a tenu sans ajustement. **À ne pas défaire** : si Hibernate charge un jour plus
d'entités, on ajuste le budget, jamais en réintroduisant une requête par ligne.
