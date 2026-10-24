# La météo sur la carte du groupe d'une sortie (web et mobile)

Écrit le 24 octobre 2026. **État : palier 1 livré le 24 octobre 2026 (contrat `11.16.1`), palier 2 et palier 3 lot A le
25 octobre ; palier 3 lot B à faire.**
Ledger `API-138` (convention de distance documentée dans le contrat), `WEB-115` et `MOB-91`
(palier 1, le site et l'app), `WEB-116` et `MOB-92` (palier 2), `WEB-117` et `MOB-93` (palier 3 lot A), `WEB-118` et `MOB-94` (palier 3 lot B et recette). Suit la météo des
sorties (`API-74`, `WEB-94`, `MOB-67`, `MOB-69`) et des étapes (`API-76`, `WEB-67`, `MOB-57`), dont
le plan archivé [`2026-10-05-weather.md`](archive/2026-10-05-weather.md) garde les arbitrages.

Les faits sur le dépôt ont été relus sur `develop` (`7f9fa7e1`, contrat `11.16.0`) le 24 octobre
2026, avec leurs numéros de ligne à cette date.

---

## 1. Objectif

Montrer **où** se passent le vent, la pluie et la température, sur la carte du groupe. La frise
« Heure par heure » reste la référence complète et accessible : la carte n'y ajoute que la
géographie. Livré en trois paliers, chacun utilisable seul.

## 2. Ce qui existe et qu'on réutilise

- **Les données sont déjà sur la page, sans requête de plus.**
  - Web : `useRideGroupData` fournit `leg` (`frontend/src/pages/ride/rideGroupData.ts:41-46`) ;
    seule `route` va à `GroupRouteMap` (`RideGroupPage.tsx:309`).
  - Mobile : `weatherLegOfGroup` (`ride_group_page.dart:264-273`) passe le leg à
    `RideGroupOverviewTab`, qui ne le transmet pas à `RideGroupsMap` (`ride_group_overview_tab.dart:73`).
- **Les DTO suffisent.** `WeatherCheckpointDto` : distance, heure, `weather` (température,
  probabilité de pluie, vent absolu `direction`), `relativeWind`. `WindSegmentDto` :
  `from/toDistance`, `relativeWind`. **Pas de coordonnées, et c'est voulu** (plan archivé `:39`) : un
  point se place par sa distance sur la géométrie que la personne a le droit de voir.
- **La géométrie est `[lon, lat, ele, dist]`**, non simplifiée à la lecture (`TrackDto.java:52-60,
  91-94`) : un checkpoint tombe sur un sommet du tracé.
- **Colorer le tracé point par point existe sur les deux clients** : web `lineColorAt(trackIndex,
  pointIndex)` (`useRouteSurfaceColors.ts`, `RouteMapView.tsx:63`) ; mobile `PdlMapTrack.segmentColors`
  (`pdl_map_controller.dart:61-81`, `_appendSegments` `:1468+`).
- **La logique météo est écrite.** Web : `windPhases`/`phaseAt` (`windPhases.ts:61-118`),
  `exposureSections`, `relativeWindColor`, `WindArrow`, `useCheckpointSummary`. Mobile :
  `relativeWindColor`, `windArrowAngle` (vent absolu, nord en haut), `PdlWindArrow`,
  `computePdlKmMarkers` (déjà « distance → marqueur »).
- **Les couleurs du vent relatif ont une source unique** : `contracts/brand-colors.yaml` (TAIL teal,
  CROSS gray, HEAD orange) → `RELATIVE_WIND_COLORS`, `RelativeWindTone`.

## 3. Le piège : la distance le long d'un parcours à plusieurs traces

- **Le serveur met les traces bout à bout sans compter le saut entre elles** :
  `last = max(last, offset + p.dist() − first)`, puis `offset = last`
  (`backend/src/main/java/fr/pedalons/service/weather/RouteSampleLookup.java:127-152`), traces triées
  par id (`domain/route/Route.java:76`, `@OrderBy("id")`).
- **Le mobile compte ce saut à vol d'oiseau** (`mobile/lib/core/geo/polyline_index.dart:86-106`,
  `total += haversineMeters(previous, first)`). Réutiliser `PolylineIndex.fromLineStrings` tel quel
  **décalerait** les checkpoints et les couleurs dès la deuxième trace.
