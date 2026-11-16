---
id: MOB-66
title: "Cartes sans voile sombre, plein écran sur la carte d'une étape"
status: done
done: 2026-10-11
---

## Livré

`MOB-66` **Cartes sans voile sombre, plein écran sur la carte d'une étape** (11 octobre 2026,
contrat inchangé) — relevé sur l'iPhone : le haut de la carte d'une étape de voyage était assombri
et elle n'offrait pas de plein écran. `PdlMapHero` perd `topScrim` (il assombrissait les cartes de
parcours et des pages plein écran) et `bottomScrim`, qui n'avait plus d'appelant. `RouteMap` prend
`allowFullscreen`, que passe `EmbeddedRouteSheet` (la vignette d'une étape) : la fiche parcours,
qui est déjà la carte en plein écran, reste sans bouton. Sans voile, la barre système suit le
thème (icônes sombres en thème clair) au lieu d'être forcée en clair, et la page plein écran garde
la barre hors de la carte (`SafeArea`). **Gestes** : une carte encastrée dans une page qui défile
ne se déplace ni ne zoome (double tap compris) hors plein écran — la vignette d'une étape
(`RouteMap.allowFullscreen`) et la carte d'un voyage (`TripMap`) rejoignent les groupes d'une
sortie et l'annonce ; le tap (choix d'étape, réticule) reste actif. La fiche parcours et la carte
des parcours, qui occupent l'écran, restent libres. Pas de test automatisé : relu sur
simulateur (voile, chevrons) et sur iPhone (gestes).
