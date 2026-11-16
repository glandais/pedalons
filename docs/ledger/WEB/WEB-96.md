---
id: WEB-96
title: "La carte s'initialise au chargement et bloque le fil principal"
status: open
size: "S"
verified: 2026-11-16
---

## Reste à faire

`WEB-96` **La carte s'initialise au chargement et bloque le fil principal (S)** — audit
Lighthouse mobile de la page sortie (16 octobre 2026) : `map-vendor` (MapLibre, 280 Ko gzip)
produit les deux plus longues tâches de la page (1,16 s et 1,11 s) et la majeure partie des
~0,7–3 s de TBT, avant même que la carte soit à l'écran. `WEB-95` a sorti le reste du
chargement initial ; il reste à ne monter `PedalonsMap` que lorsque son conteneur devient
visible (IntersectionObserver), place réservée, sur les pages sortie, groupe de sortie
(`RouteMapPanel`, ex-`GroupRouteMap`), étape, parcours et voyage. Aujourd'hui `RideDetailPage`, `TripDetailPage` et
`RouteMapPanel` chargent la carte en `React.lazy` mais la montent dès le rendu.
