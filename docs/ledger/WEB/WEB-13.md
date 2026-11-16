---
id: WEB-13
title: "Les 5 écrans qui affichent le tracé complet d'un parcours"
status: done
group: "La recette web, automatisée"
---

## Livré

`WEB-13` Les 5 écrans qui affichent le tracé complet d'un parcours : détail de parcours, carte
plein écran de parcours et d'étape (les 4 via `useGetRoute`), carte de groupe d'une sortie (via
`useRoutesBulk` sans `geometry:false`, `RoutesMapView.tsx`). — `route-maps.e2e.ts` : chaque
écran lit la géométrie entière (aucun paramètre qui la réduise, chaque point du GPX à moins
de 15 m) et la carte dessine le tracé. *Non couvert : une simplification qui serait ajoutée
plus tard dans le chemin de dessin lui-même — le test compte des pixels, pas des sommets.*
