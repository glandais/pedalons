---
id: OPS-52
title: "Alias `colorful` et `eclipse` retirés du tileserver partagé"
status: done
done: 2026-10-20
---

## Livré

`OPS-52` **Alias `colorful` et `eclipse` retirés du tileserver partagé** (2026-10-20) —
`data/tileserver/config.json` ne déclare plus que `colorful-v7` et `colorful-dark-v7`. Côté hôte,
ce qui l'applique (étape 5 de « Thumbnail basemaps (shared tileserver) » dans `OPERATIONS.md`) :
`scripts/deploy.sh --shared` puis `docker service update --force pedalons-shared_tileserver` —
sans ce redémarrage le tileserver sert les alias lus à son démarrage —, et dans chaque
environnement la suppression de `data/cache/tileserver_8080/styles/{colorful,eclipse}`, tuiles v5
que plus rien ne lit. Pas de test (configuration).
