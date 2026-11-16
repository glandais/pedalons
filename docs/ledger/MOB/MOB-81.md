---
id: MOB-81
title: "Revêtement des parcours dans l'app (19 octobre 2026, contrat d'API inchangé)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-19
---

## Livré

### `MOB-81` Revêtement des parcours dans l'app (19 octobre 2026, contrat d'API inchangé)

`MOB-81` **La fiche d'un parcours montre son revêtement** — le pendant mobile de `WEB-100` C1b
et C1c (`TrackDto.surfaceState` et `TrackDto.surfaces` du contrat `11.14.0`, déjà dans le client
Dart). Sur `route_detail_page.dart`, juste sous le profil, `RouteSurfaceSection`
(`…/routes/presentation/widgets/route_surface_section.dart`) : une bascule Pente / Revêtement
(`PdlSegmented`) qui colore **le profil et la ligne de la carte**, la barre de répartition
(`PdlSegmentBar`), la légende (« Asphalte 40 % », « < 1 % » sous 0,5 %), l'attribution
« © contributeurs OpenStreetMap » qui ouvre la page de copyright (cible de 44 px) ; « Revêtement
en cours de calcul » quand une piste est `PENDING`, et rien sans surface. La logique est celle du
site (`track_surfaces.dart` : `surfaceAtDistance`, `segmentSurfaces`, `surfaceShares`,
`barSurfaces`, classe dominante par barre du profil, pont entre pistes ignoré) ;
`PdlElevationProfile` et `ElevationAreaPainter` prennent `barColors` (une couleur par barre, à
la place de l'échelle de pente), mémorisées par `routeSurfaceBarsProvider` ; `RouteMap` prend
`colorBy`. `ElevationRefreshPoller.updatePending` recharge aussi la fiche toutes les 30 s, 15 min
au plus, tant qu'un revêtement est en cours. Couleurs : la famille de `TrackSurfaceTone`
(`enum_colors.generated.dart`, depuis `contracts/brand-colors.yaml`) rendue par
`TrackSurfaceStroke` (`enum_colors.dart`), et trois jetons gris de `pdl_colors.dart`
(`mapSurfacePaved`, `mapSurfaceOffNetwork`, `mapSurfaceUnknown`, en clair et en sombre, valeurs
du site) ; `docs/BRANDING.md` §3.6. `routes.surfaceDetail.*` en français et en anglais. Tests :
`track_surfaces_test.dart`, `track_surface_stroke_test.dart`, `route_surface_section_test.dart`
(thèmes clair et sombre), ajouts à `elevation_profile_test.dart` et `elevation_refresh_test.dart` ;
`bash check.sh` vert (`flutter analyze` sans remarque, 1 250 tests). Pas de Patrol ni de recette
sur appareil. **À ne pas défaire** : aucune table de couleurs locale — le trait suit la famille
du YAML, les nuances grises sont des jetons du thème ; le profil compare `barColors` par
identité (mémoriser, sinon il repeint à chaque `build`) ; la bascule retombe sur la pente quand
la surface disparaît. Hors périmètre : l'aperçu d'un parcours dans une sortie, une étape, un
voyage ; « hors réseau » n'est pas pointillé sur la carte.
