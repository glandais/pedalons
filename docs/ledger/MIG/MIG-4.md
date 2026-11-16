---
id: MIG-4
title: "Vignettes redessinées seulement si leur source change"
status: done
done: 2026-09-30
---

## Livré

`MIG-4` **Vignettes redessinées seulement si leur source change** (2026-09-30) — `updateRide` et
`updateTrip` redessinaient les vignettes claire et sombre à chaque écriture, donc à chaque rejeu de
la migration : son dernier coût. `ThumbnailService.rideInput`/`tripInput` décrivent ce dont elles
sont tirées — les parcours dans l'ordre de dessin, chacun avec les ids de ses traces — et sont lus
avant la modification ; `refreshRideThumbnails`/`refreshTripThumbnails` ne redessinent que si
cette entrée a changé, ou si l'une des deux vignettes manque (un rendu raté la dernière fois est
retenté). Les ids de traces suffisent à dire que la géométrie a changé : une trace n'est jamais
modifiée en place, un nouveau GPX remplace les lignes (`RouteService.updateRoute`). La création
dessine toujours. Couvert par `ThumbnailRefreshTest` (sortie et voyage : création, deux rendus ;
mise à jour au même parcours, aucun ; changement de parcours, deux), où le rendu est remplacé par
un PNG de 1×1 compté par Mockito. Ne pas comparer la `version` du parcours : le rejeu la fait
monter (nom, visibilité) sans toucher au tracé.
