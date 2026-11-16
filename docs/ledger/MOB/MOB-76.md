---
id: MOB-76
title: "Profil d'altitude provisoire dans l'app (18 octobre 2026, contrat `11.8.0`)"
status: done
group: "Tableau de bord d'équipe"
done: 2026-10-18
---

## Livré

### `MOB-76` Profil d'altitude provisoire dans l'app (18 octobre 2026, contrat `11.8.0`)

`MOB-76` **La fiche d'un parcours dit quand son profil est provisoire, et se met à jour seule**
— le pendant mobile de `WEB-102` (`API-131`). Tant que `RouteDetailDto.elevationState` vaut
`PENDING` (l'altitude rapide d'un parcours qui vient d'être enregistré, le recalcul HD étant
programmé), la fiche affiche « Profil d'altitude provisoire » au-dessus du profil et redemande le
parcours toutes les 30 s (`ElevationRefreshPoller`, `mobile/lib/features/routes/domain/
elevation_refresh.dart`, branché sur `routeDetailProvider` dans `route_detail_page.dart`) ; elle
s'arrête dès que l'état n'est plus `PENDING`, ou 15 minutes après le premier `PENDING` vu par
l'écran. Rien en `FAST` (recalcul abandonné) ni en `HD`. Test : `elevation_refresh_test.dart`.
**À ne pas défaire** : la cadence et l'abandon sont ceux du site (`useElevationRefetchInterval`) ;
un rechargement garde la valeur précédente, donc ni la carte ni le profil ne repassent par un état
de chargement, et la carte ne se recadre pas (l'emprise du tracé ne change pas avec l'altitude).
Devenu plus fréquent avec l'envoi de GPX depuis l'app (`MOB-79`) : chaque parcours importé passe
par `PENDING`.