- **Le web voit `dist` repartir de 0 à chaque trace** (`trackDistanceRange.ts:1-10`) et doit
  additionner les décalages.

D'où, sur les deux clients, une fonction pure « distances chaînées, saut nul » testée sur un cas à
deux traces (repris du fixture de `RouteSampleLookupTest`), et la convention écrite dans le contrat
dès le palier 1 (`API-138`, §6).

## 4. Arbitrages (24 octobre 2026)

| Sujet | Décision |
|---|---|
| Superposition | Mode de coloration **exclusif** « Vent » : le gris CROSS se confond avec l'asphalte de la surface, superposer rendrait le tracé illisible. |
| Mode par défaut | **Toujours « Pente »** : on ne change pas le sens des couleurs sans que la personne l'ait choisi. |
| Profil altimétrique web en mode Vent | **Reste en pente** : la lecture du relief est conservée. |
| Bascule mobile dans l'Aperçu | **Puce « Météo » sous la carte encastrée**, hors de la vue native (la carte n'est pas manipulable, `ride_groups_map.dart:290`) ; en plein écran, dans la feuille du hero comme `hillshade`. |
| Contraste du gris CROSS sur fond sombre | **Vérifié en recette**, nuance 6 dans les deux thèmes comme `TrackSurface` ; liseré ou tirets seulement si la recette le demande. |
| Pluie | **Goutte au point `leg.rainAlert`** (seuil serveur, 50 %, jamais dupliqué au client) **et probabilité brute sur chaque pastille** qui en a une. La pluie n'a pas de couleur (BRANDING §3.6 ; arbitrage ouvert au ledger `MOB-52`). |
| Flèche de vent sur la carte | **Absolue** (`direction + 180`, nord en haut). La flèche relative reste dans la frise. |
| Convention de distance | **Documentée dans le contrat dès le palier 1** (descriptions seulement, bump de version). |
| Périmètre du palier 3 | **La sortie solo et les étapes de voyage**, web et mobile. |

Règles communes :

- Le mode n'est proposé que si `hasForecast(leg.status)` (OK ou STALE) et qu'au moins un checkpoint
  porte une `weather`. Rien pour NOT_YET_AVAILABLE, NO_LOCATION, OUT_OF_RANGE, UNAVAILABLE, ni pour
  une sortie terminée ou annulée. Si un refetch perd la prévision, le mode retombe sur « Pente ».
- Un tronçon sans vent connu garde la couleur par défaut du tracé, **jamais le gris** (qui dit
  « travers »).
- Teintes : uniquement les tables générées depuis `brand-colors.yaml`.
- Textes FR/EN, français épicène.

## 5. Paliers

### Palier 1 — le vent sur le tracé (web M, mobile M, contrat S)

Un mode « Vent » qui colore le tracé (dos / travers / face), et une **légende en mots** avec les
parts (« Dos 32 km · Travers 18 km · Face 40 km »), qui porte « Prévision ancienne » en STALE et
« heures estimées à 25 km/h » si `speedIsDefault`.

**Web**

- `frontend/src/lib/weatherOnRoute.ts` (pur, hors du chunk carte) : `chainedDistances(tracks)`,
  `pointWinds(tracks, phases)` (vent au milieu de chaque segment via `phaseAt`, sur le modèle de
  `pointSurfaces`, `lib/trackSurface.ts:108-131`), parts pour la légende.
- `hooks/useRouteWindColors.ts` sur le modèle de `useRouteSurfaceColors.ts:27-30`.
- `RouteMapView.tsx` : prop optionnelle `lineColorAt` externe, prioritaire sur la surface ; le
  profil garde `colorBy` pente/surface (`:124`). Les autres écrans ne changent pas.
- Type propre à la page, `GroupColorBy = PlannerColorBy | 'wind'` : `PlannerColorBy` sert dans une
  dizaine de fichiers (planificateur, `RouteDetailView`, `RouteFullscreenView`, `GpxPreviewView`…),
  on ne l'élargit pas.
