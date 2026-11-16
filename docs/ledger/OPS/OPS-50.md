---
id: OPS-50
title: "Fonds VersaTiles : passage à la v7"
status: done
done: 2026-10-20
---

## Livré

`OPS-50` **Fonds VersaTiles : passage à la v7** (2026-10-20, livré dans le dépôt ; pas de
changement de contrat) — les clients chargent les styles de `tiles.versatiles.org` sans version
et suivaient donc d'eux-mêmes la v7.0.1, mais trois écarts s'étaient creusés. **Le fond sombre**
pointait sur `eclipse`, nom v5 conservé en alias déprécié par la v6 et retiré par la v7 : il ne
répondait plus que par une 301 vers `colorful-dark`, que `application.properties` vise désormais.
**La projection** : depuis la v6 (18 septembre 2026) le style demande `globe` ; le web dessinait un
globe aux petits zooms, mais pas sur les fonds IGN ou raster, qui n'en demandent pas, ni sur le
mobile (MapLibre Native l'ignore). Les trois cartes du web (`PedalonsMap`, `RoutePlannerMiniMap`,
`AdLocationMap`) forcent `projection="mercator"`, que react-map-gl réapplique à chaque chargement
de style. **Les vignettes** : la copie de `data/tileserver/styles/` datait de la v5.8 (31 janvier
2026), avec un correctif de sprite (`c875fae7`) qui supposait les noms d'icônes inchangés alors
que la v6 en avait renommé 22 — 26 icônes manquaient au rendu (pharmacie, toilettes, police, flèche
de sens unique…). Elle est remplacée par les `colorful` et `colorful-dark` de la release v7.0.1,
identiques au style en ligne, servis sous les ids `colorful-v7` et `colorful-dark-v7`
(`MapThumbnailRenderer`), les anciens `colorful` et `eclipse` restant des alias le temps du
déploiement (`OPS-51`). Rendu vérifié sur un tileserver-gl v5.6.0 jetable (Paris, z14, clair et
sombre, icônes présentes, aucun avertissement). Procédure de mise à jour : « Thumbnail basemaps
(shared tileserver) » dans [`OPERATIONS.md`](../../OPERATIONS.md#thumbnail-basemaps-shared-tileserver).
Pas de test automatisé : aucun test ne passe par le tileserver. **À ne pas défaire** : un nouveau
style de vignette prend un **nouvel id**, car le cache de tuiles de vcyclist est indexé par URL et
mêlerait sinon dans une même vignette des tuiles des deux versions ; la projection reste forcée
tant qu'un fond de la liste n'est pas en `globe`.
