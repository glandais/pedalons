# Éditeur de parcours : l'existant dans Pédalons

*État des lieux du 17 octobre 2026, vérifié dans le code à cette date (commit `f5e819ac` + lecture).
Les chemins sont relatifs à la racine du dépôt. Document jumeau : l'état de l'art des services
grand public dans [2026-10-17-editeur-parcours-etat-de-l-art.md](2026-10-17-editeur-parcours-etat-de-l-art.md),
qui contient aussi la confrontation et les recommandations.*

## Sommaire

1. [En une page](#1-en-une-page)
2. [Périmètre et activation](#2-périmètre-et-activation)
3. [Architecture du planificateur web](#3-architecture-du-planificateur-web)
4. [Modèle de données et algorithme](#4-modèle-de-données-et-algorithme)
5. [Interactions](#5-interactions)
6. [Routage et Valhalla](#6-routage-et-valhalla)
7. [Altitude, pipeline GPX et stockage](#7-altitude-pipeline-gpx-et-stockage)
8. [Consultation : carte et profil](#8-consultation--carte-et-profil)
9. [Outils GPX](#9-outils-gpx)
10. [Mobile, Karoo, Garmin](#10-mobile-karoo-garmin)
11. [Tests](#11-tests)
12. [Forces](#12-forces)
13. [Limites et manques](#13-limites-et-manques)
14. [Ce qui est déjà au ledger](#14-ce-qui-est-déjà-au-ledger)

---

## 1. En une page

Pédalons a **un éditeur de parcours web fonctionnel mais minimal**, derrière un drapeau par équipe et
par domaine. Il tient en trois fichiers : `RoutePlanner.tsx` (la carte et les gestes),
`useRoutePlanner.ts` (l'état et l'historique), `lib/planner.ts` (l'algorithme pur). Il sait ajouter,
insérer, déplacer et supprimer des points, router chaque segment via Valhalla auto-hébergé avec six
profils, tracer en ligne droite avec Ctrl, annuler et rétablir. C'est le socle attendu d'un éditeur ;
rien de plus.

Tout ce qui fait la différence entre « ça marche » et « on préfère ça à Komoot » manque encore :

| Attendu d'un éditeur moderne | Pédalons |
|---|---|
| Profil altimétrique pendant l'édition | Absent (distance et D+ seulement) |
| Inverser, aller-retour, boucler vers le départ | Absent |
| Recherche d'adresse, « partir d'ici » | Absent de l'éditeur |
| Surface, pente, popularité sur la carte | Absent (tracé d'une seule couleur) |
| Surface déduite du routage | Non : saisie manuelle, Valhalla ne renvoie que la forme |
| Points d'intérêt / waypoints d'auteur | Absent |
| Édition sur mobile | Non : consultation seulement |
| Brouillon, sauvegarde automatique | Absent |
| Clavier et accessibilité | Marqueurs sans rôle ni nom, aucune action clavier |

La force du système est **en aval** de l'éditeur : un seul pipeline pour toutes les sources (dessin,
import, fusion), altitude IGN LiDAR HD à 1 m avec ponts et tunnels, D+ à bande morte, export GPX et
FIT, envoi automatique vers Garmin, Wahoo et Hammerhead. L'éditeur est aujourd'hui la partie la moins
aboutie d'une chaîne par ailleurs solide.

Trois défauts à corriger indépendamment de toute refonte :

- **Ctrl+Z dans le champ « Nom » annule le tracé** : le gestionnaire est sur `window` et ne regarde
  pas l'élément focalisé (`frontend/src/components/planner/RoutePlanner.tsx:224-235`).
- **`POST /api/router` ne vérifie aucun drapeau** : tout utilisateur connecté peut router, même sur
  un domaine où le planificateur est fermé ; seul l'enregistrement est bloqué
  (`backend/src/main/java/fr/pedalons/api/router/RouterResource.java`). À régler avant le palier
  « Club » du plan de monétisation, qui prévoit justement de bloquer cet endpoint.
- **Aucun timeout vers Valhalla** : `application.properties` ne définit que l'URL
  (lignes 433, 462, 573) ; `open-meteo` en a un, pas Valhalla.

---

## 2. Périmètre et activation

**Deux drapeaux, tous deux faux par défaut** (`V32__route_planner_toggle.sql`) :

| Drapeau | Gouverne | Qui le règle |
|---|---|---|
| `Team.enableRoutePlanner` → `TeamDetailDto.enableRoutePlanner` | Dessiner un parcours d'équipe | Admin plateforme (`AdminTeamService.java:73`, `TeamForm.tsx:372`) |
| `Domain.enableGpxPlanner` → `ConfigDto.enableGpxPlanner` → `isGpxPlannerEnabled()` | Dessiner dans les outils GPX (sans équipe) | Admin plateforme (`AdminDomainService.java`, `DomainFormModal.tsx:73`) |

- Une équipe migrée de biketeam naît avec le planificateur ouvert (`MIG-13`).
- Le planificateur n'est proposé **qu'en création ou sur un parcours à une seule trace**
  (`EditRoutePage.tsx:80-82`, `EditGpxPreviewPage.tsx`). Un GPX multi-traces n'est pas éditable.
- Quel domaine a `enableGpxPlanner` allumé en production n'est écrit nulle part dans le dépôt ; seul
  le domaine dédié de l'e2e (`plannerSite`) est documenté.
- Le plan de monétisation (`docs/plans/2026-10-17-monetisation.md`, rien de décidé) ferait du
  planificateur une fonction du palier « Club », avec un `403 PLAN_REQUIRED` sur `/api/router`.

**Où il apparaît** : `RouteEditor.tsx` (création et édition de parcours d'équipe, bascule
« fichier GPX / dessiner ») et `GpxPreviewEditor.tsx` (outils GPX : dessiner de zéro, ou redessiner
un aperçu). Les deux ne sont que des enveloppes de formulaire autour de `RoutePlanner`.

---

## 3. Architecture du planificateur web

| Fichier | Rôle | Taille |
|---|---|---|
| `frontend/src/components/planner/RoutePlanner.tsx` | Carte MapLibre (`react-map-gl/maplibre`), marqueurs, gestes souris et tactiles, barre d'outils, menu contextuel | 814 l. |
| `frontend/src/hooks/useRoutePlanner.ts` | État du tracé, historique annuler/rétablir, profil courant, exécution des opérations | 216 l. |
| `frontend/src/lib/planner.ts` | Algorithme pur : création, ajout, insertion, déplacement, suppression, Douglas-Peucker, appels au routeur | 328 l. |
| `components/planner/RouterProfileSelector.tsx`, `UndoRedoControl.tsx`, `RoutePlannerMiniMap.tsx` | Sélecteur de profil, boutons annuler/rétablir, mini-carte de précision | |

- **Pas de store** : tout est en `useState` local ; le seul état partagé est le style de carte
  (`mapStyleStore`, relief 3D).
- **Pas de bibliothèque d'édition tierce** : les gestes sont écrits à la main sur les événements
  MapLibre.
- Aucun `TODO` ni `FIXME` dans `planner/`, `route/`, `gpxtool/`, `map/`.

---

## 4. Modèle de données et algorithme

**Un tableau plat de points, pas de segments.** `Route = { points, dist, ascend, index: KDBush }`
avec `RoutePoint = { id, idx, lng, lat, ele?, manual, rdpDistance?, zoom }` (`planner.ts:11-27`).

- Les **points de contrôle** sont ceux marqués `manual`, plus le premier et le dernier
  (`useRoutePlanner.ts:103-105`). Les autres sont les points renvoyés par le routeur.
- Un segment n'existe pas comme objet : déplacer un point recalcule entre les deux ancres voisines
  *visibles au zoom courant* (`useRoutePlanner.ts:53-86`), pas entre les deux points manuels
  voisins. C'est une originalité : l'« ancre » dépend du zoom.
- **Simplification à 5 m** (Douglas-Peucker, `planner.ts:85, 244-287`) à chaque `computeRoute`, et
  chaque point reçoit un zoom minimal d'affichage (`getZoomLevelForDistance`) pour n'afficher les
  ancres qu'au zoom pertinent (`RoutePlanner.tsx:439-451`).
- **Distance et D+ affichés pendant l'édition** : calculés côté client, somme des écarts positifs
  **sans bande morte**, sur des points déjà simplifiés (`planner.ts:36-53`). Le backend renvoie
  `dist` et `ascend` à chaque segment, **ignorés** : seul `route.coordinates` est lu
  (`planner.ts:241`). Le D+ affiché pendant l'édition ne sera donc pas celui du parcours enregistré.
- **Ce qui part à l'enregistrement** : les `[lng, lat]` du tracé simplifié, sans altitude
  (`RoutePlanner.tsx:122-132`). Les points de contrôle ne sont **pas conservés** : rouvrir un
  parcours pour l'éditer repart d'une trace re-simplifiée (`createRoute`, `planner.ts:31-34`), dont
  tous les points sont des ancres potentielles. L'intention d'auteur (« je voulais passer par là »)
  est perdue à la sauvegarde.

---

## 5. Interactions

| Geste | Comportement | Référence |
|---|---|---|
| Clic sur la carte | Ajoute un point en fin de tracé, route le segment | `RoutePlanner.tsx:290-335` |
| Ctrl maintenu | Ligne droite au lieu du routage (ajout, insertion, déplacement, suppression) | `:222-238` |
| Glisser un marqueur | Déplace et reroute entre les ancres voisines, liaisons en pointillés pendant le geste | `:247-280, 453-494` |
| Survol du tracé | Point fantôme ; appuyer-glisser insère un point | `:337-430` |
| Tap à < 25 px du tracé (tactile) | Insère un point | `:300-321` |
| Clic droit sur un marqueur | Supprime | `:282-288` |
| Appui long 500 ms (tactile) | Menu « Supprimer le point » | `:184-220, 755-784` |
| Corbeille | Tout effacer | `:534-538` |
| Ctrl/Cmd+Z, Ctrl/Cmd+Maj+Z, boutons | Annuler, rétablir (snapshots complets de `Route`) | `useRoutePlanner.ts:95-191` |
| Touche « h », bouton | Masquer le tracé | `useHideTrackKey` |
| Mini-carte 200×200 au zoom 15 | Suit le curseur ; bureau seulement | `RoutePlannerMiniMap.tsx` |

**Textes d'aide** (`locales/fr/common.json:1386-1387`) : « Cliquer pour ajouter, glisser pour
déplacer, clic droit pour supprimer », version tactile avec « appui long ». Le mode Ctrl n'est
mentionné nulle part dans l'interface.

**Comportements fragiles relevés** :

- Aucun verrou pendant un calcul : un clic pendant `isLoading` enchaîne une opération sur
  `routeRef.current` sans annuler la requête précédente (`useRoutePlanner.ts:113-133`).
- Erreur affichée brute (`err.message`, sinon `'Failed'` non traduit, `useRoutePlanner.ts:129`).
- Profil `FASTBIKE` par défaut, jamais mémorisé (`useRoutePlanner.ts:90`).
- Détection tactile une seule fois au montage (`'ontouchstart' in window`).
- Pas de mode ligne droite au tactile.

---

## 6. Routage et Valhalla

**Contrat** : `POST /api/router` avec `{ from, to, profile }`, un appel **par segment**, réponse
`{ route (LineString 3D), dist, ascend }`. `@RolesAllowed("user")`, aucune vérification de drapeau,
aucune limite de débit propre.

**Six profils** (`RouterProfile.java:10-15`, libellés `common.json:1392-1398`) :

| Profil | Costing Valhalla | Options |
|---|---|---|
| BIKE | bicycle | `bicycle_type: hybrid` |
| FASTBIKE | bicycle | `road`, `use_roads: 1`, `avoid_bad_surfaces: 1` |
| GRAVEL | bicycle | `cross` |
| MTB | bicycle | `mountain` |
| RUN_HIKE | pedestrian | |
| MOTORCYCLE | motorcycle | |

**Ce qui est demandé à Valhalla** : deux `locations`, un `costing`, ses options. **Ce qui est lu** :
`trip.legs[].shape` (polyline6), rien d'autre (`ValhallaClient.java`, `RouterService.java:99-143`).
Ni surface, ni type de voie, ni pente, ni les `maneuvers` (instructions de virage), ni
`use_hills`/`use_ferry`/`avoid_locations`, ni `exclude_polygons`, ni l'altitude de Valhalla.
L'altitude est mise à 0 puis réécrite par le pipeline IGN (le commentaire « will be fixed by SRTM »
ligne 124 est périmé).

**Exploitation** (`docker-compose.shared.yml:26-63`, `docs/OPERATIONS.md` § Valhalla) : image
`valhalla-scripted`, `france-latest.osm.pbf` par défaut (couverture France), `build_elevation True`
sans usage côté backend, 4 threads, environ 17 Go de tuiles, mise à jour sans coupure (`OPS-43`),
pas de limite mémoire, pas de timeout côté client.

**Erreurs** : toute exception Valhalla devient `ErrorCode.UNKNOWN` (`RouterService.java:105-108`)
alors que l'OpenAPI annonce un 503 ; un trajet vide renvoie une ligne vide.

---

## 7. Altitude, pipeline GPX et stockage

Tout tracé, quelle que soit sa source, passe par `GpxPipeline` (version 2,
`backend/.../service/route/GpxPipeline.java:82-102`) :

1. **Altitude** : IGN LiDAR HD (terrain 1 m, modèle de surface pour les ponts), Mapterhorn en repli,
   cache disque `DemTileStore` ; correction des ponts et tunnels (`API-104`, `API-106`).
2. Lissage sur 150 m.
3. **D+ à bande morte**, mesuré *avant* simplification (décision `API-104` à ne pas défaire).
4. Douglas-Peucker 3 m, puis rééchantillonnage à 10 m au plus (`GpxLimits.RESAMPLING_STEP_METERS`).
5. Détection et nommage des cols (`ClimbNaming`), estimation du vent (`WindEstimator`).

**Limites** (`GpxLimits.java`) : fichier 10 Mo, 4 000 km cumulés, 100 000 points pour le
planificateur, fusion de 2 à 10 fichiers et 16 pièces.

**Stockage** : `gpx_tracks` en PostGIS `LineString 4326` + JSONB `{lat, lng, ele, dist}` + JSONB
`climbs` ; `gpx_waypoints` en `Point` ; `Route` porte distance, D+, D−, hilliness, `surfaceType`
manuel (ROAD / GRAVEL / MTB / MIXED), départ et arrivée, vent. Les aperçus GPX (`GpxPreview`) sont en
JSONB seul, purgés à 30 jours. S3 : `original.gpx`, `filtered.gpx`, `route.fit`, miniatures claire
et sombre (rendu par tileserver, échec non bloquant).

---

## 8. Consultation : carte et profil

Ce que l'éditeur n'a pas, la **vue de consultation** l'a en partie :

- `ElevationChart.tsx` (Chart.js) : survol synchronisé carte ↔ profil dans les deux sens, montées
  colorées par pente (`getPointClimbGradient`), info-bulles des cols, zoom et déplacement en plein
  écran (`chartjs-plugin-zoom`, `WEB-80`).
- `RouteTrackMap.tsx` : tracé coloré par pente des montées, repères kilométriques, flèches de sens.
- `PedalonsMap.tsx` : relief 3D et ombrage (`raster-dem` servi par `/api/config`), fonds de carte
  servis, aucun codé en dur ; tuiles MVT pour les cartes multi-parcours (`RoutesTileMap.tsx`).
- Défaut ouvert `WEB-81` : plusieurs traces empilées sur le même axe.

Le mobile colore le tracé **par pente de chaque segment** (`track_slope_colors.dart`), le web **par
partie de montée** : deux règles différentes pour la même donnée.

---

## 9. Outils GPX

`GpxToolsPage.tsx` : voir un fichier, fusionner 2 à 10 fichiers avec ordre et sens optimaux choisis
par le serveur (`API-112`, `WEB-87`), dessiner de zéro, carte vierge (`WEB-89`), « Mes fichiers »
(30 jours). Un aperçu se télécharge en GPX et FIT, s'envoie vers un appareil, se partage, et se
convertit en parcours d'équipe avec **surface forcée à ROAD** (`GpxPreviewView.tsx:66-79`).

Absents : nettoyage ou découpage interactif, import par URL ou depuis OpenRunner / VisuGPX (refusés,
`API-113`, `API-114`, risque SSRF).

---

## 10. Mobile, Karoo, Garmin

**Mobile Flutter : consultation seulement.** Les routes `gpxTools*` sont `mobile: false` dans
`contracts/routes.yaml`, `routeNew` et `routeEdit` n'ont pas de variante mobile, et aucun code de
`mobile/lib` n'appelle `/api/router`. L'app utilise `maplibre ^0.3.6`, un profil altimétrique
interactif avec curseur partagé (`pdl_elevation_profile.dart`, `route_cursor_controller.dart`),
télécharge et partage GPX et FIT, envoie vers un service GPS. Pas de navigation guidée.

**Karoo** : `GET /api/device/routes`, puis `POST …/sync?type=hammerhead` ; le serveur pousse le GPX
filtré vers le cloud Hammerhead. **Garmin** : `GET /device/routes` et téléchargement direct du FIT.
**Envoi automatique** (`API-120`, `API-121`, `GPS_SYNC_ENABLED` vrai en prod depuis le 16/10/2026) :
opt-in par connexion, fenêtre 7 jours avant la sortie, retrait 24 h après.

Conséquence : **l'auteur ne reçoit aucune instruction de virage** d'origine Pédalons. Le FIT et le
GPX portent la trace et les waypoints ; les appareils recalculent eux-mêmes les manœuvres.

---

## 11. Tests

| Couche | Couvert | Non couvert |
|---|---|---|
| Frontend unitaire | `ElevationChart`, `trackDistanceRange`, `useMapChartZoomSync`, `GpxPreviewView`, `GpxToolsPage`, `mapStyles`, `routeColors` | **`lib/planner.ts`, `useRoutePlanner`, `RoutePlanner.tsx`** |
| Frontend e2e | `flow-gpx-tools`, `flow-routes`, `route-maps` | `gpx-planner.e2e.ts` existe mais est **écarté en CI** (`E2E_NO_ROUTING`, pas de Valhalla) |
| Backend | `GpxPreviewResourceTest` (dont from-points), `RouteResourceTest` (`ROUTE_PLANNER_DISABLED`), pipeline, sanitizer, merger, DEM, polyline6, miniatures, synchro GPS | **`RouterService`, `RouterResource`** |
| Mobile | elevation builder, cursor, climbs | |
| Karoo, Garmin | aucun test de parcours | |

L'algorithme de l'éditeur, pur et sans dépendance (`lib/planner.ts`), est le candidat le plus
facile et le plus rentable à tester ; il ne l'est pas.

---

## 12. Forces

- **Chaîne aval unique et soignée** : altitude LiDAR 1 m avec ponts et tunnels, D+ à bande morte,
  cols nommés, vent, FIT et GPX, miniatures, envoi automatique vers trois écosystèmes d'appareils.
- **Routage auto-hébergé** : six profils, aucune dépendance à un quota tiers, données France
  rafraîchies sans coupure.
- **Socle d'édition correct** : insertion par glisser sur le tracé, déplacement reroutable, ancres
  dépendantes du zoom (idée originale et utile), undo/redo, ligne droite, gestes tactiles de base,
  mini-carte de précision, zones de toucher de 44 px.
- **Cartes** : MapLibre partout (web et mobile), fonds servis par le serveur, relief 3D, tuiles MVT.
- **Algorithme isolé** dans un module pur, donc testable et réutilisable tel quel.

## 13. Limites et manques

Par ordre d'impact pour quelqu'un qui dessine un parcours de club :

1. **Pas de profil altimétrique pendant l'édition**, et un D+ d'édition qui ne correspond pas à
   celui du parcours enregistré (client, sans bande morte, `dist`/`ascend` du backend ignorés).
2. **Pas de recherche d'adresse ni de géolocalisation** dans l'éditeur : on commence en faisant
   défiler la carte à la main.
3. **Pas d'inversion, d'aller-retour ni de bouclage** : les trois opérations les plus fréquentes
   après le tracé lui-même.
4. **Surface invisible et saisie à la main** : Valhalla connaît le revêtement de chaque arête et ne
   le renvoie pas ; le tracé est monochrome ; un aperçu enregistré devient « ROAD » d'office.
5. **Points de contrôle perdus à l'enregistrement** : rééditer un parcours, c'est repartir d'une
   trace brute.
6. **Pas d'édition sur mobile**, alors que l'app a déjà MapLibre et le profil.
7. **Pas de waypoints d'auteur** (ravitaillement, regroupement, danger) ni d'instructions de virage.
8. **Clavier et accessibilité** : Ctrl+Z capturé dans les champs texte, marqueurs sans rôle ni nom,
   aucune action clavier, mode Ctrl non documenté dans l'interface, sans équivalent tactile.
9. **Robustesse** : pas de verrou pendant le calcul, erreurs non traduites, profil non mémorisé,
   pas de timeout Valhalla, erreurs Valhalla en `UNKNOWN`.
10. **`/api/router` ouvert** à tout utilisateur connecté, quel que soit le drapeau.
11. **Aucun test** de l'algorithme ni du routage ; l'e2e de routage ne tourne pas en CI.
12. **Multi-traces** non éditable, et mal affiché (`WEB-81`).
13. **Commentaires périmés** (« SRTM » dans `RouterService.java:124` et dans l'entrée `API-44`).

## 14. Ce qui est déjà au ledger

- Ouvert : `WEB-81` (multi-traces), `API-27` (coût du lot de géométries).
- Au backlog, non cochés : heatmap, panier de parcours, style de carte vélo, variantes d'étape,
  favoris (`docs/BACKLOG.md:71-89`).
- Refusés : `API-113`, `API-114` (import par URL), `API-124` (azimut de vent vcyclist).
- Livrés, décisions à ne pas défaire : `API-104` (D+ avant simplification, 10 m max entre points,
  20 req/s vers l'IGN), `API-112` et `WEB-87` (fusion exacte, ordre choisi par le serveur), `WEB-80`
  (plugin zoom chargé après montage), `WEB-89` (carte vierge ne lit que `/api/config`), `OPS-43`
  (Valhalla sans `force_rebuild`), `API-120`, `API-121` (envoi automatique opt-in, un appareil ne
  lit que son service), `MIG-13`.
- `BILL` (plan de monétisation, non décidé) : planificateur au palier « Club ».

Aucune entrée du ledger ne porte aujourd'hui sur l'éditeur lui-même (profil altimétrique d'édition,
inversion, recherche d'adresse, surface, mobile). Les propositions sont dans le document jumeau.