- `RouteSurfaceSummary.tsx` renvoie `null` sans surface (`:52-58`) : en extraire un `ColorByControl`
  affiché même sans surface (« Pente | Météo » ou « Pente | Surface | Météo »), plus `WindMapLegend`.
- `GroupRouteMap.tsx` : props `leg`, `attribution`, état `GroupColorBy` ; `RideGroupPage.tsx:309` les
  passe quand la condition du §4 est remplie.
- Crédit Open-Meteo : option `attribution` de la `Source` GeoJSON ; vérifier en recette qu'il reste
  visible sous le profil superposé (`RouteMapView.tsx:105-119`).
- Tests : `weatherOnRoute.test.ts` (deux traces dont `dist` repart à 0, bornes, segment inconnu),
  `GroupRouteMap.test.tsx`, `RideGroupPage.test.tsx` (pas de bascule en NOT_YET_AVAILABLE ni pour une
  sortie terminée ; bascule et badge en STALE), le contrôle sans surface.

**Mobile**

- `lib/features/rides/domain/ride_weather_map.dart` (sans widget) : `chainedMeasures(lines)` (saut
  nul — **pas** `PolylineIndex.fromLineStrings`, ou alors un mode `zeroGap` testé) ;
  `windSegmentColors(lines, segments, colorOf)` : une couleur par intervalle **dans chaque ligne
  brute**, contrat de `_appendSegments` (pas les sommets nettoyés de `PolylineIndex`).
- Jetons de trait `RelativeWind.stroke` (ou `mapWind*` dans `core/theme/pdl_colors.dart`) sur le
  modèle de `TrackSurface.stroke` ; la teinte `soft` des badges est trop pâle sur une carte.
- `ride_groups_map.dart` : paramètre `weatherLeg`, **transmis aussi à `fullscreenBuilder`** (`:179`) ;
  `segmentColors` dans `_tracks` quand `onlyGroup`, prévision et mode sont réunis ; légende en
  `overlays` (`:305`) ; `Semantics` de résumé via `exposureSummary`.
- `ride_group_overview_tab.dart:73` : `weatherLeg: widget.leg` ; puce « Météo » sous la carte.
- État du mode : provider en mémoire indexé par `RideKey`, partagé entre la carte encastrée et le
  plein écran.
- Mémoriser `segmentColors` par (route, leg) : `PdlMapTrack.==` compare par `listEquals` (`:81`) et
  `didUpdateWidget` repose toutes les couches au moindre changement.
- Tests : unitaire `ride_weather_map` (cas à deux traces), widget `RideGroupsMap` (légende selon le
  statut, paramètre transmis au plein écran).

**Contrat** : `API-138`, §6.

**Docs** : BRANDING §3.6, la nuance de carte de `RelativeWind`.

### Palier 2 — les pastilles aux checkpoints (web S-M, mobile M)

En mode Vent, une pastille par checkpoint. Une goutte au point `leg.rainAlert.distance`. Les
bornes km sont masquées en mode Vent.

**Arbitrages du palier 2 (24 octobre 2026, après la livraison du palier 1)** :

| Sujet | Décision |
|---|---|
| Quand | **En mode Météo seulement** : le même geste montre le vent sur le tracé et les pastilles ; « Pente » garde une carte épurée. |
| Au repos | **Compacte** : icône du ciel, température, flèche du vent absolue. |
| Détail | Heure de passage (zone de la sortie, `formatWeatherTime` / `useRendezvousFormat`), probabilité de pluie si présente, **quantité de précipitation** (`precipitation`, mm sur l'heure), vent en km/h et **rafales** (`wind.gusts`, absentes quand le modèle n'en a pas : ne rien afficher, jamais « 0 »). Unités par le formateur unique (impérial compris). Aucun changement de contrat : tout est déjà dans `WeatherConditionsDto`. |
| Ouverture du détail, web | **Clic → bulle** (`Popup` MapLibre) qui reste ouverte, atteignable au clavier, avec un titre accessible. |
| Ouverture du détail, mobile | **Tap → `PdlSheet` courte**, comme les points de parcours (`MOB-84`). |
| Bornes km | **Masquées en mode Météo.** |
| Mobile, carte encastrée | **Pas de pastilles** : plein écran seulement ; l'encastrée garde le tracé coloré et la légende. |
| Extrêmes de température | **Pastilles égales**, pas de mise en avant ; les verdicts restent dans la frise. |
| Crédit Open-Meteo mobile | **Traité dans ce palier** : `RideWeatherDto.attribution` descend jusqu'à la légende de la carte (encastrée et plein écran). |

