---
id: WEB-89
title: "Carte sans tracé"
status: done
group: "Outils GPX (repris de biketeam)"
done: 2026-10-15
---

## Livré

`WEB-89` **Carte sans tracé** (2026-10-15, sans changement de contrat) — route `gpxToolsBlankMap` (`/outils-gpx/carte`, `/gpx-tools/map`, `web` seulement, ni mobile ni lien profond) dans `contracts/routes.yaml`, segment statique placé avant `gpxToolsView` (un TSID ne vaut jamais `map`). `pages/gpxtool/GpxBlankMapPage.tsx` : page plein écran (`layout: 'bare'`), barre de 48 px avec retour vers `/outils-gpx` et titre « Carte », puis `PedalonsMap` (zoom, fonds, relief 3D, ombrage) avec le bouton plein écran et un `GeolocateControl` qui suit la position — premier usage de la géolocalisation dans le dépôt, libellé en fr et en en par la `locale` de `PedalonsMap` (`map.locate.find`, `map.locate.unavailable`). Squelette tant que `/api/config` n'a pas donné le centre, comme `RoutePlanner`. Publique, `noindex` (`gpxBlankMapMeta`), sans préchargement. Le hub gagne une carte « Ouvrir une carte ». Tests : `GpxToolsPage.test.tsx` (le bouton mène à la route), `routeMeta.test.ts` (page non indexée), e2e `routes-render` (`gpxToolsBlankMap`, tous rôles — non lancé à la livraison). **À ne pas défaire** : aucune donnée lue hors `/api/config`, donc pas de prefetch ni d'aperçu requis. Limite connue : le hub reste réservé aux membres, le retour d'un visiteur anonyme mène donc à la connexion.
