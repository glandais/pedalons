---
id: OPS-71
title: "Vignettes dessinées sur le fond « Route » (cycling-style)"
status: open
size: "S"
kind: externe
verified: 2026-11-27
---

## Livré

Dans le dépôt, le 27 novembre 2026 : les vignettes étaient dessinées sur VersaTiles `colorful` v7.0.1
(copie du 20 octobre, `OPS-50`), alors que depuis `WEB-177` le fond par défaut des cartes est « Route »
(`@glandais/cycling-style`) et que « Plan » n'est plus proposé — les vignettes ne ressemblaient plus aux
cartes. `data/tileserver/styles/cycling-road.json` et `cycling-road-dark.json` sont les `dist/style-road*.json`
de cycling-style 1.0.1, servis sous les ids `cycling-road-v1` et `cycling-road-dark-v1`
(`MapThumbnailRenderer`, `VERSION` 2) ; les anciens `colorful-v7` restent servis, sur leurs anciens
fichiers, pour le backend précédent pendant le déploiement. Rendu vérifié sur un tileserver-gl v5.7.0
jetable (Paris, z8, z11 et z14, clair et sombre, sprite double `base` + `cyclo`, aucun avertissement). Le
parc existant est redessiné par le rattrapage de `API-223`. Procédure : « Thumbnail basemaps (shared
tileserver) » dans [`OPERATIONS.md`](../../OPERATIONS.md#thumbnail-basemaps-shared-tileserver).

## Reste à faire

`OPS-71` **Vignettes dessinées sur le fond « Route » (cycling-style)** — à exploiter, dans cet ordre :
déployer la pile partagée **avant** les environnements et forcer le redémarrage du tileserver
(`docker service update --force pedalons-shared_tileserver`), puis staging et prod ; suivre le rattrapage
dans les journaux (`Thumbnail backfill: … left …`) jusqu'à « done » ; ensuite retirer `colorful-v7`,
`colorful-dark-v7` et leurs fichiers de `data/tileserver`, redéployer la pile partagée, et supprimer
`data/cache/tileserver_8080/styles/colorful*-v7` dans chaque environnement.