- **Web** : prop `overlays?: ReactNode` sur `RouteTrackMap`, rendue dans `PedalonsMap` après
  `WaypointLayer`, sous `!trackHidden` (`RouteTrackMap.tsx:236-258`) ;
  `components/weather/WeatherCheckpointMarkers.tsx` (`Marker` DOM sur le modèle de `KmMarker`, avec
  `WindArrow`, `WeatherIcon`, `useUnits`, `useRendezvousFormat(ride.timezone)`, `aria-label` par
  `useCheckpointSummary`) ; position par `checkpointPoint(tracks, d)` dans `weatherOnRoute.ts`
  (premier sommet de distance chaînée ≥ d − 0,5).
- **Mobile** : une liste générique `markers` (position + widget, égalité de valeur) dans le
  `WidgetLayer` existant de `PdlMap` (`pdl_map.dart:539-549`), sans DTO dans `core/pdl`
  (`README.md:42`) ; pastilles **en plein écran seulement** ; `PdlWindArrow` avec `windArrowAngle`.
- Tests : web `checkpointPoint` sur deux traces, rendu des marqueurs (aucun sans `weather`) ; mobile
  positions et égalité des marqueurs.

### Palier 3 — liens, sortie solo, étapes de voyage (web M, mobile M)

- **Web** : remonter l'état `Selection` de `RouteWeather.tsx:105` dans `RideGroupPage` en props
  contrôlées : une pastille sélectionne la ligne du tableau, la ligne allume le point sur la carte.
- **Mobile** : un sliver de carte en tête de `RideGroupWeatherTab._content`
  (`ride_group_weather_tab.dart:151`), lié à la frise par `setWaypointFocus` ou `setCursor`.
- **Sortie solo** : même mode sur la carte du détail (`soloLeg`, `RideDetailPage.tsx` ;
  `ride_detail_page.dart`).
- **Étapes de voyage** : même mode sur la carte de l'étape (web `StageDetailPage.tsx`,
  `StageFullscreenMapPage.tsx` ; mobile `trip_map.dart` avec l'étape choisie, et
  `stage_weather_page.dart`, qui partage `weather_leg_sections.dart`). Le `TripWeather` de l'étape
  porte les mêmes checkpoints et segments : la logique des paliers 1 et 2 doit donc rester
  indépendante de la page du groupe.

**Arbitrages du palier 3 (25 octobre 2026, après la livraison du palier 2)** — ils font foi sur
la liste ci-dessus. Livré en **deux lots**, chacun avec sa revue et son commit.

*Lot A — liens, plein écran du groupe, onglet Météo mobile*

