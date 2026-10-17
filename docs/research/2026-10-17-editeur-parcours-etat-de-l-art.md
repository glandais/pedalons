# Éditeur de parcours : état de l'art et pistes pour Pédalons

*Recherche du 17 octobre 2026. Sources web lues et recoupées ce jour (voir [§9](#9-sources-et-fiabilité)) ;
l'état de Pédalons est celui de [2026-10-17-editeur-parcours-existant.md](2026-10-17-editeur-parcours-existant.md),
vérifié dans le code le même jour. Les chemins sont relatifs à la racine du dépôt.*

## Sommaire

1. [En une page](#1-en-une-page)
2. [Méthode et limites](#2-méthode-et-limites)
3. [Le patron d'édition dominant](#3-le-patron-dédition-dominant)
4. [Routage et re-routage](#4-routage-et-re-routage)
5. [Ce que les éditeurs montrent](#5-ce-que-les-éditeurs-montrent)
6. [GPX, appareils, navigation](#6-gpx-appareils-navigation)
7. [Mobile et club](#7-mobile-et-club)
8. [Confrontation et propositions](#8-confrontation-et-propositions)
9. [Sources et fiabilité](#9-sources-et-fiabilité)
10. [Questions ouvertes](#10-questions-ouvertes)

---

## 1. En une page

Les éditeurs de référence (Komoot, Strava, Ride with GPS, gpx.studio, BRouter-web, Garmin Connect,
Outdooractive) **convergent sur un même patron** : deux clics donnent un tracé routé, des points de
passage l'affinent, et l'on corrige en **tirant directement la ligne**, ce qui insère un point et ne
recalcule que les deux segments voisins. Autour de ce noyau, les attendus sont stables depuis
plusieurs années : annuler/rétablir, inverser, aller-retour, boucle, tracé libre par segment avec
avertissement, recherche d'adresse, profil altimétrique synchronisé avec la carte, et une lecture
du revêtement.

**Pédalons a le noyau et presque rien autour.** Son éditeur gère déjà le drag sur la ligne,
l'insertion, le re-routage partiel et l'undo ; il lui manque le profil pendant l'édition, les
opérations structurelles (inverser, aller-retour, boucle), la recherche d'adresse, la surface, et
toute édition sur mobile.

Trois constats orientent les choix :

1. **gpx.studio est le modèle technique le plus proche** : MapLibre, ancres générées par
   Douglas-Peucker et dévoilées selon le zoom, re-routage entre ancres voisines. Pédalons a
   *déjà* repris ce schéma (`lib/planner.ts`) ; la suite logique est de reprendre aussi son profil
   altimétrique colorable et sa persistance des attributs par point.
2. **Valhalla couvre nativement ce que les concurrents font payer** : profils route/gravel/VTT,
   « éviter le trafic » (`use_roads`), « éviter les côtes » (`use_hills`), routes à éviter
   (`exclude_locations`, `exclude_polygons`), instructions de virage (`maneuvers`), et le revêtement
   de chaque arête via `trace_attributes`. Rien de cela n'est aujourd'hui demandé au moteur.
3. **Le différenciateur club n'est pas l'éditeur lui-même** mais ce qu'on en fait : un parcours de
   club annoté (regroupements, ravitaillements, dangers), envoyé automatiquement sur les compteurs
   des inscrits *avec* ces points. Pédalons a déjà l'envoi automatique ; il lui manque les points.

Les propositions classées sont en [§8](#8-confrontation-et-propositions). Les cinq premières :
profil altimétrique dans l'éditeur, inverser / aller-retour / boucle, recherche d'adresse et
« partir d'ici », surface déduite de Valhalla et affichée, points de parcours d'auteur exportés
en FIT.

---

## 2. Méthode et limites

- **Recherche web structurée** en cinq angles (UX d'édition, routage, données affichées, GPX et
  appareils, club et retours utilisateurs) : 21 sources lues, 100 affirmations extraites, les 25
  principales vérifiées chacune par trois relectures contradictoires ; 22 confirmées, 3 réfutées
  (listées en [§9](#9-sources-et-fiabilité)). Puis un complément manuel sur Strava, Ride with GPS,
  Openrunner, Garmin Connect, Mapy.com et la documentation Valhalla.
- **Bien couvert** : Komoot (doc officielle mise à jour le 15/10/2026), gpx.studio (doc et code
  source), BRouter-web / bikerouter.de, Ride with GPS mobile, Valhalla (doc et code du costing vélo).
- **Couvert par des sources secondaires seulement** : Strava (un article support officiel, le reste
  en presse), Ride with GPS web (son centre d'aide refuse les lectures automatisées), Openrunner
  (presse française 2022-2023), Garmin Connect (blog Garmin et presse), Mapy.com (fiches
  magasin).
- **Non couvert** : Bikemap, Cycle.travel, Plotaroute, Wandrer, VeloViewer (hors export Garmin).
  Les angles *heatmap*, *POI*, *hors ligne*, *collections de club* n'ont produit aucune
  affirmation vérifiable : ils sont traités brièvement, sur la foi de la presse.
- **Dérive** : les docs produit sont rarement datées et les planificateurs changent vite (les
  libellés de boutons Komoot diffèrent déjà entre deux pages officielles). Ce document décrit des
  *patrons*, pas des captures d'écran.
- Aucun test en main n'a été fait : tout vient de la documentation, du code public et de la presse.

---

## 3. Le patron d'édition dominant

### 3.1 Le noyau, partout identique

Confirmé pour Komoot, Strava, Outdooractive et gpx.studio (vote 3-0) :

- **Départ + arrivée** cliqués produisent un tracé routé ; chaque clic suivant ajoute un point en
  fin de tracé.
- **Tirer la ligne** n'importe où crée un nouveau point de passage et recolle aux routes
  (« magnétique », selon le comparatif Tour Magazin de 2024). Déplacer un point existant ne change
  pas l'ordre.
- **Re-routage partiel** : déplacer une ancre ne recalcule que les segments vers l'ancre précédente
  et la suivante ; supprimer une ancre ne recalcule que précédent → suivant. Vérifié dans le code
  de gpx.studio (`moveAnchor()` passe exactement `[previous, anchor, next]` au routeur).
- **Insertion** : point fantôme au survol du segment puis glisser (bureau) ; **tap sur le segment**
  (tactile).

**Pédalons** fait tout cela (`RoutePlanner.tsx`), à une nuance près : l'ancre voisine est celle
*visible au zoom courant*, pas forcément un point manuel. C'est le comportement de gpx.studio
(`getNeighbouringAnchors()` filtré sur le zoom), donc un choix défendable, mais il surprend si on
vient de Komoot, où les points de passage sont une liste explicite.

### 3.2 Deux modèles de « point »

Deux philosophies coexistent, et la différence compte pour Pédalons :

| | Komoot, Strava, RWGPS, Garmin | gpx.studio, BRouter-web, Pédalons |
|---|---|---|
| Point de passage | Objet nommé, listé dans un panneau latéral, réordonnable, avec adresse | Ancre anonyme sur le tracé |
| Insertion par clic hors tracé | Komoot l'insère « au meilleur endroit » de la séquence ; depuis la liste, juste avant l'arrivée | Toujours en fin de tracé |
| Persistance | Les points de passage sont enregistrés avec le parcours et rééditables | Pédalons : perdus à l'enregistrement, régénérés par Douglas-Peucker à la réouverture |
| GPX importé | Komoot : « route » recalculée, le tracé d'origine peut bouger | gpx.studio : ancres générées, **le tracé d'origine ne bouge pas** tant qu'on n'y touche pas |

gpx.studio a l'avantage décisif pour un club qui importe beaucoup de GPX existants : **un fichier
importé reste fidèle**, et devient éditable par ancres dévoilées selon le zoom
(`MIN_ANCHOR_ZOOM`/`MAX_ANCHOR_ZOOM`, `getZoomLevelForDistance()`, une couche MapLibre par
niveau). Pédalons a repris ce mécanisme ; il lui manque la persistance des points *voulus* par
l'auteur, qui permettrait de distinguer « j'ai cliqué ici » de « le routeur est passé là ».

### 3.3 Opérations structurelles et raccourcis

Komoot web, dès deux points de passage (doc du 15/10/2026) : **inverser** l'ordre complet,
**basculer aller simple / boucle**, **recadrer** (crop), supprimer plusieurs points, masquer
temporairement le tracé, annuler/rétablir. Raccourcis documentés : `Ctrl+Z` / `Ctrl+Maj+Z`, `C`
centrer, `H` panneau, `P` profil, `M` maintenu pour cacher le tracé, `W` heatmap, `Alt+clic` pour
ajouter un point de passage, `Échap`. Les raccourcis sont explicitement absents de l'app mobile.

Strava web : annuler, rétablir, corbeille, **inverser** (icône dédiée), recherche d'un lieu de
départ, « Route to here » depuis une photo communautaire. Ride with GPS : annuler, rétablir,
effacer, inverser, **aller-retour** (génère le retour avec ses instructions), **changer le départ /
l'arrivée** en se raccordant au tracé existant. Garmin Connect web : boucler vers le départ,
inverser, aller-retour, points de parcours, tracé libre.

**Pédalons** : annuler/rétablir (`Ctrl+Z`), masquer le tracé (`h`), tout effacer. Pas d'inversion,
d'aller-retour, de boucle, de recadrage, pas de multi-sélection. Le `Ctrl` de ligne droite n'est
documenté nulle part dans l'interface.

### 3.4 Tracé libre

Komoot : « Follow ways » décoché **par point ou par segment**, ligne droite pointillée, avertissement
« cannot guarantee that your route is passable » ; un segment existant peut être converti.
gpx.studio : bascule routage / ligne droite (`F5`), routage actif par défaut, option opt-in « allow
private roads » avec avertissement sur la permission locale. Strava mobile : « Manual Mode », tap
pour une ligne droite ou dessin au doigt, retour au routage en désactivant la bascule.

Le patron commun : **un état visible et persistant** (bascule, segment pointillé), pas un modificateur
clavier maintenu. **Pédalons** n'a que `Ctrl` maintenu, invisible, sans équivalent tactile, et le
segment libre n'est pas distingué visuellement une fois tracé.

### 3.5 Tactile

Ride with GPS mobile (page officielle 2026) : tap pour ajouter un point routé, recherche de lieux,
drag des points de contrôle, inverser, « Change Start / Change End », « Out and Back »,
annuler/rétablir. gpx.studio : tap sur le segment pour insérer. Komoot : refonte du planificateur
Android le 03/09/2026 (« édition plus fluide, gestion des waypoints simplifiée »), Trail View, Street
View et préférences d'itinéraire portés sur mobile le 13/07/2026. Strava : refonte du Route Builder
mobile avec données communautaires, ajustement des waypoints, changement de sport.

Le tactile est le chantier 2026 de Komoot et Strava. **Pédalons** n'édite pas sur mobile.

---

## 4. Routage et re-routage

### 4.1 Les moteurs

| Service | Moteur | Note |
|---|---|---|
| Komoot, Strava, RWGPS, Garmin, Openrunner | Propriétaires sur données OSM (+ données communautaires chez Strava et Garmin) | Komoot et Strava précisent que les corrections se font dans OSM |
| gpx.studio | BRouter (instance publique) | Profils par activité, routes privées opt-in |
| BRouter-web / bikerouter.de | BRouter | Profils éditables, le plus fin pour le vélo |
| Pédalons | **Valhalla auto-hébergé**, France | 6 profils, seule la forme est lue |

### 4.2 Ce que Valhalla sait faire et que Pédalons ne lui demande pas

Le costing `bicycle` de Valhalla pondère chaque arête par `1 + stress_factor + slope_factor`
(« level of traffic stress », billet Mapzen 2017, confirmé dans `bicyclecost.cc`) :

| Option | Défaut | Effet | Équivalent concurrent |
|---|---|---|---|
| `bicycle_type` | `hybrid` | road / hybrid / cross / mountain, vitesses de 25 à 16 km/h | Sport Komoot, profil RWGPS |
| `use_roads` | 0,25 | 0 = pistes cyclables seulement, 1 = routes acceptées | « Éviter le trafic » |
| `use_hills` | 0,25 | 0 = fuir les côtes | « Minimiser le dénivelé » (Strava) |
| `avoid_bad_surfaces` | 0,25 | 1 = mauvais revêtements interdits | « Asphalte / terre » (Strava) |
| `use_ferry`, `use_living_streets`, `shortest` | | | |
| `exclude_locations`, `exclude_polygons` | | Routes ou zones à éviter | Komoot « Avoid specific roads, paths, and areas » (26/08/2026) |
| `locations[].type` = `through` | | Point de passage sans demi-tour ni leg | Comportement attendu d'un waypoint intermédiaire |
| `alternates` | | Itinéraires alternatifs (pas en multipoint) | |
| `elevation_interval` | | Altitude le long du tracé (30 m recommandé) | Inutile : Pédalons a l'IGN |
| `directions_type`, `language`, `maneuvers` | | **Instructions de virage** localisées, avec `rough` (revêtement dégradé) | Cue sheets RWGPS, course points Garmin |

Pédalons fixe `bicycle_type` par profil et, pour `FASTBIKE`, `use_roads: 1` et
`avoid_bad_surfaces: 1`. Il n'expose ni `use_hills`, ni les zones à éviter, ni les alternatives,
et ne lit pas les `maneuvers`.

### 4.3 Le revêtement par point

La coloration par surface ou type de voie **suppose que le moteur écrive les tags OSM dans les
points au moment du routage** : dans gpx.studio, la pente vient de l'altitude, mais surface et
catégorie viennent des tags `surface` / `highway` stockés en `gpxtpx:TrackPointExtension`, et ne
sont disponibles que pour les fichiers créés par gpx.studio. Ride with GPS classe en trois états
(revêtu, non revêtu, inconnu), en trait plein / pointillé / contour blanc, avec pourcentages et
correction manuelle par l'utilisateur, remontable à OSM. Komoot donne les répartitions par type de
voie et surface pour tout le parcours (données OSM). Openrunner classe par type de voie (route,
piste cyclable, piste forestière, agricole et DFCI, chemin, sentier) le long du profil.

Avec Valhalla, deux voies :

- **`trace_attributes`** sur le tracé (ou la réponse `route` enrichie) renvoie, par arête, des
  attributs filtrables : surface, classe de route, usage, pente pondérée, pente maximale, voie
  cyclable, réseau cyclable, `sac_scale`, vitesse, `way_id`, noms, longueur, et pour chaque point
  l'index de l'arête. *Les noms exacts des clés n'ont pas pu être relus ce jour (documentation
  injoignable depuis le poste) : à vérifier dans la référence de l'endpoint avant de coder.*
- Le routage **segment par segment** de Pédalons permet d'appeler `trace_attributes` sur le
  segment fraîchement routé, et de ranger la surface par point dans le JSONB `track_points`
  existant, à côté de `ele` et `dist`. Un GPX importé passe par la même route, en mode
  `map_snap`, pour obtenir le même enrichissement.

C'est la pièce manquante qui débloque à la fois l'affichage de la surface (carte et profil), le
pourcentage revêtu / non revêtu, et une **proposition automatique de `surfaceType`** à la place de
la saisie manuelle et du `ROAD` forcé des aperçus.

### 4.4 Routes interdites et impasses

Komoot explique un drag refusé par le sport, le sens unique ou une propriété privée (causes
documentées, pas un message d'interface). gpx.studio avertit explicitement pour les routes privées.
Komoot propose depuis le 31/08/2026 un détour en navigation face à une barrière ou une route
inondée. Rien d'équivalent chez Pédalons, qui renvoie une erreur `UNKNOWN` quand Valhalla échoue.

---

## 5. Ce que les éditeurs montrent

### 5.1 Profil altimétrique

Le standard est fixé par BRouter-web et gpx.studio (vote 3-0 et 2-1) :

- **Synchronisation bidirectionnelle** : survol du profil → position sur la carte ; sélection d'un
  intervalle (`Maj`+glisser ou loupe) → segment surligné des deux côtés.
- **Coloration du profil par variable** : BRouter-web en cycle six (pente, type de voie, surface,
  `smoothness`, vitesse max, coût de routage) par un bouton ou la touche `c` ; gpx.studio propose
  pente, surface, catégorie de voie, vitesse, FC, cadence, température, puissance.
- Strava affiche en direct distance, profil et surface pendant la planification (presse allemande,
  2026).

**Pédalons** a tout cela en *consultation* (`ElevationChart.tsx` : survol synchronisé, montées
colorées par pente, zoom en plein écran, `WEB-80`) et **rien pendant l'édition**. L'écart est
d'autant plus étrange que le composant existe.

### 5.2 Cartes et couches

- **Heatmap de popularité** : Komoot (`W`), Strava (heatmap et segments dans le Route Builder,
  routage « le plus populaire »), Garmin (« popularity routing »), RWGPS (heatmap). C'est l'avantage
  structurel des plateformes qui enregistrent des activités ; Pédalons n'en a pas. Il a en revanche
  une **popularité interne** possible : parcours déjà roulés par l'équipe (`usages`), tuiles MVT de
  tous les parcours de l'équipe (`RoutesTileMap`). Le backlog le liste déjà (« heatmap »,
  `docs/BACKLOG.md:75`).
- **Vue terrain** : Komoot « Trail View » (photos géolocalisées des sentiers) et Street View,
  portés sur mobile en juillet 2026 ; Strava : photos communautaires sur la carte, « Route to
  here ».
- **Fonds** : Komoot ajoute les topographiques officielles (Swisstopo, OS, USGS, IGN Espagne) en
  Premium ; Mapy.com montre revêtu / non revêtu / sentiers sur le fond lui-même ; RWGPS change
  d'algorithme de routage selon le fond choisi (forum). Pédalons sert ses fonds et son relief ; un
  « style vélo » est au backlog (`:77`).
- **Points d'intérêt** : Komoot « Highlights » communautaires avec cotation S0-S5 des singletracks,
  nouvelle catégorie station-service en janvier 2026 ; Openrunner : POI sur l'aller ou le retour,
  placés par distance depuis le départ (forum VisuGPX, juillet 2026). Pédalons a `gpx_waypoints` en
  base et des cols nommés, aucun POI d'auteur.

---

## 6. GPX, appareils, navigation

### 6.1 Import et édition d'un GPX

gpx.studio reste la référence : import sans altération, édition par ancres, découpage, fusion,
inversion, nettoyage, et un GPX de sortie enrichi (`gpxtpx`). Pédalons importe, nettoie
(`GpxSanitizer`), fusionne avec ordre optimal (`API-112`), mais **ne découpe pas** et n'enrichit pas
le fichier.

### 6.2 Export et points de parcours

- Importer un parcours **via l'app Garmin Connect** supprime les points de parcours personnalisés
  (TCX et FIT) et peut réécrire l'altitude avec des données moins fiables ; la copie USB dans
  `Garmin/NewFiles` ou une intégration API les préserve (VeloViewer, forums Garmin 2024-2026 ;
  vote 2-1, pas de doc officielle Garmin). Komoot annonce le 30/09/2026 que ses waypoints
  personnalisés s'affichent désormais sur Karoo 2 et 3, en aperçu, en navigation et en
  notification : c'est devenu un argument marketing.
- RWGPS : « custom cues » et POI typés (le guide Randonneurs Ontario recommande d'encadrer un
  contrôle par deux points de contrôle pour que la cue survive aux éditions), aller-retour avec
  instructions. Garmin Connect web : « course points ».
- **Réfuté** (0-3) : « FIT est le seul format Wahoo pour les waymarkers », « un GPX track ne peut
  pas porter de cues ». Ne pas reprendre ces affirmations.

**Pédalons** envoie déjà vers Garmin Connect (JSON course), Wahoo (FIT) et Hammerhead (GPX) par
API, automatiquement 7 jours avant la sortie : c'est précisément le canal qui **préserve** les
points. Mais il n'a aucun point à envoyer. Un auteur de parcours de club voudrait y mettre : départ
réel, regroupements, ravitaillement, danger, séparation des groupes. Le FIT (`FitExporter`) et le
convertisseur Garmin (`GarminCourseConverter`) sont les deux endroits à étendre.

### 6.3 Navigation

Tous les concurrents génèrent des instructions de virage et une navigation dans l'app ; Komoot
reroute à l'obstacle. Pédalons laisse les appareils recalculer les manœuvres à partir de la trace.
Pour un club dont les membres roulent sur compteur, c'est acceptable ; les `maneuvers` de Valhalla
seraient le point d'entrée si une feuille de route imprimable ou une navigation mobile devenait
un objectif.

---

## 7. Mobile et club

- **Mobile** : Komoot et Strava ont tous deux refondu leur planificateur mobile en 2025-2026 ; RWGPS
  en a un depuis 2019 (sans parité complète avec le web, l'affirmation contraire a été réfutée).
  Le noyau tactile commun : tap pour ajouter, tap sur le segment pour insérer, drag des points,
  inverser, aller-retour, annuler. Les raccourcis clavier n'y existent pas et personne ne le regrette.
- **Club** : RWGPS Clubs (bibliothèque partagée, calendrier, exports), Komoot Collections,
  Strava Clubs. Les sources vérifiables manquent sur la duplication et la synchronisation
  compteur d'un parcours *de club* ; le rapport RWGPS de septembre 2026
  ([lecture](2026-10-17-rwgps-state-of-the-cycling-club-2026.md)) dit surtout que la taille de la
  bibliothèque ne prédit pas l'engagement et qu'un cinquième seulement des parcours est roulé. La
  valeur pour un club est donc moins « encore un éditeur » que **« le parcours de dimanche, à jour,
  sur le compteur de chacun, avec les points de regroupement »**.
- **Performances** : les éditeurs modernes sont tous en tuiles vectorielles (MapLibre chez
  gpx.studio, Mapbox GL ou équivalent ailleurs) ; Pédalons aussi, web et mobile. Pas d'écart.

---

## 8. Confrontation et propositions

Tableau de synthèse, puis propositions classées par rapport effet / coût. Tailles : S (quelques
heures à un jour), M (quelques jours), L (une à deux semaines).

| Attendu | Komoot | Strava | RWGPS | gpx.studio | Pédalons |
|---|---|---|---|---|---|
| Drag de la ligne, insertion, re-routage partiel | ✓ | ✓ | ✓ | ✓ | ✓ |
| Undo / redo | ✓ | ✓ | ✓ | ✓ | ✓ |
| Inverser | ✓ | ✓ | ✓ | ✓ | ✗ |
| Aller-retour, boucle | ✓ | boucle | ✓ | ✗ | ✗ |
| Recherche d'adresse, départ d'ici | ✓ | ✓ | ✓ | ✓ | ✗ |
| Tracé libre visible par segment | ✓ | ✓ (mobile) | ✓ | ✓ | `Ctrl` invisible |
| Profil altimétrique pendant l'édition | ✓ | ✓ | ✓ | ✓ colorable | ✗ |
| Surface affichée et déduite | ✓ | ✓ | ✓ corrigeable | ✓ | ✗ manuelle |
| Éviter côtes / trafic | sport | ✓ | profils | profils BRouter | profils, pas de curseur |
| Zones à éviter | ✓ (2026) | ✗ | ✗ | ✗ | ✗ (Valhalla le permet) |
| Points de parcours d'auteur → compteur | ✓ Karoo (2026) | ✗ | ✓ cues | waypoints GPX | ✗ |
| Popularité / heatmap | ✓ | ✓ | ✓ | ✗ | ✗ |
| Édition mobile | ✓ refonte 2026 | ✓ refonte | ✓ | web responsive | ✗ |
| GPX importé fidèle et éditable | ✗ recalculé | ✗ | ✓ | ✓ | ✓ |
| Altitude de qualité (LiDAR 1 m) | ✗ | ✗ | ✗ | ✗ | **✓** |
| Routage auto-hébergé sans quota | ✗ | ✗ | ✗ | public BRouter | **✓** |
| Envoi automatique vers 3 écosystèmes | Karoo, Garmin, Wahoo | Garmin, Wahoo | ✓ | ✗ | **✓** |

### 8.1 Corriger d'abord (S, indépendant de toute refonte)

1. **`Ctrl+Z` ne doit pas annuler le tracé depuis un champ texte** : ignorer les événements dont la
   cible est un `input`, `textarea` ou `contenteditable` (`RoutePlanner.tsx:224-235`), comme le fait
   déjà `useHideTrackKey`.
2. **Verrouiller l'éditeur pendant un calcul** ou annuler la requête précédente
   (`AbortController`), et traduire l'erreur (`useRoutePlanner.ts:113-133`).
3. **Timeout et erreur Valhalla** : `quarkus.rest-client.valhalla.read-timeout`, et renvoyer le 503
   annoncé par l'OpenAPI au lieu de `UNKNOWN`.
4. **Vérifier le drapeau sur `/api/router`** (équipe ou domaine), prérequis au `403 PLAN_REQUIRED`
   du plan de monétisation.
5. **Mémoriser le profil** choisi (`localStorage`) et **documenter `Ctrl`** dans le texte d'aide.
6. **Tester `lib/planner.ts`** : module pur, aucune excuse.

### 8.2 Rattraper le standard (M)

7. **Profil altimétrique dans l'éditeur** : réutiliser `ElevationChart` avec le survol synchronisé ;
   alimenter l'altitude depuis `dist`/`ascend` et les coordonnées 3D que `/api/router` renvoie
   déjà (aujourd'hui ignorées), ce qui aligne du même coup le D+ affiché pendant l'édition sur
   celui du pipeline (bande morte, LiDAR).
8. **Inverser, aller-retour, boucler** : trois opérations sur le tableau de points, l'aller-retour
   étant une concaténation du tracé inversé, la boucle un routage `dernier → premier`. Un
   `reverse` existe déjà côté serveur pour la fusion.
9. **Recherche d'adresse et « partir d'ici »** : `PlaceAutocomplete` existe dans le dépôt ; ajouter la
   géolocalisation (`GeolocateControl`, déjà sur la carte vierge) et la position de l'équipe comme
   centrage initial (déjà au backlog, coché).
10. **Tracé libre comme état visible** : bascule dans la barre (en plus de `Ctrl`), segment libre
    rendu en pointillés, avertissement à l'enregistrement si un segment libre dépasse quelques
    centaines de mètres. Donne enfin l'équivalent tactile.
11. **Conserver les points d'auteur** : enregistrer les `manual` avec le parcours (une colonne
    JSONB `control_points` sur `gpx_tracks`, ou une extension dans `filtered.gpx`) et les
    restaurer à la réouverture, en complément des ancres générées.
12. **Clavier et accessibilité** : marqueurs focalisables avec nom, suppression par `Suppr`,
    déplacement par flèches ; `Alt+clic` pour ajouter, comme Komoot.

### 8.3 Se différencier (M à L)

13. **Surface par point via Valhalla** (`trace_attributes` sur chaque segment routé, puis sur les
    GPX importés) : stockée dans `track_points`, affichée sur le tracé (plein / pointillé comme
    RWGPS) et dans le profil (comme gpx.studio), avec le pourcentage revêtu et une **proposition de
    `surfaceType`** à la place du `ROAD` forcé. C'est le chantier au meilleur rapport valeur / coût
    parmi les différenciateurs, parce que le moteur est déjà là.
14. **Curseurs « éviter les côtes » et « éviter le trafic »** : deux `use_hills` / `use_roads`
    exposés sous les profils, à la Strava. Coût quasi nul côté backend, le contrat change
    (`pedalons.api.version`).
15. **Points de parcours d'auteur** (type : regroupement, ravitaillement, danger, séparation des
    groupes, départ réel), posés sur le tracé, exportés en **FIT course points** et dans la course
    Garmin, visibles en consultation web et mobile, envoyés automatiquement comme le parcours. C'est
    ce que Komoot vient d'annoncer pour Karoo et que RWGPS vend aux clubs depuis des années ;
    Pédalons a déjà le canal d'envoi.
16. **Zones et routes à éviter par équipe** (`exclude_polygons`, `exclude_locations`) : un club
    connaît ses routes dangereuses ; Komoot l'a livré en août 2026 par utilisateur. Par équipe,
    c'est inédit.
17. **Popularité interne** : surligner dans l'éditeur les tronçons déjà empruntés par les parcours
    de l'équipe (les tuiles MVT existent), à défaut d'une heatmap d'activités.
18. **Édition sur mobile** : l'app a MapLibre, le profil interactif et le curseur partagé. Le noyau
    tactile (tap pour ajouter, tap sur segment pour insérer, drag, inverser, aller-retour, undo)
    suffit ; Komoot et Strava viennent d'y consacrer leurs refontes 2026. Prérequis : que
    `lib/planner.ts` soit stabilisé et testé, pour le porter en Dart sans deux algorithmes
    divergents, ou mieux, déplacer l'orchestration des segments côté serveur (un endpoint
    « reroute ces ancres ») que les deux clients appellent.

### 8.4 Délibérément hors champ

- **Heatmap d'activités** : Pédalons n'enregistre pas d'activités ; la popularité interne (17) est
  le substitut honnête.
- **Navigation guidée dans l'app** : les membres roulent sur compteur ; les `maneuvers` de Valhalla
  restent disponibles si une feuille de route imprimable est demandée un jour.
- **Trail View / photos** : suppose une communauté de contributeurs que n'a pas un outil de club.
- **Import par URL depuis d'autres services** : déjà refusé (`API-113`, `API-114`).

Aucune de ces propositions n'est encore au ledger ; elles y entreront avec des IDs `WEB` / `API` /
`MOB` quand elles seront décidées.

---

## 9. Sources et fiabilité

**Primaires (documentation ou code)**

- Komoot, [Plan routes on the website](https://www.komoot.com/help/routeplanner) (édité le
  15/10/2026) et [Tips and tricks](https://support.komoot.com/hc/articles/10194270667034),
  [Follow ways](https://support.komoot.com/hc/articles/360024733651),
  [What's new](https://komoot.com/whats-new) (juin à octobre 2026).
- gpx.studio, [Routing](https://gpx.studio/help/toolbar/routing),
  [Files and stats](https://raw.githubusercontent.com/gpxstudio/gpx.studio/main/website/src/lib/docs/en/files-and-stats.mdx),
  code `routing-controls.ts` et `simplify.ts` sur [GitHub](https://github.com/gpxstudio/gpx.studio).
- bikerouter.de, [Elevation profile](https://docs.bikerouter.de/en/elevation-profile/).
- Ride with GPS, [Mobile route planner](https://ridewithgps.com/app/mobile_route_planner) (2026),
  [Out and back](https://support.ridewithgps.com/hc/en-us/articles/4415456909339) (2025).
- Strava, [Creating routes on the web](https://support.strava.com/hc/articles/216918387),
  [Creating routes on mobile](https://support.strava.com/hc/en-us/articles/18001474720397).
- Garmin, [How to build a course in Garmin Connect](https://www.garmin.com/en-GB/blog/how-to-build-a-course-in-garmin-connect/).
- Valhalla, [Route API reference](https://valhalla.github.io/valhalla/api/route/api-reference/),
  [Low-stress bike routing](https://www.mapzen.com/blog/low-stress-bike-routing) (Mapzen, 2017),
  [`bicyclecost.cc`](https://github.com/valhalla/valhalla/blob/master/src/sif/bicyclecost.cc).
- VeloViewer, [Route export](https://blog.veloviewer.com/worldtour/racehub/upcomingraces/routedetails/export/).

**Secondaires (presse, guides, forums)**

- Tour Magazin, [comparatif de trois planificateurs](https://www.tour-magazin.de/en/electronics/bike-computers-sat-navs-trackers/route-planning-a-comparison-of-three-digital-route-planners/) (2024).
- bikepacking.com, [RWGPS app route planner](https://bikepacking.com/news/ride-with-gps-app-route-planner/) (2019).
- gravelstoke.com et gearjunkie.com sur les [types de surface RWGPS](https://gravelstoke.com/gravel-cycling-gear-blog/ridewithgps-surface-types) (2021).
- Bike Café, [OpenRunner web fait peau neuve](https://bike-cafe.fr/2022/08/openrunner-web-fait-peau-neuve/) (2022) ; RunPack sur OpenRunner ; forum VisuGPX (juillet 2026).
- TechRadar sur Garmin Connect ; outdoor-magazin.com et androidauthority.com sur Strava 2026 ;
  Komoot newsroom (refonte septembre 2025) ; BikeRadar sur Komoot.
- Randonneurs Ontario, [Mapping in Ride With GPS](https://www.randonneursontario.ca/tech/Mapping_in_Ride_With_GPS.pdf) ; forums Garmin (course points, 2024-2026).

**Affirmations réfutées par la vérification (0-3), à ne pas reprendre** :

- « FIT est le seul format de parcours que Wahoo supporte pleinement avec waymarkers ; TCX reste
  recommandé ailleurs. »
- « Un fichier GPX *track* ne peut pas porter de cues vers un compteur, seul un GPX *route* le
  peut. »
- « RWGPS a livré en décembre 2019 un planificateur mobile à parité complète avec le web. »

**Affirmations à 2-1 (tenues avec nuance)** : les six modes de coloration de BRouter-web (doc
d'une instance hébergée, non datée), la perte des course points via l'app Garmin Connect (forums
et VeloViewer, pas de source Garmin).

---

## 10. Questions ouvertes

1. **Attributs d'arête Valhalla** : noms exacts des clés `edge.*` de `trace_attributes` dans la
   version déployée (`valhalla-scripted:latest`), coût par point en JSONB, et si la réponse `route`
   peut les porter sans second appel. À vérifier dans la doc de l'endpoint avant de chiffrer (13).
2. **Insertion « au meilleur endroit »** à la Komoot : projection sur le segment le plus proche, ou
   minimisation de la longueur totale ? Nécessaire si Pédalons adopte une liste explicite de points
   de passage.
3. **Points d'auteur et course points** : correspondance entre les types utiles à un club
   (regroupement, ravito, danger) et les `course_point` FIT reconnus par Garmin, Wahoo et Karoo ;
   comportement de Hammerhead sur les `<wpt>` GPX.
4. **Où placer l'algorithme** avant le mobile : garder `lib/planner.ts` et le porter en Dart, ou
   remonter l'orchestration des segments au serveur.
5. **État réel de Strava web, Openrunner et Garmin Connect** sur le drag-to-reroute et l'édition
   tactile : aucune source primaire lue ; un essai en main d'une heure chacun lèverait le doute.
6. **Quel domaine a `enableGpxPlanner` en production** : à noter dans `docs/OPERATIONS.md`.
