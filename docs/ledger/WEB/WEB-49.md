---
id: WEB-49
title: "Carte d'une sortie : sens des parcours, contrôles visibles, plein écran sur iPhone, choix des traces"
status: done
group: "Défauts d'interface"
done: 2026-10-04
---

## Livré

`WEB-49` **Carte d'une sortie : sens des parcours, contrôles visibles, plein écran sur iPhone,
choix des traces** (4 octobre 2026, relevé dans `docs/BUGS.md`) —
- *Sens* : un chevron répété le long de chaque trace, dans l'ordre de ses points, sur **toutes**
  les cartes qui dessinent une trace (sortie et voyage `RoutesMapView`, parcours `RouteTrackMap`,
  planificateur et sa loupe). Image dessinée au canvas (`map/RouteArrows.tsx`), enregistrée par
  `PedalonsMap` via `setMissingStyleImageResolver` **et** un `addImage` immédiat — le résolveur
  seul laisse sans flèches une couche qui a demandé l'image avant l'effet (constaté sur la page
  parcours) ; mise en page commune `map/routeArrowLayout.ts`. Sur la carte de tous les parcours
  (`RoutesTileMap`), seul le parcours survolé ou ouvert en a : sur toutes les traces à la fois
  elles noieraient la carte. `RouteTrackMap` les pose sur une source des pistes entières, pas sur
  les segments du dégradé.
- *Contrôles cachés* : le profil d'altitude de `RoutesMapView` était en haut à droite, en pleine
  largeur sous `sm`, donc par-dessus toute la colonne de boutons (zoom, fonds, plein écran) sur
  téléphone. Il passe en bas à gauche (laisse le ⓘ de l'attribution visible), le cadrage réserve
  le bas au lieu du haut, et il disparaît quand aucune trace n'est affichée.
- *Plein écran* : sans API Fullscreen (Safari iPhone), MapLibre passe la carte en
  `position: fixed; z-index: 99999` (`maplibregl-pseudo-fullscreen`), mais dans le contexte
  d'empilement de sa boîte (`z-index: 0` inline) et du `.detail-map` collant : les pastilles des
  participants passaient devant. Les deux montent au `--mantine-z-index-max` tant que la carte est
  en plein écran (`index.css`, `:has()`, `!important` contre le style inline).
- *Traces* : le panneau des fonds (`MapStyleSwitcher`) liste les traces quand il y en a plus
  d'une, une case et la couleur chacune ; une trace décochée garde sa couche (`visibility: none`,
  le clic interroge toujours la même liste de couches), sort du profil, des marqueurs départ et
  arrivée, et du choix de la trace mise en avant.
Vérifié à la main dans Chrome sur staging (sortie à 8 groupes, page parcours, carte des
parcours ; plein écran simulé par la classe). Pas de test automatisé : jsdom ne rend pas MapLibre.
