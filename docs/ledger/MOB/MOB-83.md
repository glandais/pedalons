---
id: MOB-83
title: "Revêtement sur le profil du groupe d'une sortie (20 octobre 2026, contrat `11.15.0`)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-20
---

## Livré

### `MOB-83` Revêtement sur le profil du groupe d'une sortie (20 octobre 2026, contrat `11.15.0`)

`MOB-83` **Le profil du groupe d'une sortie montre son revêtement** — `RideElevationSection`
(fiche de la sortie et onglet du groupe) reprend la bascule Pente / Revêtement de `MOB-81` et
`MOB-82`, sur le revêtement que le lot `/routes/bulk` porte depuis `API-133` :
`RouteSurfaceSection` sous le profil, barres colorées par `rideRouteSurfaceBarsProvider`
(`ride_group_selection_provider.dart`, mémorisé), classe sous le réticule. La bascule retombe sur la
pente quand le groupe choisi n'a pas de revêtement. Test : `ride_elevation_section_test.dart`
(prêt, en cours, sans revêtement). **Hors périmètre** : la carte de la sortie, qui dessine tous les
groupes, garde ses couleurs ; le profil global d'un voyage reste en pente seule (décidé avec le
propriétaire le 20 octobre 2026) ; pas de rechargement tant qu'un revêtement se calcule.