| Sujet | Décision |
|---|---|
| Web, pastille → tableau | **La bulle s'ouvre et la ligne du tableau « Heure par heure » se sélectionne**, sans faire défiler la page. |
| Web, tableau → carte | **La pastille correspondante s'allume** (et sa bulle s'ouvre si le mode Météo est actif), sans bouger la caméra ; en mode Pente, rien ne bascule tout seul. |
| Web, plein écran du groupe | **Nouvelle route `rideGroupMap`** dans `contracts/routes.yaml` : `/teams/{teamSlug}/rides/{rideSlug}/groups/{groupId}/map`, `/equipes/{teamSlug}/sorties/{rideSlug}/groupes/{groupId}/carte`, **web seul** (pas de `mobile`, pas de `deeplink`), sur le modèle de `stageMap`. Puis `pnpm generate-routes`. Le bouton plein écran de la page du groupe y mène au lieu de `routeMap`. La page porte le mode Météo (tracé, légende, pastilles, bulle), avec un `prefetch` déclaré une seule fois dans un module compagnon (docs/SSR-data-loading.md). |
| Mode à l'arrivée sur le plein écran | **Celui de la page**, porté par un paramètre d'URL (par exemple `?couleur=meteo`, nom à choisir selon les conventions de `useUrlFilters`) : un lien partagé montre la même carte. Sans paramètre, Pente. Une prévision absente fait retomber sur Pente, comme sur la page. |
| Mobile, onglet Météo | **Carte encastrée, toujours en mode Météo** (tracé coloré par le vent d'office, pas de puce, légende et crédit), non manipulable ; un tap ouvre le plein écran existant ; toucher un point de la frise y place un curseur (`setCursor` / `setWaypointFocus`). Rien si le leg n'a pas de prévision (`showsWindOnMap`). |

*Lot B — sortie solo et voyages*

| Sujet | Décision |
|---|---|
| Sortie solo, détail | **Même mode** sur la carte du détail (web `RideDetailPage` avec `soloLeg`, mobile `ride_detail_page.dart`) : sélecteur / puce, légende, pastilles. |
| Sortie solo, plein écran web | **Nouvelle route `rideMap`** : `/teams/{teamSlug}/rides/{rideSlug}/map`, `/equipes/{teamSlug}/sorties/{rideSlug}/carte`, web seul ; elle affiche le groupe unique (l'URL ne dévoile pas l'id d'un groupe sans page). Même paramètre de mode que `rideGroupMap`. |
| Étape, détail et plein écran | **Même mode** sur la carte d'une étape (web `StageDetailPage` et `StageFullscreenMapPage` via `stageMap`, avec le même paramètre de mode ; mobile la carte de l'étape choisie). |
| Carte d'ensemble du voyage | **Toutes les étapes** en mode Météo : chaque tracé coloré par le vent de son étape (à son jour) et les pastilles de toutes les étapes (web `TripDetailPage`, mobile `trip_map.dart`). La lisibilité à beaucoup d'étapes est à vérifier en recette. |
 `API-138` — la convention de distance dans le contrat (S, palier 1)

Descriptions seulement, dans les DTO Java (puis skill `contract-first-api`) :

- `WeatherCheckpointDto.distance`, `WindSegmentDto.fromDistance/toDistance` : mètres depuis le
  départ, les traces du parcours mises bout à bout dans l'ordre de leurs id, **sans compter le saut
  entre la fin d'une trace et le début de la suivante** ;
- `GeoJsonLineString` : la 4ᵉ composante est la distance depuis le début de **cette** trace (elle
  repart de 0 à chaque trace).

Bump de patch de `pedalons.api.version` (`11.16.0` → `11.16.1`, livré), comme pour toute
description seule. Aucun
changement de comportement : les tests backend existants (`RouteSampleLookupTest`) couvrent déjà la
convention, et c'est la personne propriétaire qui les lance.

## 7. Options écartées

| Option | Raison |
|---|---|
| Coordonnées dans les DTO météo | Une sortie PUBLIC peut pointer sur un parcours TEAM (plan archivé `:39`) ; la distance suffit. |
| `RainSegmentDto` et hachure de pluie | Contrat et backend en plus, hachure à créer dans `core/pdl` (aucun `line-dasharray`) ; la goutte au point `rainAlert` réutilise le seuil serveur. À revoir si les retours le demandent. |
| Couleur de pluie, échelle de température | Les conditions n'ont pas de couleur (BRANDING §3.6) ; si on en ajoute, par `brand-colors.yaml`. |
| Vent superposé à la pente ou à la surface | Illisible (gris CROSS contre asphalte gris). |
| Flèche relative sur la carte | Repère de la personne qui roule, contredit une carte orientée nord. |
| Échantillonnage plus fin que 15 km, interpolation au client | Plus d'appels Open-Meteo (budgets `application.properties:400-407`) pour une précision du même ordre que le modèle ; « tous les calculs côté serveur » (plan archivé `:38`). |
| Vent absolu dans `WindSegmentDto` | Redondant : `segment.fromDistance == checkpoint.distance`, même `round0`. |
| Radar ou champ de vent hors du tracé | Hors du modèle, et pas de coordonnées. |
| Couche native de symboles mobile | Taille L pour 6 à 15 points ; seulement si le `WidgetLayer` pose problème en plein écran. |
| Pastilles sur la carte mobile encastrée | Trop petite, non touchable. |
