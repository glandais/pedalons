# Points de parcours d'auteur — étude

*Recherche du 20 octobre 2026 sur `feat/routing-web-mobile` (commit `36835aabc`), pour la tâche C3
du plan [`../plans/2026-10-17-editeur-parcours-web.md`](../plans/2026-10-17-editeur-parcours-web.md)
(« à concevoir avant de commencer »). Elle répond aux questions ouvertes n° 2 et 3 du §10 de
[l'état de l'art](2026-10-17-editeur-parcours-etat-de-l-art.md#10-questions-ouvertes) et détaille
sa proposition n° 15. Les chemins sans préfixe sont relatifs à la racine du dépôt ; ceux de
gpx.studio (lu au commit `6a0d4343`) et de vcyclist sont préfixés par le nom du projet.*

**Fiabilité.** **[V]** : vérifié, c'est-à-dire lu dans une source primaire (spécification, XSD,
SDK, documentation ou centre d'aide de l'éditeur, code) ou constaté sur des tuiles décodées.
**[NV]** : non vérifié ou supposé (forum, presse, outil tiers, déduction). Rien n'a été essayé
sur un appareil : les comportements des compteurs viennent de leur documentation ou de tests
publiés par d'autres.

## Sommaire

1. [En une page](#1-en-une-page)
2. [Formats](#2-formats)
3. [Appareils](#3-appareils)
4. [Les plateformes : Komoot, Ride with GPS, Strava, Garmin Connect, Wahoo](#4-les-plateformes--komoot-ride-with-gps-strava-garmin-connect-wahoo)
5. [gpx.studio](#5-gpxstudio)
6. [vcyclist](#6-vcyclist)
7. [Rendu MapLibre, web et mobile](#7-rendu-maplibre-web-et-mobile)
8. [Points d'intérêt OSM](#8-points-dintérêt-osm)
9. [Les POI des tuiles VersaTiles](#9-les-poi-des-tuiles-versatiles)
10. [L'existant dans Pédalons](#10-lexistant-dans-pédalons)
11. [Réponses aux questions ouvertes](#11-réponses-aux-questions-ouvertes)
12. [Recommandation](#12-recommandation)
13. [Questions au propriétaire](#13-questions-au-propriétaire)
14. [Sources](#14-sources)

---

## 1. En une page

**Un seul format porte un type de point que tous les compteurs comprennent : le `course_point`
FIT**, posé sur le tracé avec sa distance depuis le départ. Son énumération compte 53 valeurs,
dont `meeting_spot`, `aid_station`, `water`, `danger`, `toilet`, `summit`, `checkpoint` : de quoi
couvrir tous les besoins d'un club sans rien inventer. Le TCX en est le sous-ensemble historique
(16 valeurs, nom limité à 10 caractères) ; le GPX n'a pas de type, seulement `sym` et `type` en
texte libre, que chaque appareil interprète à sa façon.

**Pédalons a le canal, pas le contenu.** L'envoi automatique vers Garmin, Wahoo et Hammerhead,
sept jours avant une sortie, est précisément le chemin qui préserve les points (la copie par
l'import d'un fichier dans Garmin Connect retire les noms d'un FIT et les points d'un TCX). Les
cinq plateformes étudiées (§4) le confirment : Komoot, RWGPS, Strava poussent leurs points par
leurs propres intégrations, Wahoo n'a pas d'éditeur, et la Courses API Garmin accepte des course
points typés dans la liste `geoPoints` **[NV, spécification non officielle]**. Mais aujourd'hui :

- un waypoint n'est qu'**une position et un nom**, en lecture seule, venu d'un `<wpt>` importé ;
  `GpxSanitizer` jette `sym`, `type` et `desc` ;
- **aucun export n'en porte de type** : le FIT (téléchargement, Wahoo, app Garmin) n'a aucun
  `course_point`, le JSON Garmin Courses aucun `coursePoints` ; seul le GPX envoyé à Hammerhead
  garde des `<wpt>`, que Hammerhead ignore officiellement ;
- **toute retouche du tracé efface les waypoints** (`RouteService.java:544`), et l'éditeur
  prévient qu'ils ne survivent qu'à un import non modifié.

**Les trois questions ouvertes**, en bref (détail au [§11](#11-réponses-aux-questions-ouvertes)) :

1. *Types utiles et correspondances.* Douze types suffisent : regroupement, ravitaillement, eau,
   café, toilettes, danger, col ou sommet, point de vue, atelier vélo, départ réel, séparation
   des groupes, information. Chacun a un `course_point` FIT exact ou très proche ; la table est au
   §11.1.
2. *Hammerhead et les `<wpt>`.* La documentation Hammerhead dit qu'ils sont **ignorés** à l'import
   GPX ; seuls les POI des parcours RWGPS, Komoot (depuis septembre 2026) et ceux posés dans le
   Dashboard arrivent sur le Karoo **[V]**. Un contournement communautaire (`<type>` et `<sym>`
   parmi neuf valeurs) est **[NV]**. Le sort des `course_point` d'un FIT poussé par l'API
   Hammerhead n'est documenté nulle part : c'est le premier essai à faire.
3. *Insertion « au meilleur endroit ».* La question ne se pose pas pour un point d'auteur : il ne
   modifie pas le tracé, il s'y **accroche à une distance**. Posé par un geste sur la ligne, cette
   distance est exacte. La difficulté réelle est de **ré-accrocher** les points après une retouche
   du tracé, sur une boucle ou un aller-retour qui repasse au même endroit : projection limitée
   aux candidats à moins de 50 m, départagés par la distance la plus proche de l'ancienne.

**Recommandation** ([§12](#12-recommandation)) : étendre `gpx_waypoints` plutôt que créer une
table (type, description, distance, origine), garder les points à travers les retouches du tracé,
les exporter en `course_point` FIT (évolution de vcyclist) et en `<wpt>` typés, et les afficher
avec une icône par type sur la carte **et sur le profil**. Huit sous-tâches, de C3a à C3h : un essai sur
appareils à faire en premier et l'évolution FIT de vcyclist (S), le backend, la consultation web et
mobile (M), l'éditeur (L), puis deux options, les POI de la carte (S) et une extension Karoo (L),
celle-ci seulement si Hammerhead refuse les points.

---

## 2. Formats

### 2.1 GPX 1.1

`<wpt>`, `<rtept>` et `<trkpt>` partagent le même type, `wptType` ; seul le contexte change
**[V]** ([XSD](https://www.topografix.com/GPX/1/1/gpx.xsd)) :

- `gpx/wpt` : « a waypoint, point of interest, or named feature on a map » — indépendant du
  tracé, sans ordre ni distance ;
- `rte/rtept` : « an ordered list of waypoints representing a series of turn points leading to a
  destination » ;
- `trk/trkseg/trkpt` : un point de trace.

Les éléments de `wptType`, tous facultatifs et **dans cet ordre** : `ele`, `time`, `magvar`,
`geoidheight`, `name`, `cmt`, `desc`, `src`, `link` (0..n), `sym`, `type`, `fix`, `sat`, `hdop`,
`vdop`, `pdop`, `ageofdgpsdata`, `dgpsid`, `extensions` **[V]**. Les quatre qui comptent ici :

| Élément | Ce qu'en dit le XSD | Usage proposé |
|---|---|---|
| `name` | « GPX does not place restrictions on the length of this field » | Nom du point |
| `cmt` | « GPS waypoint comment. Sent to GPS as comment. » | Repris par RWGPS pour son type (§4) |
| `desc` | « intended for the user, not the GPS » | Description de l'auteur |
| `sym` | « use the exact spelling of the symbol as displayed on the GPS » | Nom de symbole Garmin |
| `type` | « Type (classification) of the waypoint » | Texte libre ; voir Karoo (§3.3) |

**Extensions Garmin** ([GpxExtensionsv3.xsd](https://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd))
**[V]** : `gpxx:WaypointExtension` porte `Proximity` (mètres, une distance d'alerte), `DisplayMode`
(`SymbolOnly`, `SymbolAndName`, `SymbolAndDescription`), `Categories`, `Address`, `PhoneNumber`.
`TrackPointExtension` v1/v2 ne concerne que les capteurs (`hr`, `cad`, `atemp`…) : inutile ici.
Aucune source ne dit qu'un compteur Edge lise `Proximity` sur un parcours **[NV]**.

**Symboles `sym` Garmin.** Garmin ne publie aucune liste lisible par machine. La référence de
fait est la table de GPSBabel, « based on information provided by … Garmin MapSource »
([`garmin_icon_tables.h`](https://github.com/GPSBabel/gpsbabel/blob/master/garmin_icon_tables.h))
**[V dans GPSBabel, source secondaire]**. Les noms utiles au vélo :

| Thème | Noms exacts |
|---|---|
| Génériques | `Waypoint` (défaut), `Flag, Blue`, `Flag, Red`, `Flag, Green`, `Pin, Blue`, `Circle, Red`, `Triangle, Red` |
| Ravitaillement | `Drinking Water`, `Water Source`, `Restaurant`, `Fast Food`, `Food Source`, `Convenience Store`, `Bar` |
| Services | `Restroom`, `Shower`, `Medical Facility`, `Pharmacy`, `Car Repair`, `Lodging`, `Campground`, `Picnic Area`, `Parking Area` |
| Terrain et danger | `Summit`, `Scenic Area`, `Danger Area`, `Skull and Crossbones`, `Bridge`, `Tunnel`, `Crossing` |
| Vélo et info | `Bike Trail`, `Trail Head`, `Information`, `Ground Transportation` |

Il n'existe ni « Coffee », ni « Bike Shop », ni « First Aid » comme symbole de waypoint **[V par
recherche dans la table]**. gpx.studio emploie la même convention (§5).

### 2.2 FIT : le message `course_point`

Profil 21.218.0, le plus récent ([`profile.js`](https://raw.githubusercontent.com/garmin/fit-javascript-sdk/main/src/profile.js))
**[V]**. Message n° 32 :

| N° | Champ | Type | Échelle, unité |
|---|---|---|---|
| 254 | `message_index` | uint16 | — |
| 1 | `timestamp` | date_time (uint32) | s |
| 2 | `position_lat` | sint32 | semicircles |
| 3 | `position_long` | sint32 | semicircles |
| 4 | `distance` | uint32 | ×100, m (stocké en cm) |
| 5 | `type` | enum `course_point` | — |
| 6 | `name` | string | UTF-8 terminé par zéro |
| 8 | `favorite` | bool | — |

**L'énumération `course_point`, complète** **[V]** :

| Valeurs | Noms |
|---|---|
| 0-15 (identiques au TCX) | 0 `generic` · 1 `summit` · 2 `valley` · 3 `water` · 4 `food` · 5 `danger` · 6 `left` · 7 `right` · 8 `straight` · 9 `first_aid` · 10 `fourth_category` · 11 `third_category` · 12 `second_category` · 13 `first_category` · 14 `hors_category` · 15 `sprint` |
| 16-25 | 16 `left_fork` · 17 `right_fork` · 18 `middle_fork` · 19 `slight_left` · 20 `sharp_left` · 21 `slight_right` · 22 `sharp_right` · 23 `u_turn` · 24 `segment_start` · 25 `segment_end` |
| 26 | *n'existe pas* |
| 27-53 | 27 `campsite` · 28 `aid_station` · 29 `rest_area` · 30 `general_distance` (« Used with UpAhead ») · 31 `service` · 32 `energy_gel` · 33 `sports_drink` · 34 `mile_marker` · 35 `checkpoint` · 36 `shelter` · 37 `meeting_spot` · 38 `overlook` · 39 `toilet` · 40 `shower` · 41 `gear` · 42 `sharp_curve` · 43 `steep_incline` · 44 `tunnel` · 45 `bridge` · 46 `obstacle` · 47 `crossing` · 48 `store` · 49 `transition` · 50 `navaid` · 51 `transport` · 52 `alert` · 53 `info` |

Les valeurs 0 à 53 sont identiques dans les treize versions du SDK JS publiées sur GitHub depuis
le profil 21.94 (2022) **[V]**. Les valeurs 27-53 seraient apparues dans la version 21.78 (« two
dozen new Course Point Types ») **[NV]** : les notes de version sont derrière une connexion.
Garmin Connect accepterait en plus `obstacle_start` (54) et `obstacle_end` (55), absents du profil
**[NV, test tiers]**.

**Le fichier Course** ([doc Garmin](https://developer.garmin.com/fit/file-types/course/),
[cookbook](https://developer.garmin.com/fit/cookbook/encoding-course-files/)) **[V]** :

- `file_id.type` = 6 (et non 4, l'Activity) ;
- séquence imposée : `file_id`, `course`, `lap` (1..n), `event` timer start, `record` (1..n),
  `course_point` (0..n), `event` timer stop_all — « should be strictly adhered to » ;
- « The optional Course Point messages can be grouped together after the Record messages or
  interleaved with the Record message by timestamp » ;
- « A Course Point message can also be associated to a Record message through a matching
  timestamp » : dans l'exemple officiel, le point « Halfway » a **le même timestamp, la même
  position et la même distance** qu'un record ;
- `distance` est « the distance from the start of the course ».

**Ce que la documentation ne dit pas** : qu'un course point doive être sur le tracé, ni qu'ils
doivent être triés par distance. L'usage courant (RWGPS, coursepointer) est de les aligner sur un
record et de les trier **[NV]**. Le protocole ne limite pas `name` au-delà des 255 octets d'un
champ ; l'exemple du SDK C fixe 16 octets (`FIT_COURSE_POINT_MESG_NAME_COUNT 16`) **[V]**, ce qui
n'est qu'une configuration d'exemple. La troncature à l'affichage n'est documentée nulle part.

### 2.3 TCX

[`TrainingCenterDatabasev2.xsd`](https://www8.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd)
**[V]** : `CoursePoint_t` = `Name` (**1 à 10 caractères**), `Time`, `Position`, `AltitudeMeters`?,
`PointType`, `Notes`?. `CoursePointType_t` a seize valeurs, celles du FIT 0-15 : `Generic`,
`Summit`, `Valley`, `Water`, `Food`, `Danger`, `Left`, `Right`, `Straight`, `First Aid`,
`4th Category` … `Hors Category`, `Sprint`. Pas de distance : le point se rattache au tracé par
son heure et sa position.

**Pédalons n'exporte pas de TCX** (aucune occurrence dans `backend/src/main`) et n'a pas de
raison d'en ajouter : tous les compteurs visés lisent le FIT, et le TCX est plus pauvre.

---

## 3. Appareils

### 3.1 Garmin Edge et Garmin Connect

- **Sur l'appareil** **[V]**, manuel Edge 1050 : « Select Course Points to view all the points
  along the course » et « to include course points on the map ». Aucun réglage de distance
  d'alerte. Le manuel ne mentionne ni GPX, ni TCX : un parcours arrive par Garmin Connect ou se
  crée sur l'appareil.
- **Up Ahead** : le compteur affiche la distance restante au prochain point et une notification à
  son passage **[NV, presse 2023]**. Sur un Edge 1040 (logiciel 27.14), **tous les types
  apparaissent avec une icône générique**, `segment_start` est absent de Up Ahead, et une Fenix 7
  montre les icônes propres à chaque type **[NV, test publié par coursepointer]**.
- **ClimbPro** repose sur l'altitude du parcours (« at least 500 meters and an average grade of at
  least 3 percent ») et ne parle pas des course points `summit` **[V]**. Un point « col » d'auteur
  n'alimente donc pas ClimbPro ; il s'ajoute à la liste des points.
- **Limites** : « 200 course point max exceeded » sur un Edge 530, les points au-delà masqués
  **[NV, forum]** ; le nom d'un *parcours* tronqué vers 15 caractères **[NV]** ; rien de fiable
  sur le nom d'un course point.
- **Ce qui arrive par Garmin Connect** (import de fichiers, éditeur, Courses API) est traité avec
  les plateformes, au [§4.4](#44-garmin-connect).

**Garmin** — `<wpt>` GPX → course point via Connect s'il est à ~40 m du tracé **[NV]** ;
`course_point` FIT → course point natif, liste, carte et Up Ahead **[V liste et carte, NV Up
Ahead]** ; alerte → notification à l'approche, distance non réglable ; limites → 200 points
(Edge 530) **[NV]**, icône générique sur Edge 1040 **[NV]**.

### 3.2 Wahoo ELEMNT (BOLT 3, ROAM 3, ACE)

- **Import** : « You can import a FIT, GPX, or TCX route file into the Wahoo app » **[V]**.
- **Cloud API** (celle de `WahooClient`) : « route[file] … Base64 encoded FIT file », synchronisé
  vers l'app et le compteur **[V]**.
- **Custom Waypoints** (firmware ≥ 301724, 2025-2026) **[V]** : affichés « on the map, in the route
  cue sheet, and on a new Waypoints page », avec la distance et l'écart d'altitude, et « ROUTE
  TO ». Ils « will generate a notification pop-up as you approach them », au même intervalle que
  les virages. Environ cinquante icônes : `warning`, `first_aid`, `water`, `bar`, `bike_shop`,
  `coffee`, `food`, `groceries`, `info`, `shower`, `toilet`, `rest_area`, `summit`, `valley`,
  `checkpoint`, `climb_*_cat`, `distance_marker`, `meeting_spot`, `segment_start/end`, `sprint`,
  `viewpoint`, `generic`…
- **Réserve qui compte** **[V]** : les icônes typées ne valent que pour les parcours « cloud synced
  from third party route services (komoot, RideWithGPS, and Strava) ». Un parcours importé par
  l'app montre l'icône générique avec le nom et la description. Un FIT poussé par la Cloud API par
  un autre partenaire n'est pas cité : **icône typée ou générique, à essayer [NV]**.

**Wahoo** — `<wpt>` GPX → waypoint (carte, cue sheet, page Waypoints) à icône générique **[V]** ;
`course_point` FIT par la Cloud API → probablement affiché, icône non documentée **[NV]** ; alerte
→ pop-up à l'approche **[V]** ; limites → aucune publiée.

### 3.3 Hammerhead Karoo (2 et 3)

**Le comportement documenté.** « Dashboard and the Karoo do not show the POI points when imported
as a GPX file » ; seuls les POI des parcours RWGPS s'affichent
([article 360036632794](https://support.hammerhead.io/hc/en-us/articles/360036632794), mis à jour le
10/05/2024) **[V]**. Les POI peuvent aussi être posés dans le Dashboard, rattachés à un parcours
(« Save to Route ») ou rendus globaux **[V]**. En course, le réglage « POI Cues » les montre « in
the drawer when approaching them », et la cue sheet a un filtre POI **[V]**.

**Komoot (septembre 2026)** : « Custom waypoints you add in komoot now sync to Hammerhead Karoo 2
and 3 devices. They appear in the route preview, during navigation, and in waypoint
notifications with distance remaining » **[V, journal Komoot]**. Le canal est la synchronisation
de compte Komoot → Dashboard, réservée aux abonnés Premium **[V]** : une intégration propriétaire,
pas un format de fichier.

**Contournement communautaire** : le Dashboard importerait un `<wpt>` dont `<type>` **et** `<sym>`
valent l'une de neuf valeurs, sensibles à la casse : `Food`, `Water`, `Parking`, `Camping`,
`Lodging`, `Geocache`, `Summit`, `Generic`, `Danger`
([gpx-poi-karoo-fixer](https://github.com/mendalka/gpx-poi-karoo-fixer), juin 2026) **[NV]** ; un
autre testeur dit que `sym` peut différer **[NV]**.

**L'API de routes** (celle de `HammerheadClient`) accepte « .gpx .fit .tcx .kml .kmz » en
multipart, sans aucun champ POI ([`docs/hammerhead-openapi.yml`](../hammerhead-openapi.yml)) **[V]**.
Le traitement des `course_point` d'un FIT envoyé par ce canal n'est documenté nulle part.

**Le SDK karoo-ext 1.1.9** (celui de `karoo/`, `gradle/libs.versions.toml:4`) **[V, code]** :

- `Symbol.POI(id, lat, lng, type, name, distancesAlongRoute)` — « POIs are considered along the
  route by proximity they can appear more than once » ; 35 types : `aid_station`, `atm`, `bar`,
  `bike_parking`, `bike_share`, `bike_shop`, `camping`, `caution`, `coffee`, `control`,
  `convenience_store`, `ferry`, `first_aid`, `food`, `gas_station`, `generic`, `geocache`, `home`,
  `hospital`, `library`, `lodging`, `monument`, `park`, `parking`, `rest_stop`, `restroom`,
  `shopping`, `shower`, `summit`, `swimming`, `trailhead`, `transit_center`, `viewpoint`, `water`,
  `winery` — presque la liste des POI RWGPS (§4.2) ;
- événements : `OnNavigationState` → `NavigatingRoute(routePolyline, routeDistance, name, reversed,
  pois, climbs…)`, `OnGlobalPOIs` ;
- effets : `ShowSymbols` / `HideSymbols` sur la carte (depuis `KarooExtension.startMap`),
  `InRideAlert`, `PlayBeepPattern`, `LaunchPinDrop` (« navigate to this point or save this point
  as a POI »).

Une extension peut donc **lire** les POI du parcours suivi avec leur distance, **dessiner** ses
propres symboles et **déclencher** ses propres alertes ; elle ne peut pas écrire un POI dans le
parcours système. L'extension Pédalons n'en utilise rien aujourd'hui (`PedalonsExtension.kt` est
vide) : elle déclenche l'envoi du GPX par le serveur (`api/PedalonsApiClient.kt:139-145`).

**Karoo** — `<wpt>` GPX → ignoré selon la doc (2024) **[V]**, importé s'il porte l'un des neuf
types **[NV]** ; `course_point` FIT par l'API → **inconnu, à essayer** ; alerte → « POI Cues » à
l'approche, ou alerte d'extension ; limites → aucune publiée.

### 3.4 Les apps du dépôt

- **Connect IQ** (`garmin-app/`) : télécharge le FIT de `GET /device/routes/{team}/{route}/fit`
  (`source/ApiClient.mc:517-532`), que le firmware enregistre comme parcours. Aucun code de
  waypoint : **dès que le FIT servi portera des `course_point`, l'app les transmettra sans
  changement**, ce qui en fait le chemin le plus simple vers un Edge.
- **Karoo** (`karoo/`) : voir ci-dessus ; une extension qui montre les points d'auteur et alerte à
  l'approche est possible, mais c'est un développement à part (C3h).

---

## 4. Les plateformes : Komoot, Ride with GPS, Strava, Garmin Connect, Wahoo

Les centres d'aide ont été lus par l'API publique Zendesk de chaque éditeur ; les dates sont les
dates de mise à jour qu'elle renvoie.

### 4.1 Komoot

**Quatre objets, et aucun n'est exporté dans un fichier.**

- **Point de passage de routage** **[V]** ([planifier sur le web](https://support.komoot.com/hc/fr/articles/10194270667034),
  19/10/2026). Un clic sur la carte puis « Ajouter à l'itinéraire » : le planificateur
  « positionnera automatiquement le nouveau point de passage au meilleur endroit possible ».
  Depuis la liste, un point s'ajoute « juste avant le point d'arrivée » ; on réordonne par
  glisser ; tirer la ligne crée un point. Dans l'app (septembre 2026), un toucher sur la ligne
  propose « along the route or at the end ». Un Highlight ou un POI peut devenir un point de
  passage.
- **Point de passage personnalisé** **[V]** ([planification avancée](https://support.komoot.com/hc/fr/articles/10268757747738),
  mars 2026) : on sélectionne un point de passage, puis « Personnaliser » : « un nom, une
  description et une catégorie (par ex. point de rendez-vous, point d'eau, camp) » ; sans nom, il
  prend celui de la catégorie, avec « une icône dédiée » sur la carte et dans la chronologie des
  points. Il est « lié à un itinéraire spécifique » et « n'affecte pas le routage ». Création sur
  le web et Android ; consultation seulement sur iOS, Apple Watch et Garmin. La liste des
  catégories n'est pas publiée.
- **Highlight** **[V]** ([Highlights](https://support.komoot.com/hc/en-us/articles/10364710659994)) :
  contribution communautaire, « a Place or a Segment », avec nom, sport, conseil et photos,
  notée par ceux qui passent ; masquée si les avis sont mauvais.
- **POI OSM** **[V]** : couche de la carte (« hébergements, sites naturels, bornes de recharge pour
  VAE »), en lecture seule, ajoutable comme point de passage.

**Sorties** **[V]** :

- **Export GPX** : « uniquement la géométrie de l'itinéraire … Les points de passage ajoutés
  pendant la planification … ne sont pas inclus » ([export](https://support.komoot.com/hc/fr/articles/10115477099674)).
  Ni FIT, ni TCX. L'**import** accepte GPX, TCX, FIT, et depuis mai 2026 un GPX « with custom
  waypoints » dont « most waypoint categories map automatically to the right icon ».
- **Garmin** : Courses Sync envoie le tracé (instructions « calculées par Garmin ») ; Highlights et
  POI partent « via Course Points » depuis février 2026 ; l'app Connect IQ Komoot (Premium) a une
  vue « Up Ahead » des Highlights, POI et points personnalisés depuis mai 2026. Que Courses Sync
  transmette aussi les points personnalisés n'est pas dit.
- **Wahoo** : synchronisation et Live Sync, rien sur les points ; Wahoo précise que les points
  personnalisés Komoot « will not appear on you ELEMNT » (05/10/2026).
- **Karoo** : synchronisation de compte, 50 derniers parcours ; les points personnalisés y arrivent
  depuis le 30/09/2026 (aperçu, navigation, notification avec distance restante).

**À retenir.** Le point personnalisé de Komoot est exactement le point d'auteur de C3 : nom,
description, catégorie à icône, attaché à un parcours, sans effet sur le routage. Komoot le réserve
à ses intégrations et ne l'exporte dans aucun fichier.

### 4.2 Ride with GPS

**Trois niveaux d'objets** **[V]** ([Highlights, POI et Waypoints](https://support.ridewithgps.com/hc/en-us/articles/36570435135131),
17/04/2026) :

- **Highlights** : « built from community-sourced POI and photos across publicly shared routes »,
  icônes rondes ;
- **POI** (Premium) **[V]** ([POI](https://support.ridewithgps.com/hc/en-us/articles/4419004424219)) :
  pour ce qui est « nearby your route but not necessarily along the route line », icônes carrées ;
  type, nom, description, URL, photos ; « Placement is not required to be along route lines » ;
  il « will not factor into navigation » et n'entre pas dans la cue sheet. **39 types**
  ([référence API](https://ridewithgps.com/api/v1/doc/reference/points_of_interest)) : camping,
  lodging, parking, food, viewpoint, restroom, generic, aid_station, bar, bike_shop, bike_parking,
  convenience_store, first_aid, hospital, rest_stop, trailhead, geocache, water, control, winery,
  start, stop, finish, atm, caution, coffee, ferry, gas, library, monument, park, segment_start,
  segment_end, shopping, shower, summit, swimming, transit, bikeshare — presque les types
  `Symbol.POI` du Karoo ;
- **Waypoints** (mai 2025) **[V]** ([Waypoints](https://support.ridewithgps.com/hc/en-us/articles/36795897776411)) :
  « a combination of a Cue, a Point of Interest, and a Control Point », « directly on or near your
  route line », dans le profil altimétrique et la cue sheet. On les crée depuis un POI ou un
  Highlight (« Include in Route » branche le point depuis le point le plus proche du tracé ; « Route
  to Here » l'ajoute à la fin), depuis la recherche (type deviné), ou en posant un POI sur la ligne.
  On les glisse comme un point de contrôle, et « your route and cuesheet will automatically
  adjust ».

**Cue sheet** **[V]** ([custom cues](https://support.ridewithgps.com/hc/en-us/articles/4419011474843)) :
générée au routage ; les cues personnalisées (Premium) se posent sur la ligne ou sur le profil
(utile « for any route that crosses itself »), avec un type, des notes lues à voix haute et une
description. **Points de contrôle** **[V]** ([control points](https://support.ridewithgps.com/hc/en-us/articles/4415470200859)) :
« help lock your route into place while editing ». Une cue modifiée est perdue si son segment est
recalculé, d'où le conseil des randonneurs : « Protect edited cues by placing a control point on
either side » ([RUSA](https://rusa.org/node/549)) **[V]**.

**Sorties** **[V]** ([formats](https://support.ridewithgps.com/hc/en-us/articles/4419007646235),
18/05/2026 ; [OpenAPI](https://ridewithgps.com/api/v1/openapi.yaml)) :

| Format | Contenu |
|---|---|
| FIT Course, TCX Course | « contain the cuesheet », cues personnalisées comprises, en course points ; placés « 30 meters ahead of the turn » pour les abonnés (réglable de 5 à 100 m, « NOTIFY BEFORE TURN ») |
| GPX Track | « only the GPS points » ; option « Include POI as waypoints » |
| GPX Route | « only contains cuesheet entries » |

Vers les appareils : **Garmin** par Garmin Connect (« Send to Garmin ») ; **Wahoo** de 3e génération
par synchronisation (carte, cue sheet, page Waypoints avec icônes) **[V]** ; **Karoo** par
synchronisation de compte, POI et waypoints visibles **[V]**, mais pas par un GPX importé **[V,
Hammerhead]**. Un test tiers a relevé dans les exports RWGPS : `cmt` = type RWGPS, `type` = type
FIT, `sym` toujours `Dot`, avec caution → `danger`, restroom → `toilet`, viewpoint → `overlook`,
control → `checkpoint` **[NV, coursepointer]**. Le **compte Club** partage une bibliothèque de
parcours entre administrateurs ; les points restent portés par chaque parcours, sans POI de club
**[V]**.

**À retenir.** RWGPS distingue nettement le POI hors tracé (informatif, exporté en `<wpt>` à la
demande) du waypoint sur le tracé (cue, course point, profil), et pousse ses points par la
synchronisation de compte plutôt que par fichier. Sa règle « 30 m avant » et son réglage de 5 à
100 m sont la seule « distance d'alerte » qu'un auteur puisse régler, en décalant le point.

### 4.3 Strava

Les « custom waypoints » s'ajoutent par une recherche ou un clic sur le tracé, se complètent par
« Customize », et partent vers les appareils connectés **[V]**
([Strava](https://support.strava.com/en-us/articles/15401644-custom-waypoints-on-strava-routes),
15/09/2026). L'article ne dit rien des fichiers ; l'export GPX les contiendrait ou non selon les
sources **[NV]**. Sur Garmin, ils apparaissent dans Up Ahead **[NV, 2023]** ; sur Wahoo, avec leur
icône typée, Strava étant l'un des trois partenaires reconnus **[V]**.

### 4.4 Garmin Connect

**L'éditeur** (web et app). Aucune documentation officielle ne décrit l'ajout d'un course point :
le blog Garmin « How to Build a Course » (2023) et les manuels s'arrêtent à « clicking the map to
create points on your course » et « send to device » **[V, pour cette absence]**. Ce qu'en disent
les utilisateurs **[NV]** :

- on édite le parcours, « add course point », puis on **clique sur la ligne**, à un ou deux pixels
  près (« when I click somewhere on the course, nothing happens ») ; sur un aller-retour, le clic
  peut tomber sur la mauvaise branche ;
- un panneau demande le type, le nom (environ **15 caractères**, « just 15 letters ») et une
  description ; choisir le type écrase le nom ;
- le web proposait sept types en 2022 contre « a large range » dans l'app, et un point créé dans
  l'app avec un type absent du web en cassait l'édition ; aucun type de virage n'est proposé ;
- aucune limite propre à Connect ; celle des appareils est de 50 (anciennes montres) ou 200 points.

L'éditeur a la heatmap, le « popularity routing » et les montées catégorisées **[V]** ; aucune
source ne décrit une couche de POI qu'on transformerait en course point.

**L'import de fichiers** **[NV, rapports d'utilisateurs et tests de tiers]** :

| Fichier | Ce que Connect en fait |
|---|---|
| GPX | les `<wpt>` à moins de **39,67 m** du tracé deviennent des course points, les autres sont jetés (mesure PitStopper, juin 2026) ; leur distance est juste depuis juillet 2025 (avant : 0), sauf au-delà de **322 km** (200 milles), où ils retombent à 0 km |
| FIT | les `course_point` sont gardés, **leurs noms retirés** ; régression « Invalid course » sur Edge 1040 entre mai et juillet 2026 |
| TCX | les `CoursePoint` sont **supprimés** |

C'est ce qui condamne l'import manuel : un club qui télécharge le FIT de Pédalons et le charge
dans Connect perd les noms de ses points. L'app Connect IQ de Pédalons (§3.4) et l'envoi par API
évitent Connect.

**La Courses API.** La page publique ne montre qu'une image « Course Points » **[V]**. Une copie
non officielle de la spécification partenaire, « Courses API Version 1.0.1 » (révisions de 2020,
« Updated Course Point Types »), circule dans un dépôt public
([`courses.md`](https://github.com/clementpeleman/coach-v2/blob/main/api-docs/courses.md))
**[NV, mais texte de Garmin]** :

- endpoint `POST https://apis.garmin.com/training-api/courses/v1/course` — **celui que `GarminClient.java:37`
  appelle déjà** ;
- **pas de tableau `coursePoints`** : un course point est un élément de `geoPoints` qui porte un
  objet `information` :
  `{"latitude":46.474929,"longitude":11.745668,"elevation":0.0,"distance":13698.295,"information":{"name":"water","coursePointType":"WATER"}}` ;
- **43 types** : les noms FIT en majuscules (GENERIC, SUMMIT, VALLEY, WATER, FOOD, DANGER,
  FIRST_AID, catégories, SPRINT, SEGMENT_START/END, CAMPSITE, AID_STATION, REST_AREA,
  GENERAL_DISTANCE, SERVICE, ENERGY_GEL, SPORTS_DRINK, MILE_MARKER, CHECKPOINT, SHELTER,
  MEETING_SPOT, OVERLOOK, TOILET, SHOWER, GEAR, SHARP_CURVE, STEEP_INCLINE, TUNNEL, BRIDGE,
  OBSTACLE, CROSSING, STORE, TRANSITION, NAVAID, TRANSPORT, ALERT, INFO), plus `SHAPING`, **sans
  aucun virage** : « We don't provide API access for the partners to send us the navigations » —
  Garmin les calcule ;
- un geoPoint tous les 100 m recommandé, environ 10 000 au plus ; virages calculés seulement
  jusqu'à 200 milles ; « courses will be directly synced to the device ».

Un projet open source récent emploie exactement cette forme (`information: { name, coursePointType:
'INFO' }`, [quantified-self](https://github.com/jimmykane/quantified-self), `functions/src/garmin/routes.ts`,
octobre 2026) **[V que le code existe]** ; un autre envoie un tableau `coursePoints` de premier
niveau, ce qui contredit la spécification **[NV]**. Le programme développeurs n'accepte plus de
nouveaux partenaires depuis le printemps 2026 **[NV, presse]** ; Pédalons, déjà connecté, n'est pas
concerné.

**À retenir.** Les douze types de Pédalons existent tous dans la Courses API. Comme le course point
est un geoPoint, il suffit d'**insérer à sa distance**, dans la liste `geoPoints` que construit
`GarminCourseConverter`, un point portant `information`. C'est la distance stockée (§12.1) qui le
rend trivial.

### 4.5 Wahoo

- **Pas d'éditeur.** « The Wahoo app does not have a 'route builder' » : un itinéraire vient de
  l'historique, d'un fichier importé, d'un service tiers ou d'une adresse partagée depuis une app
  de cartes ; un itinéraire tiers ne se renomme ni ne se supprime dans l'app
  ([article 22710659712658](https://support.wahoofitness.com/hc/en-us/articles/22710659712658),
  08/09/2026) **[V]**. Aucune édition de points n'est documentée **[NV pour l'absence]**.
- **Import de fichiers** : FIT, GPX, TCX, convertis dans le cloud Wahoo **[V]** ; leurs points
  s'affichent avec l'**icône générique**, nom et description (« Routes downloaded and imported via
  the Wahoo app will not currently produce matching custom icons ») **[V]**. Un `CoursePoint` TCX
  de type Water a déclenché une alerte « Water! » avec une icône de robinet, en 2023 **[NV]** ; un
  `<wpt>` GPX trop loin du tracé devient un POI hors cue sheet **[NV, forum mai 2026]**.
- **Synchronisation des partenaires** : depuis le firmware 301724 (21 octobre 2025, ACE, BOLT 3,
  ROAM 3), les « Custom Waypoints … added in Strava, Komoot, or Ride with GPS » apparaissent sur la
  carte, dans la cue sheet et sur une page Waypoints, avec alerte et « Route To », et une
  cinquantaine d'icônes **tirées des catégories propres à chaque partenaire** (« Water Source »,
  « Stamp Station »…), dont plusieurs n'existent pas en FIT (bar, coffee, atm) **[V]**. Komoot n'y
  envoie pas ses points personnalisés **[V]**.
- **Cloud API** (celle de `WahooClient`) **[V]** : `POST /v1/routes` exige un `route[file]` FIT en
  base64, `external_id`, `name`, `workout_type_family_id`, `start_lat/lng`, `distance`, `ascent` ;
  **FIT seulement**, et **aucun champ POI, waypoint ou course point**. Les intégrations open source
  qui l'emploient n'envoient qu'un FIT.
- **Inconnu** : ce que deviennent les `course_point` d'un FIT envoyé par cette API. Par analogie
  avec l'import par l'app, on peut s'attendre à des points affichés avec l'icône générique et leur
  nom **[NV, déduction]**. Les icônes typées des partenaires passent sans doute par une intégration
  propre à chacun, que Wahoo tire de leur API **[NV, déduction]** : Pédalons n'y a pas accès.

**À retenir.** Pour Wahoo, le seul canal de Pédalons est le FIT de la Cloud API ; le **nom** du
point devra porter le sens à lui seul.

### 4.6 Synthèse

| | Point de routage | Point d'information sur le tracé | POI hors tracé | Fichier exporté avec points |
|---|---|---|---|---|
| Komoot | oui, insertion « au meilleur endroit » | point personnalisé (nom, description, catégorie) | POI OSM, Highlights | **aucun** |
| RWGPS | point de contrôle | waypoint (= cue + POI + point de contrôle) | POI (39 types), Highlights | FIT/TCX (cues en course points), GPX (`<wpt>` à la demande) |
| Strava | oui | custom waypoint | — | non documenté |
| Garmin Connect | oui | course point, posé sur la ligne, ~15 caractères | — (heatmap, popularité) | FIT de l'appareil ; à l'import : GPX → points à < 40 m, FIT → sans noms, TCX → sans points **[NV]** |
| Wahoo | pas d'éditeur | ceux des partenaires seulement | — | import de fichiers, icône générique |
| **Pédalons (C3)** | point de contrôle (existant) | **point d'auteur** | POI de la carte, à adopter (C3g) | **FIT (`course_point`) et GPX (`<wpt>` typés)** |

Les trois éditeurs indépendants ont convergé en 2025-2026 vers le même objet : un point **attaché au parcours**, typé,
avec icône, nom et description, visible dans la chronologie ou la cue sheet et poussé vers les
compteurs **par leurs propres intégrations**. Pédalons peut faire mieux sur un point : l'exporter
aussi dans les fichiers, que Komoot n'exporte pas.

---

## 5. gpx.studio

Lu au commit `6a0d4343` (chemins relatifs à `gpx.studio/`).

**Modèle.** Un waypoint appartient au **fichier**, pas à une trace : `GPXFile.wpt: Waypoint[]`
(`gpx/src/gpx.ts:126`). La classe `Waypoint` (`gpx/src/gpx.ts:1511-1660`) porte `name`, `cmt`,
`desc`, `link`, `sym`, `type`, `ele`, `time`, sans `extensions` : celles d'un `<wpt>` sont perdues
à l'export (`toWaypointType`, `:1565-1590`). L'état passe par Immer (`produceWithPatches`,
`website/src/lib/logic/file-action-manager.ts:167-218`), dont les patches font l'annulation.
**Aucune distance le long du tracé, aucun lien à une trace, rien dans le profil altimétrique**
(aucune référence dans `components/elevation-profile/`).

**Import et export.** Lecture fast-xml-parser (`gpx/src/io.ts:40-112`) ; les `<rte>` deviennent des
traces et le `name`/`sym` d'un `<rtept>` est perdu (`gpx.ts:1851-1890`). Export en GPX seul,
`<wpt>` réécrits avec leurs champs standard (`io.ts:114-161`). Ni FIT, ni TCX.

**Outil « Point d'intérêt »** (`website/src/lib/components/toolbar/tools/waypoint/Waypoint.svelte`) :

- un clic sur la carte remplit lat/lon (`:108-111`, `:144-149`) : **position libre, aucune
  accroche au tracé** ; l'altitude vient du MNT (`getElevation`, `file-actions.ts:680-706`) ;
- formulaire nom, description, symbole, lien ; une seule zone écrit `desc` **et** `cmt`
  (`:94-96`) ;
- le point est ajouté **à chaque fichier sélectionné** (`file-actions.ts:695-704`) ;
- glisser seulement outil actif, mise à jour par `GeoJSONSource.updateData` puis une action
  annulable au relâchement (`gpx-layer.ts:594-703`) ; Maj + clic supprime (`:564-565`).

**Symboles** : 41 entrées codées en dur, clé → **nom de symbole Garmin** + icône Lucide, par
exemple `drinking_water: { value: 'Drinking Water', icon: Droplet }`
(`website/src/lib/assets/symbols.ts:74-131`). Un `sym` inconnu reste affiché tel quel avec
l'icône par défaut.

**Rendu.** Une source GeoJSON et une **couche `symbol`** par fichier (`gpx-layer.ts:280-309`) :
`icon-image` par entité, `icon-allow-overlap: true`, **pas de texte**, pas de regroupement. L'icône
est un SVG composé (épingle, symbole Lucide, carré de la couleur du fichier) chargé par
`map.addImage` (`:85-112`, `:779-797`). Survol → popup partagé ; seule la prévisualisation de
l'outil est un `maplibregl.Marker` DOM.

**POI OSM.** Une couche Overpass (`components/map/layer-control/overpass-layer.ts`) : serveur
`overpass.gpx.studio`, zoom ≥ 12, requêtes par tuile z12, cache Dexie de 7 jours, au plus cinq
requêtes en vol. Une vingtaine de catégories, toutes éteintes par défaut (`assets/layers.ts:892-936`,
`:1183-1490`) : eau (`drinking_water`, `water_point`, source potable), toilettes, boulangerie,
alimentation, cafés et restaurants, abris, campings, points de vue, sommets (`natural=peak`),
magasins de vélo… pas de station de réparation. Le popup d'un POI a un bouton qui **en fait un
waypoint** : nom ou libellé de la catégorie, tous les tags dans `desc`, `sym` de la catégorie,
`link` = `website` (`OverpassPopup.svelte:32-54`).

**À retenir** : la convention `sym` = nom Garmin, la couche `symbol` à icônes composées, le POI
OSM transformé en point en un clic. **À ne pas reprendre** : le point flottant sans distance, qui
ne peut ni devenir un course point ni s'afficher sur le profil.

---

## 6. vcyclist

vcyclist est la bibliothèque de traitement GPX et FIT de Pédalons (`backend/pom.xml:25`, version
6.10.0).

- **Modèle** : `GpxWaypoint(latitudeDeg, longitudeDeg, elevationM?, name?, description?, symbol?,
  type?, timeEpochMs?)` (`vcyclist/gpx/src/commonMain/kotlin/io/github/glandais/engine/gpx/Gpx.kt:32-43`),
  porté par le document et non par le tracé : ils « never enter a Path » (`:19-21`), ce qui les
  protège du rééchantillonnage et du recalcul d'altitude. Pas de distance.
- **GPX** : lecture de `ele`, `time`, `name`, `desc`, `sym`, `type` sans les extensions
  (`GpxParser.kt:305-372`) ; écriture dans l'ordre du XSD, avant `<trk>` (`GpxWriter.kt:141-176`).
  Les `<rtept>` deviennent des points de trace, leur nom est perdu (`GpxParser.kt:258-267`).
- **FIT : aucun `course_point` écrit.** `FitEncoder.encode` n'émet que `file_id`, `course`, `lap`,
  `event` et `record` (`vcyclist/fit/src/commonMain/kotlin/io/github/glandais/fit/FitEncoder.kt:60-79`) ;
  `FitCourse` n'a pas de champ pour eux (`FitCourse.kt:16`).
- **Mais le SDK est prêt** : `fit-kotlin-sdk` 21.217.0 fournit `CoursePointMesg` (`messageIndex`,
  `timestamp`, `positionLat/Long`, `distance` en m, `type`, `name`, `favorite`) et l'énumération
  complète (`fit-kotlin-sdk/src/commonMain/kotlin/com/garmin/fit/CoursePointMesg.kt:31-66`,
  `types/CoursePoint.kt:20-72`). Les records reçoivent `timestamp = startTime + (time(i) − time(0))`
  et `distance = distanceStart + distance(i)` (`PathToFit.kt:166`, `:171`) : un course point aligné
  sur un record n'a qu'à reprendre ces deux valeurs.
- **Aucune projection** d'un waypoint sur le tracé. Deux briques réutilisables : `Distance.pointToSegment3D`
  (`vcyclist/elevation/.../Distance.kt:49-61`, projection bornée sur un segment, qui rend la
  distance mais pas le paramètre) et `Corridor.applySelfProximityClamp`
  (`vcyclist/engine/.../trajectory/Corridor.kt:144-210`), seul code qui distingue deux passages au
  même endroit : grille de hachage sur les voisins, puis « autre portion de route » si l'écart de
  distance le long du tracé ou de cap est trop grand. C'est exactement le critère dont la
  ré-accroche a besoin (§11.3).
- **UI** : la démo Vue n'affiche pas les waypoints, ne les édite pas, et le profil ne les montre pas.
- **Lien avec Pédalons** : le plan [`2026-07-28-migration-vcyclist.md`](../plans/2026-07-28-migration-vcyclist.md)
  porte sur la migration gpx2web → vcyclist du backend ; il ne cite les waypoints que pour la
  collision de nom avec l'entité `GpxWaypoint` (`:194`) et leur réinjection dans `filtered.gpx`
  (`:358`, `:382`). Il ne dit rien des course points ; le ledger acte la perte (`API-55` :
  « vcyclist n'écrit pas de `course_point` »).

**À reprendre pour C3** : le SDK FIT tel quel ; une évolution de vcyclist (`FitCourse.coursePoints`,
émission des `CoursePointMesg` après les records, alignés sur eux), publiée dans une 6.11 ; le
critère de `Corridor` pour départager les passages multiples ; `TrackAttachmentSanitizer.readFit`
(`backend/.../service/gpx/TrackAttachmentSanitizer.java:149-162`), à étendre pour garder `type` et
`distance` d'un FIT importé.

---

## 7. Rendu MapLibre, web et mobile

### 7.1 Web (maplibre-gl 6.14.0, react-map-gl 8)

| | Couche `symbol` + `addImage` | `Marker` DOM |
|---|---|---|
| Nombre de points | des milliers ; collisions et regroupement (`cluster: true`) gérés par le moteur **[V]** | un nœud DOM repositionné à chaque image : quelques dizaines **[NV, savoir commun]** |
| Icônes | une image par type, ou une seule image SDF recolorée par `icon-color` (« only … with SDF icons ») **[V]** | n'importe quel composant React, icônes Tabler comprises |
| Collisions | `icon-allow-overlap`, `text-optional`, `symbol-sort-key` (« lower sort keys are drawn and placed first ») **[V]** | aucune : tout se superpose |
| Glisser | pas natif ; patron officiel *create-a-draggable-point* : `mousedown` sur la couche, `mousemove` + `setData`, `mouseup` **[V]** | natif (`draggable`, `dragend`) **[V]** |
| Clic, survol | `queryRenderedFeatures`, `setFeatureState` (exige un `id` ou `promoteId`) **[V]** | événements React |
| Profil, SSR | aucun effet | aucun effet |

Le dépôt pratique les deux : les points de contrôle du planificateur sont des `Marker` DOM
glissables (`RoutePlanner.tsx:1524-1532`) ; les chevrons de sens sont une couche `symbol` dont
l'image est dessinée sur un canvas et ajoutée par `map.addImage`, **reposée à chaque changement
de fond** grâce à `setMissingStyleImageResolver` (`components/map/RouteArrows.tsx:36-56`). C'est le
patron à reprendre pour des icônes de type.

### 7.2 Mobile (`maplibre` 0.3.6, `mobile/pubspec.yaml:52`)

Le paquet de joscha-eckert (et non `maplibre_gl`) **[V, source lu dans `~/.pub-cache`]** :

- `StyleController.addImage(id, bytes)` et ses variantes `addImageFromIconData`,
  `addImageFromCanvas`, `addImageFromWidget` ; **ni `sdf` ni `pixelRatio`** : une image par type et
  par couleur ;
- `GeoJsonSource` **sans option `cluster`** ; `SymbolStyleLayer`, `CircleStyleLayer` ;
- `WidgetLayer` de `Marker` Flutter, reprojetés à chaque build (« TODO: filter markers that are
  completely outside of the visible screen ») ;
- **aucune API de glisser** ; `featuresAtPoint` / `featuresInRect` pour le toucher, sans
  `querySourceFeatures` ni filtre.

Le mobile dessine déjà les waypoints en `CircleStyleLayer` (`pdl_map_controller.dart:1116-1149`,
ambre `#FAB005`) et leurs libellés en `WidgetLayer` (`pdl_map.dart:461-481`), **toujours visibles**,
alors que le web les cache sous le zoom 12 depuis `36835aabc` (`MapMarkers.tsx:133`). Les chevrons
suivent le même patron qu'au web (`pdl_map_controller.dart:1029-1047`). Le mobile ne fait que de la
consultation : aucun glisser n'y est nécessaire pour C3.

---

## 8. Points d'intérêt OSM

**Les tags utiles à un club** ([wiki OSM](https://wiki.openstreetmap.org/)) :

| Besoin | Tags | Remarque |
|---|---|---|
| Eau potable | `amenity=drinking_water` ; `man_made=water_tap` + `drinking_water=yes` ; `natural=spring` + `drinking_water=yes` | `seasonal=yes` pour un point fermé l'hiver **[V]** ; `amenity=water_point` sert aux réservoirs (camping-cars) **[V]** |
| Toilettes | `amenity=toilets` | **[NV, tag standard]** |
| Ravitaillement | `shop=bakery`, `amenity=cafe`, `shop=convenience`, `shop=supermarket`, `amenity=fuel` | **[NV]** |
| Réparation | `amenity=bicycle_repair_station` (« tools, a pump and a repair stand », `service:bicycle:pump`) ; `shop=bicycle` | **[V]** |
| Cols | `mountain_pass=yes` (« highest point of a mountain road … », sur un nœud de la voie) ; `natural=saddle` (le col topographique) | **[V]** |
| Point de vue, abri | `tourism=viewpoint`, `amenity=shelter` (`shelter_type`) | **[V]** pour l'abri |
| Secours | `emergency=defibrillator`, `amenity=pharmacy` | **[V]** pour le défibrillateur |

**Overpass** ([politique d'usage](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html))
**[V]** : « a maximum of about 10000 requests per day » et « below about 1 GB per day », 180 s et
512 MiB par requête, HTTP 429 au-delà d'un créneau ; le wiki conseille de diviser ces chiffres par
cent pour un usage régulier. La forme `(around:200, lat1, lon1, …, latn, lonn)` filtre le long
d'une polyligne (depuis 0.7.55), à simplifier au préalable. Interroger Overpass à chaque geste de
l'éditeur est exclu ; une fois par enregistrement, en cache, resterait raisonnable pour quelques
centaines de parcours par jour **[NV, déduction]**.

**Ce que font les autres.** Komoot sépare les POI OSM, en lecture seule, des Highlights
communautaires ; l'un comme l'autre s'ajoute au parcours comme point de passage (§4.1). RWGPS a
des POI d'auteur typés et des « highlights » communautaires (§4.2). gpx.studio interroge Overpass
par tuile et transforme un POI en waypoint en un clic (§5).

**La distinction à garder** : un *point d'auteur* est une intention (« regroupement ici ») que
l'auteur crée, nomme et assume ; un *POI suggéré* est une donnée tierce (« il y a une fontaine à
80 m »), qui ne part sur les compteurs que si l'auteur l'adopte. Adopter un POI le copie en point
d'auteur (type, nom, position) ; il n'y a pas de lien vivant avec OSM.

---

## 9. Les POI des tuiles VersaTiles

Le fond « Plan » des deux clients est VersaTiles, au schéma **Shortbread** : `colorful` et sa
variante sombre, configurés dans `application.properties:207-211`, lus par le web
(`hooks/useMapStyle.ts:15-30`) et le mobile (`config_provider.dart:86,112`) à travers
`/api/config` **[V]**. Les tuiles sont celles de `tiles.versatiles.org/tiles/osm`, planète entière,
zooms 0 à 14 ; le dépôt n'en héberge aucune. Le `tileserver` local ne sert qu'aux vignettes, avec
des copies de style anciennes (`data/tileserver/styles/colorful.json`, POI à z16, sprite `basics`)
sans effet sur les clients.

**La couche `pois`** ([schéma 1.1](https://shortbread-tiles.org/schema/1.1/), constaté sur des
tuiles décodées à Paris, Lyon et au Galibier) **[V]** :

- **« All features are available on zoom level 14 only »** ; le TileJSON live dit `pois 14 14` ;
  une tuile z13 n'a pas de couche `pois` ;
- attributs : `amenity`, `shop`, `tourism`, `leisure`, `man_made`, `historic`, `emergency`,
  `highway`, `office`, plus `name`, `name_fr` (et dix autres langues), `cuisine`, `information`,
  `vending`… ;
- le TileJSON annonce `shortbread@1.0` (données OSM du 7 juin 2026) mais sert déjà des valeurs de
  la 1.1 (`amenity=fuel`, `leisure=park`).

| Catégorie | Dans le schéma | Tuile de Paris |
|---|---|---|
| `amenity=drinking_water` | oui | 46 |
| `amenity=toilets` | oui | 47 |
| `shop=bicycle` | oui | 18, nommés |
| `amenity=bicycle_repair_station` | **non** | — |
| `shop=bakery` / `amenity=cafe` | oui | 63 / 135 |
| `amenity=fuel` | oui (1.1) | servi |
| `tourism=viewpoint`, `amenity=shelter`, `emergency=defibrillator` | oui | défibrillateurs : 46 |
| `natural=peak`, `natural=saddle`, `mountain_pass` | **non, dans aucune couche** | — |

**Les cols manquent.** L'extension VersaTiles `mountain_peaks` (`kind` = peak, volcano, saddle) est
documentée ([extensions.md](https://github.com/versatiles-org/planetiler-shortbread/blob/main/docs/extensions.md))
mais **absente des tuiles servies** (TileJSON) ; `mountain_pass` n'y figure de toute façon pas. Au
Galibier, le col n'apparaît que comme un panneau (`tourism=information`, `information=guidepost`,
« Col du Galibier ») **[V]**.

**Côté style** (versatiles-style 7.0.1, 15 octobre 2026) : neuf couches `poi-*` à partir du zoom 14,
texte `name` (et non `name_fr`), icônes du sprite `base` (126 entrées : `icon-drinking_water`,
`icon-restrooms`, `icon-cafe`, `icon-bakery`, `icon-viewpoint`, `icon-shelter`…, **aucune icône
vélo ni sommet**, `shop=bicycle` retombe sur `icon-shop`) **[V]**. `eclipse/style.json` répond par
une redirection 301 vers `colorful-dark` **[V]** : la configuration du dépôt passe par cette
redirection.

**Interroger** **[V, doc de maplibre-gl 6.14]** : `queryRenderedFeatures` exclut les couches hors de
leur plage de zoom et les symboles masqués par collision ; `querySourceFeatures` ne voit que les
tuiles chargées, et un point près d'un bord « may appear in multiple tiles ». Au mobile, seul
`featuresAtPoint` / `featuresInRect` existe.

**Ce que ces tuiles permettent pour C3** :

- **Toucher un POI de la carte pour en faire un point de parcours**, au web comme au mobile, dès le
  zoom 14 et sur le fond « Plan » : nom, `name_fr` et catégorie pré-remplissent le formulaire
  **[NV, l'API le documente, non essayé]**. Filtrer sur `sourceLayer === 'pois'` plutôt que sur les
  identifiants `poi-*`, qui dépendent du style VersaTiles (deux versions majeures en
  septembre-octobre 2026). Un POI masqué par collision n'est pas touchable ; 41 % des POI de la
  tuile de Paris n'ont pas de nom, d'où un libellé par défaut tiré du type.
- **Suggérer les POI le long de tout un tracé sans Overpass : non.** Seules les tuiles z14
  chargées sont lisibles, soit la portion visible à z ≥ 14 ; il faudrait décoder côté serveur
  toutes les tuiles z14 du corridor depuis un service tiers, ou héberger un fichier `.versatiles` ou
  PMTiles.
- **Ce qui manque** : cols et sommets, stations de réparation, `bicycle_parking` (seulement en
  polygone dans `sites`), tout en dessous du zoom 14, et tout fond autre que « Plan » (IGN,
  satellite, OSM raster, CyclOSM, Michelin n'ont aucun POI touchable).

---

## 10. L'existant dans Pédalons

**En une phrase** : un waypoint est une position et un nom, en lecture seule ; la base le stocke,
l'API l'expose, le web et le mobile l'affichent, il sert à nommer les cols ; rien ne le crée, rien
ne l'exporte avec un type, et la moindre retouche du tracé l'efface.

| Couche | Ce qui existe | Où |
|---|---|---|
| Entité | `GpxWaypoint` : `route` (non nul), `name` (250, **non nul**), `geometry Point 4326` ; ni type, ni description, ni altitude, ni ordre, ni distance | `backend/.../domain/route/GpxWaypoint.java:15-35` ; `V2__initial_schema.sql:137-148` ; index `V3:22-24`, `V9:102` |
| Relation | `Route.waypoints`, `cascade = ALL`, `orphanRemoval` | `Route.java:76-77`, `:95-98` |
| Import GPX | vcyclist lit tout ; **`GpxSanitizer` ne garde que lat, lon, nom** (altitude nulle) — décision `API-44` | `service/route/GpxSanitizer.java:60-66` |
| Import FIT joint | `CoursePointMesg` relus en waypoints, position et nom seulement | `service/gpx/TrackAttachmentSanitizer.java:117-162` |
| Persistance | `ComputedWaypoint(name ?? "", point)` | `GpxProcessingService.java:264-272`, `:481-483`, `:550` |
| **Retouche du tracé** | `route.getTracks().clear(); route.getWaypoints().clear();` | `RouteService.java:543-544` |
| Éditeur | `PlannerState` sans waypoint ; l'import ne rend que `waypointCount` ; notification « ne sont conservés que si vous enregistrez le tracé sans le modifier » | `common/planner/PlannerState.java:21-32` ; `GpxImportService.java:77` ; `RoutePlannerField.tsx:291-299` |
| Export GPX | `filtered.gpx` réécrit les `<wpt>` (nom seul) ; `original.gpx` n'en a pas | `GpxProcessingService.java:262`, `:283-285` |
| Export FIT | **aucun `course_point`** ; `FitExporter` ne reçoit que des `Path` | `infrastructure/gpx/FitExporter.java:39-51` ; `LEDGER_DONE API-55` |
| Garmin Courses | `geoPoints` seulement, **aucun `coursePoints`** | `infrastructure/gps/GarminCourseConverter.java:48-53`, `:99-120` |
| Wahoo | FIT construit à la volée, donc sans point | `infrastructure/gps/WahooClient.java:266-267`, `:325-328` |
| Hammerhead | GPX filtré brut, `<wpt>` avec nom | `infrastructure/gps/HammerheadClient.java:172-180` ; `service/gps/GpsRouteGpx.java:26-29` |
| Cols | une montée prend le nom du waypoint le plus proche de son sommet, à 300 m au plus (`API-10`) | `service/route/ClimbNaming.java:46-60` |
| Contrat | `WaypointDto(geometry, name)` dans `RouteDetailDto`, `GpxPreviewDto` ; **aucun endpoint d'écriture** | `dto/routes/response/WaypointDto.java` ; `contracts/openapi.yaml:7961-7970` |
| Web | `WaypointMarker`, `Marker` DOM, pastille jaune de 14 px, nom dès le zoom 12 | `components/map/MapMarkers.tsx:124-215` ; `RouteTrackMap.tsx:211-223` |
| Planificateur | aucun waypoint (`waypoints: []`) ; menu de B12 à un seul item, « Supprimer », ouvert seulement sur un marqueur ou une ancre importée ; pas de menu « Plus » | `lib/planner.ts:693` ; `RoutePlanner.tsx:113-125`, `:689-745`, `:1739-1771` ; `PlannerBottomBar.tsx:25-29` |
| Mobile | pastilles en `CircleStyleLayer`, libellés en `WidgetLayer`, sans seuil de zoom ; pas d'édition | `pdl_map_controller.dart:1116-1149` ; `pdl_map.dart:461-481`, `:520-560` |
| Karoo, Garmin | rien | `karoo/.../PedalonsExtension.kt` ; `garmin-app/source/ApiClient.mc` |

**Défauts trouvés en chemin** :

- `RouteTrackMap.tsx:214-215` teste `coordinates[0] && coordinates[1]` : un waypoint à longitude
  ou latitude exactement nulle disparaît (un point sur le méridien de Greenwich).
- **Perte probable à la promotion d'un aperçu** des outils GPX en parcours : `GpxPreviewService.java:626`
  relit l'*original*, écrit sans waypoint (`GpxProcessingService.java:262`, confirmé par le
  commentaire de `ElevationRefreshService.java:248`). Aucun test ne couvre ce cas **[NV, à
  vérifier par un test]**.
- Le nom `routePoints` désigne déjà les points envoyés au routeur (`RouteService.java:339-342`) :
  le nouveau concept ne doit pas le reprendre.

---

## 11. Réponses aux questions ouvertes

### 11.1 Types utiles à un club et correspondances

**Critères.** Un type n'existe que s'il change ce que fait le cycliste au passage (s'arrêter,
attendre, ralentir, remplir son bidon) ; chaque type a un `course_point` FIT exact ou voisin ; la
liste tient sur un menu de téléphone. Les instructions de virage (`left`, `right`…) sont exclues :
les compteurs les calculent eux-mêmes et Pédalons n'en produit pas (état de l'art §6.3).

**Douze types, et leur sort dans chaque format.** Les colonnes Karoo, Wahoo et RWGPS servent de
contrôle : le même concept existe-t-il ailleurs ?

| Type Pédalons | Libellé | `sym` GPX (Garmin) | `course_point` FIT | Garmin Courses API | TCX `PointType` | Karoo SDK (`Symbol.POI.Types`) | Karoo, import GPX (9 types, **[NV]**) | Icône Wahoo | Type RWGPS |
|---|---|---|---|---|---|---|---|---|---|
| `REGROUP` | Regroupement | `Flag, Blue` | `meeting_spot` (37) | `MEETING_SPOT` | Generic | `control` | Generic | `meeting_spot` | `control` (31) |
| `SUPPLY` | Ravitaillement | `Food Source` | `aid_station` (28) | `AID_STATION` | Food | `aid_station` | Food | `food` | `aid_station` (20) |
| `WATER` | Eau | `Drinking Water` | `water` (3) | `WATER` | Water | `water` | Water | `water` | `water` (30) |
| `CAFE` | Café, pause | `Restaurant` | `food` (4) | `FOOD` | Food | `coffee` | Food | `coffee` | `coffee` (38) |
| `TOILETS` | Toilettes | `Restroom` | `toilet` (39) | `TOILET` | Generic | `restroom` | Generic | `toilet` | `restroom` (15) |
| `DANGER` | Danger | `Danger Area` | `danger` (5) | `DANGER` | Danger | `caution` | Danger | `warning` | `caution` (37) |
| `SUMMIT` | Col, sommet | `Summit` | `summit` (1) | `SUMMIT` | Summit | `summit` | Summit | `summit` | `summit` (48) |
| `VIEWPOINT` | Point de vue | `Scenic Area` | `overlook` (38) | `OVERLOOK` | Generic | `viewpoint` | Generic | `viewpoint` | `viewpoint` (14) |
| `BIKE_SHOP` | Atelier, magasin vélo | `Car Repair` | `gear` (41) | `GEAR` | Generic | `bike_shop` | Generic | `bike_shop` | `bike_shop` (22) |
| `REAL_START` | Départ réel | `Flag, Green` | `checkpoint` (35) | `CHECKPOINT` | Generic | `control` | Generic | `checkpoint` | `start` (33) |
| `SPLIT` | Séparation des groupes | `Flag, Red` | `alert` (52) | `ALERT` | Generic | `caution` | Generic | `warning` | `caution` (37) |
| `INFO` | Information (défaut) | `Information` | `info` (53) | `INFO` | Generic | `generic` | Generic | `info` | `generic` (17) |

*Sources* : FIT et TCX **[V]** (§2) ; Courses API **[NV, spécification non officielle]** (§4.4) ;
symboles Garmin **[V dans GPSBabel]** ; types Karoo du SDK
**[V, code]** ; neuf types d'import GPX Karoo **[NV]** ; icônes Wahoo **[V, centre d'aide]** ;
types RWGPS **[V, référence de l'API]**. Les choix de correspondance eux-mêmes sont des
propositions.

**Les choix discutables, à trancher** (§13) :

- **`REAL_START` en `checkpoint` plutôt qu'en `segment_start`.** `segment_start` serait le plus
  juste, mais il est absent de Up Ahead sur un Edge 1040 **[NV]**, et Garmin l'emploie pour ses
  segments Strava Live. `checkpoint` s'affiche partout.
- **`SPLIT` en `alert`.** Aucun type FIT ne dit « séparation » ; `alert` (52) déclenche
  l'attention sans prétendre à un danger. Le nom du point (« Séparation A / B ») porte le sens.
- **`BIKE_SHOP` en `Car Repair` côté GPX** : aucun symbole Garmin « vélo » n'existe hors `Bike
  Trail`, qui désigne une piste. Le `sym` ne compte que pour un GPX téléchargé à la main.
- **`CAFE` en `food` plutôt qu'en `rest_area`** : un club s'arrête au café pour manger, et `food`
  existe aussi en TCX.
- **Pas de type « eau » distinct de « ravitaillement » ?** Gardé : une fontaine n'est pas un
  ravitaillement organisé, et l'eau est le seul type que les quatre écosystèmes partagent.

**Le nom.** TCX le limite à 10 caractères, l'exemple du SDK FIT à 16 octets, un Edge tronque le nom
d'un parcours vers 15 caractères **[NV]**. Proposition : un nom de **40 caractères au plus** dans
Pédalons, exporté tel quel dans le GPX ; dans le FIT, un `name` de **15 caractères** (tronqué à un
mot si possible) et le libellé du type quand le nom est vide. La description ne part que dans le
GPX (`<desc>`) : le FIT n'a pas de champ pour elle.

### 11.2 Hammerhead et les `<wpt>` GPX

> **Vérifié le 20 octobre 2026 (C3a, kit d'essai local non versionné).** Par l'API de
> routes, seul un GPX dont `<type>` et `<sym>` valent l'une des neuf valeurs, casse exacte, garde ses
> points : `pointsOfInterest` sur le Dashboard (`Danger` → `caution`, `Food` → `food`…, point hors
> tracé compris, accents et 40 caractères intacts) et points affichés sur le Karoo. Le GPX actuel, le
> GPX aux `sym` Garmin, un GPX aux types du SDK karoo-ext en minuscules et le FIT à `course_point`
> perdent tous leurs points. Ce qui suit est l'état d'avant l'essai.

- **Officiellement ignorés** à l'import d'un GPX, sur le Dashboard comme sur le Karoo
  (article 360036632794, mis à jour en mai 2024) **[V]**. C'est le cas exact de Pédalons, qui
  pousse aujourd'hui un GPX filtré par `POST /v1/api/routes/file`.
- **Contournement non officiel** : `<type>` et `<sym>` parmi `Food`, `Water`, `Parking`,
  `Camping`, `Lodging`, `Geocache`, `Summit`, `Generic`, `Danger` **[NV, juin 2026]**. Il est
  gratuit à essayer : la colonne « Karoo, import GPX » du §11.1 donne la valeur à écrire.
- **Inconnu** : un FIT avec `course_point` envoyé à la même API. L'API accepte le FIT **[V]** ; ce
  qu'elle fait des points n'est documenté nulle part.
- **Ce que font les autres** : Komoot et RWGPS passent par leur propre synchronisation de compte
  vers le Dashboard, pas par un fichier **[V]**. L'API publique de routes n'a aucun champ POI.
- **Repli si les deux essais échouent** : l'extension Karoo de Pédalons lit le parcours suivi
  (`NavigatingRoute`, avec son nom et sa polyligne), récupère les points d'auteur par l'API
  Pédalons, les dessine (`ShowSymbols`) et alerte à l'approche (`InRideAlert`, `PlayBeepPattern`).
  Faisable avec le SDK actuel **[V, code]**, mais c'est une fonctionnalité à part entière (C3h).

**Essai à faire en premier** (C3a, S) : un parcours de test avec trois points, poussé à Hammerhead
en trois variantes (GPX actuel ; GPX aux neuf types ; FIT avec `course_point`), puis observé sur
le Dashboard et un Karoo.

### 11.3 Insertion « au meilleur endroit »

**Deux problèmes que la question confondait.**

1. *Pour un point de passage du routage* (un point de contrôle qui modifie le tracé), « au meilleur
   endroit » veut dire : entre quels points de la liste insérer un nouveau point ?
   - **Projection sur le segment le plus proche** : rapide, exacte quand l'auteur vise la ligne ;
     fausse sur un aller-retour, où deux segments sont à égale distance et le choix du mauvais
     sens crée un crochet. C'est ce que fait déjà le planificateur (`nearestSegment`,
     `lib/planner.ts:315-332`, décision D7 de B12).
   - **Minimisation de la longueur** (insertion au moindre coût) : choisir i qui minimise
     d(pᵢ₋₁, x) + d(x, pᵢ) − d(pᵢ₋₁, pᵢ). Juste pour un point posé *hors* de la ligne (« passer
     par ce café »), mais en vol d'oiseau elle ignore le réseau, et la faire sur des distances
     routées coûte une requête par candidat.
   - Komoot fait bien une insertion automatique « au meilleur endroit possible » **[V]**, sans dire
     laquelle ; RWGPS, avec « Include in Route », branche le point depuis le point le plus proche du
     tracé **[V]**, c'est-à-dire une projection.
   - Pédalons n'a pas de liste explicite de points de passage : la question reste sans objet tant
     que le planificateur n'en a pas (état de l'art §10, n° 2).
2. *Pour un point d'auteur*, qui **ne modifie pas le tracé**, il n'y a rien à insérer : il faut
   **l'accrocher à une distance** le long du tracé. C'est cette distance qui fait un course point
   FIT, place le point sur le profil et donne l'ordre de la liste.

**Trois cas d'accroche.**

| Cas | Méthode | Ambiguïté |
|---|---|---|
| Geste sur la ligne (clic droit, appui long) | le segment visé est connu : distance = distance cumulée de son début + projection | aucune |
| Point posé hors de la ligne (POI de la carte, café à 80 m) | projection sur le segment le plus proche, à moins d'un seuil | boucles et allers-retours |
| **Ré-accroche** après une retouche du tracé ou un import | projection, départagée par l'ancienne distance | boucles et allers-retours |

**L'algorithme proposé pour la projection**, côté serveur (qui seul calcule la distance de
référence, sur le tracé enregistré) et côté éditeur (pour l'aperçu) :

1. candidats : tous les segments à moins de **50 m** du point (Garmin Connect garde les `<wpt>` à
   moins de 39,67 m **[NV]** ; 50 m laisse passer un café en retrait de la route) ;
2. un candidat par passage : deux segments consécutifs du même passage ne comptent qu'une fois
   (le critère de `Corridor.applySelfProximityClamp` de vcyclist : écart de distance le long du
   tracé, ou de cap) ;
3. s'il y a plusieurs passages, garder **celui dont la distance est la plus proche de l'ancienne
   distance du point**, mise à l'échelle de la nouvelle longueur (un point au km 40 sur 100 reste
   vers 40 % du nouveau tracé) ; sans ancienne distance (import), garder le premier passage ;
4. aucun candidat : le point reste, **marqué hors tracé** ; il s'affiche et part dans le GPX, pas
   dans le FIT, et l'éditeur le signale.

L'ordre des points n'est pas stocké : c'est celui des distances.

---

## 12. Recommandation

### 12.1 Modèle de données

**Étendre `gpx_waypoints` plutôt que créer une table.** Un waypoint importé et un point d'auteur
sont la même chose pour un compteur ; deux tables doubleraient chaque export, chaque affichage et
chaque test. Colonnes ajoutées (migration additive, compatible avec le déploiement progressif) :

| Colonne | Type | Rôle |
|---|---|---|
| `type` | varchar, enum `WaypointType` (§11.1), défaut `INFO` | sémantique et export |
| `description` | varchar(500), nullable | `<desc>` GPX, popup |
| `distance_m` | double, nullable | distance le long du tracé ; nulle = hors tracé |
| `origin` | `IMPORTED` \| `AUTHOR` | provenance, pour l'affichage et la ré-accroche |

`name` reste non nul mais peut être vide (comme aujourd'hui) ; il passe à 40 caractères dans les
requêtes, la colonne de 250 restant pour les imports. `geometry` garde la **position voulue par
l'auteur** (le café, pas sa projection) ; la projection se recalcule depuis `distance_m`. Ni table
de liaison à une trace, ni index d'ordre.

**À l'import**, reconnaître les `sym` Garmin et les `type` FIT usuels pour donner un type (`Drinking
Water` → `WATER`, `Summit` → `SUMMIT`…), sans stocker la valeur brute : `API-44` ne garde du
fichier que ce qui sert, et le type en est. Un FIT importé donne son type et sa distance.

**Contrat** (mineur, additif) : `WaypointDto` gagne `type`, `description`, `distance`, `origin` ;
les requêtes de création et de modification d'un parcours gagnent une liste `waypoints`
**remplaçant** la liste existante (l'éditeur envoie l'état complet, comme pour le tracé) ;
modifier les seuls points ne recalcule pas le tracé. `pedalons.api.version` passe de 11.14.0 à
11.15.0.

**Couleur du type** : une famille par type dans `contracts/brand-colors.yaml`, comme les autres
énumérations métier (règle du `CLAUDE.md` racine) ; l'icône est une icône Tabler au web et son
équivalent au mobile.

### 12.2 Cycle de vie

- **Une retouche du tracé ne vide plus les waypoints** (`RouteService.java:544`) : ils sont
  ré-accrochés (§11.3) ; ceux qui ne le sont pas restent, marqués hors tracé. La notification de
  l'éditeur « waypoints perdus » disparaît.
- L'éditeur charge **tous** les waypoints, importés compris, et renvoie la liste complète. Les
  points font partie de l'historique (annuler, rétablir) au même titre que le tracé.
- Remplacer le fichier GPX d'un parcours remplace les points importés et ré-accroche les points
  d'auteur.
- **Les fichiers dérivés sont régénérés** quand seuls les points changent : `filtered.gpx` et
  `route.fit` sont en S3 et portent les points.
- Le nom d'une montée (`ClimbNaming`) suit les points de type `SUMMIT` en priorité.

### 12.3 Export par format

| Sortie | Aujourd'hui | Proposé |
|---|---|---|
| GPX téléchargé (`filtered.gpx`) | `<wpt>` avec `name` | `<wpt>` avec `name`, `desc`, `sym` Garmin, `type` = nom FIT du type (`meeting_spot`…), comme RWGPS **[NV]** ; points hors tracé compris |
| FIT téléchargé, app Connect IQ, Wahoo (Cloud API) | aucun point | un `course_point` par point accroché : `type` FIT, `name` de 15 caractères, **position, distance et timestamp du record le plus proche** (records tous les 10 m au plus, donc à 5 m près) ; triés par distance ; au plus 200 ; écrits après les records et avant `event` stop — évolution de vcyclist (`FitCourse.coursePoints`, `FitEncoder`) |
| Garmin Courses API | `geoPoints` | un geoPoint de plus par point accroché, inséré à sa distance, avec `information: { name, coursePointType }` (colonne « Garmin Courses API » du §11.1) — forme à confirmer sur la documentation partenaire que Pédalons a reçue (C3a) |
| Hammerhead | GPX filtré, `<wpt>` ignorés | selon l'essai de C3a : GPX aux neuf types, ou FIT avec `course_point` (l'API accepte les deux) ; sinon repli sur l'extension (C3h) |
| TCX | n'existe pas | ne pas ajouter |

### 12.4 Affichage

- **Web, consultation** : une couche `symbol` par carte, icône du type dessinée sur canvas et
  reposée à chaque changement de fond (patron de `RouteArrows.tsx`), nom dès le zoom 12
  (`text-optional`, `symbol-sort-key` par importance du type), popup au survol ou au toucher.
  `WaypointMarker` (DOM) est retiré, ce qui corrige au passage le test sur les coordonnées nulles.
- **Profil altimétrique** web et mobile : un repère par point accroché, à sa distance. C'est ce
  que gpx.studio ne sait pas faire et que la distance stockée rend gratuit.
- **Liste** « Points du parcours » sous le profil : km, type, nom, description ; toucher centre la
  carte.
- **Éditeur** : les points d'auteur sont des `Marker` DOM glissables (comme les points de
  contrôle : quelques dizaines au plus), **contraints au tracé pendant le glisser** (la position
  suit la projection du pointeur ; Alt les libère, pour un café en retrait).
- **Mobile** : `SymbolStyleLayer` à une image PNG par type (`addImageFromIconData`), libellés
  alignés sur le web (seuil de zoom 12), repères sur le profil. Pas d'édition (le mobile n'a pas
  d'éditeur).

### 12.5 Les gestes de l'éditeur

- **Ajouter** : clic droit ou appui long de 500 ms **sur la ligne**, n'importe où → menu
  « Ajouter un point de parcours » (avec « Supprimer » quand la cible est une ancre importée,
  comme aujourd'hui). Le menu de B12 ne s'ouvre aujourd'hui que sur un marqueur ou une ancre
  importée (`RoutePlanner.tsx:689-745`) : C3 l'ouvre sur toute la ligne, et sur un tronçon routé il
  ne contient que « Ajouter » (S3 de l'étude de suppression tient). Un formulaire en popover
  demande le type (grille d'icônes, `REGROUP` présélectionné), le nom et la description.
- **Modifier, supprimer** : toucher un point ouvre le même formulaire, avec « Supprimer ».
- **Au doigt**, sans clic droit : l'appui long suffit ; le menu « Plus » de D8 n'est pas
  nécessaire pour C3.
- **Coût** : 0 requête au routeur, quel que soit le geste.

### 12.6 Découpage

| Tâche | Contenu | Taille | Dépend de |
|---|---|---|---|
| **C3a** | Essais sur appareils et documentation : parcours de test à trois points poussé à Hammerhead (GPX actuel, GPX aux neuf types, FIT avec `course_point`), à Wahoo (FIT, icônes ?), à un Edge par l'app Connect IQ et par la Courses API (`geoPoints[].information`, §4.4) ; confrontation de la spécification non officielle avec la documentation partenaire reçue par Pédalons ; troncature des noms. Fichiers FIT produits à la main avec le SDK | S | — |
| **C3b** | vcyclist 6.11 : `FitCourse.coursePoints`, émission alignée sur les records, tests ; lecture du `type` et de la `distance` d'un FIT importé | S | — |
| **C3c** | Backend : migration, enum, `WaypointDto` étendu, liste `waypoints` dans les requêtes, accroche et ré-accroche (§11.3), retouche du tracé qui garde les points, régénération des fichiers dérivés, exports GPX et FIT, Garmin et Hammerhead selon C3a ; correction de la promotion d'un aperçu si le test la confirme. Contrat 11.15.0 | M | C3b ; C3a pour Garmin et Hammerhead |
| **C3d** | Web, consultation : couche `symbol` à icônes, repères du profil, liste, popup ; `brand-colors.yaml` | M | C3c |
| **C3e** | Web, éditeur : menu sur toute la ligne, formulaire, glisser contraint, suppression, historique, ré-accroche en aperçu, envoi de la liste | L | C3c, C3d |
| **C3f** | Mobile, consultation : icônes, libellés au zoom 12, repères du profil, liste | M | C3c |
| **C3g** | *Optionnel* : POI de la carte → point de parcours (web, fond « Plan », zoom ≥ 14, `sourceLayer === 'pois'`, table tags OSM → type) | S | C3e |
| **C3h** | *Seulement si C3a échoue pour Hammerhead* : l'extension Karoo dessine les points et alerte à l'approche | L | C3c |

Hors de C3 : les **POI suggérés le long du tracé** (Overpass en cache par enregistrement, ou un
extrait OSM dans PostGIS), à proposer en « Délibérément dehors » tant qu'aucun club ne le demande :
les tuiles VersaTiles ne le permettent pas (§9), et Komoot comme RWGPS le réservent à leurs
abonnements payants.

### 12.7 Risques

- **Garmin Courses API** : la forme `geoPoints[].information` vient d'une spécification non
  officielle de 2020 ; si elle a changé, les points n'arrivent sur un Edge que par le FIT
  (téléchargement, app Connect IQ), pas par l'envoi automatique. Komoot prouve que l'API les
  accepte. Ne jamais conseiller l'import manuel du FIT dans Connect, qui retire les noms **[NV]**.
- **Wahoo** : la Cloud API n'a aucun champ de point ; au mieux, les `course_point` du FIT
  s'affichent avec l'icône générique.
- **Hammerhead** : si ni le GPX aux neuf types ni le FIT ne passent, le Karoo n'aura les points que
  par une extension (C3h, L).
- **Icônes génériques** sur Edge 1040 et sur Wahoo hors partenaires reconnus **[NV]** : le **nom**
  doit porter le sens à lui seul (« Regroupement », pas « R »).
- **Ré-accroche sur les boucles** : un point peut sauter de passage après une grosse retouche ; le
  marquer et le montrer vaut mieux que le deviner.
- **Dépendance à vcyclist** : une version publiée avant le backend ; FIT déterministe (`API-55`) à
  préserver, ce qui change les octets attendus des tests de réécriture.
- **`API-44`** : garder le type d'un waypoint importé élargit ce que l'on retient d'un fichier ;
  c'est une donnée de parcours, pas une donnée personnelle, mais la décision est à écrire.
- **Déploiement progressif** : l'ancienne version du backend, qui vide les waypoints à chaque
  retouche, tourne encore une minute à côté de la nouvelle ; un enregistrement fait pendant ce
  temps perd ses points d'auteur. Acceptable, mais à savoir.

---

## 13. Questions au propriétaire

**Toutes les propositions sont validées par le propriétaire le 20 octobre 2026** (plan, §10).

| # | Question | Proposition | Effet de l'autre choix |
|---|---|---|---|
| W1 | Une table ou deux ? | Étendre `gpx_waypoints` (`origin`) | Table `route_markers` à part : deux rendus, deux exports, et des waypoints importés toujours perdus à la retouche |
| W2 | Les douze types du §11.1 | Tels quels | Moins : on perd la sémantique sur l'appareil ; plus : un menu qui ne tient plus sur un téléphone |
| W3 | `REAL_START` en FIT | `checkpoint` | `segment_start` : plus juste, mais absent de Up Ahead sur Edge 1040 **[NV]** |
| W4 | Seuil d'accroche | 50 m | 40 m comme Garmin Connect : un café en retrait devient hors tracé |
| W5 | Un point hors tracé | Gardé, signalé, GPX seulement | Refusé : impossible de noter un café à 100 m de la route |
| W6 | Nom dans le FIT | 15 caractères, nom complet dans le GPX | Nom complet : tronqué par l'appareil, à un endroit inconnu |
| W7 | Garder le type d'un waypoint importé | Oui, déduit de `sym`/`type`, sans la valeur brute | Non (`API-44` à la lettre) : tout import arrive en `INFO` |
| W8 | POI de la carte → point (C3g) | Après l'éditeur, optionnel | Avant : utile, mais limité au fond « Plan » et au zoom 14 |
| W9 | POI suggérés le long du tracé | « Délibérément dehors » | Overpass en cache ou extrait OSM : M à L, plus une dépendance |

---

## 14. Sources

**Primaires (spécifications, SDK, documentation des éditeurs, code)**

- GPX 1.1 : [spécification](https://www.topografix.com/GPX/1/1/), [XSD](https://www.topografix.com/GPX/1/1/gpx.xsd) ;
  Garmin [GpxExtensions v3](https://www8.garmin.com/xmlschemas/GpxExtensionsv3.xsd),
  [TrackPointExtension v2](https://www8.garmin.com/xmlschemas/TrackPointExtensionv2.xsd).
- FIT : [`profile.js`](https://raw.githubusercontent.com/garmin/fit-javascript-sdk/main/src/profile.js)
  (profil 21.218), [fichier Course](https://developer.garmin.com/fit/file-types/course/),
  [Encoding Course Files](https://developer.garmin.com/fit/cookbook/encoding-course-files/),
  [protocole](https://developer.garmin.com/fit/protocol/), [`fit_example.h`](https://raw.githubusercontent.com/garmin/fit-c-sdk/main/example-sdk/fit_example.h).
- TCX : [TrainingCenterDatabasev2.xsd](https://www8.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd).
- GPSBabel, [`garmin_icon_tables.h`](https://github.com/GPSBabel/gpsbabel/blob/master/garmin_icon_tables.h).
- Garmin : manuel Edge 1050 ([course points](https://www8.garmin.com/manuals/webhelp/GUID-08ACA9FC-DEE6-4C8D-8A95-F62181C512E9/EN-US/GUID-7416CBA5-CEA0-45A5-B7D8-4D9B36419E6B.html),
  [ClimbPro](https://www8.garmin.com/manuals/webhelp/GUID-08ACA9FC-DEE6-4C8D-8A95-F62181C512E9/EN-US/GUID-EBAEC138-B55A-4730-8C10-DF21A40302A9.html)),
  [Courses API](https://developer.garmin.com/gc-developer-program/courses-api/).
- Wahoo : [import de fichiers](https://support.wahoofitness.com/hc/en-us/articles/25936827245970),
  [Custom Waypoints](https://support.wahoofitness.com/hc/en-us/articles/30255756674194),
  [Cloud API](https://cloud-api.wahooligan.com/).
- Hammerhead : [POI et GPX](https://support.hammerhead.io/hc/en-us/articles/360036632794),
  [POI du Dashboard](https://support.hammerhead.io/hc/en-us/articles/360040807874),
  [POI Cues](https://support.hammerhead.io/hc/en-us/articles/25642819120795),
  [Komoot](https://support.hammerhead.io/hc/en-us/articles/360045233754),
  [API](https://api.hammerhead.io/v1/docs/openapi.yml) ; [karoo-ext](https://github.com/hammerheadnav/karoo-ext) 1.1.9.
- Komoot : [journal des nouveautés](https://support.komoot.com/hc/en-us/articles/10621431252250),
  [export GPX](https://support.komoot.com/hc/en-us/articles/10115477099674),
  [Highlights](https://www.komoot.com/help/highlights).
- Ride with GPS : [formats d'export](https://support.ridewithgps.com/hc/en-us/articles/4419007646235),
  [waypoints, POI, highlights](https://support.ridewithgps.com/hc/en-us/articles/36570435135131),
  [référence des POI](https://ridewithgps.com/api/v1/doc/reference/points_of_interest),
  [OpenAPI](https://ridewithgps.com/api/v1/openapi.yaml).
- Strava : [Custom waypoints](https://support.strava.com/en-us/articles/15401644-custom-waypoints-on-strava-routes).
- Garmin Connect : [How to Build a Course](https://www.garmin.com/en-US/blog/fitness/how-to-build-a-course-in-garmin-connect/) (2023).
- Wahoo : [itinéraires dans l'app](https://support.wahoofitness.com/hc/en-us/articles/22710659712658),
  [notes de version du firmware](https://support.wahoofitness.com/hc/en-us/articles/26243446311826).
- MapLibre : [spécification des couches](https://maplibre.org/maplibre-style-spec/layers/),
  [API `Map`](https://maplibre.org/maplibre-gl-js/docs/API/classes/Map/),
  [`Marker`](https://maplibre.org/maplibre-gl-js/docs/API/classes/Marker/), exemples
  [draggable point](https://maplibre.org/maplibre-gl-js/docs/examples/create-a-draggable-point/) et
  [clusters](https://maplibre.org/maplibre-gl-js/docs/examples/create-and-style-clusters/) ;
  paquet Flutter [`maplibre`](https://pub.dev/packages/maplibre) 0.3.6 (source lu).
- Shortbread : [schéma 1.0](https://shortbread-tiles.org/schema/1.0/), [1.1](https://shortbread-tiles.org/schema/1.1/) ;
  VersaTiles [TileJSON](https://tiles.versatiles.org/tiles/osm/tiles.json),
  [style colorful](https://tiles.versatiles.org/assets/styles/colorful/style.json),
  [sprite `base`](https://tiles.versatiles.org/assets/sprites/base.json),
  [extensions](https://github.com/versatiles-org/planetiler-shortbread/blob/main/docs/extensions.md).
- OSM : wiki ([drinking_water](https://wiki.openstreetmap.org/wiki/Tag:amenity=drinking_water),
  [bicycle_repair_station](https://wiki.openstreetmap.org/wiki/Tag:amenity=bicycle_repair_station),
  [mountain_pass](https://wiki.openstreetmap.org/wiki/Key:mountain_pass),
  [Overpass QL](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL)),
  [politique d'usage Overpass](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html).
- Code lu : gpx.studio (commit `6a0d4343`), vcyclist et fit-kotlin-sdk (copies locales), Pédalons
  (commit `36835aabc`).

**Secondaires (outils tiers, forums, presse)**

- Spécification Courses API 1.0.1, copie non officielle :
  [`courses.md`](https://github.com/clementpeleman/coach-v2/blob/main/api-docs/courses.md) ;
  code [quantified-self](https://github.com/jimmykane/quantified-self) (`functions/src/garmin/routes.ts`).
- PitStopper, [waypoints jetés au-delà de 39,67 m](https://pitstopper.net/blog/garmin-discards-distant-waypoints.html)
  et [GPX contre FIT](https://pitstopper.net/articles/gpx-waypoints-vs-fit-course-points.html) (juin 2026).
- Forums Garmin Connect : [ajout de course points](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-web/437595/garmin-connect---frustration-with-course-points),
  [types web contre app](https://forums.garmin.com/apps-software/mobile-apps-web/f/garmin-connect-web/283092/course-point-types).

- [coursepointer](https://github.com/mshroyer/coursepointer) (README et `docs/point_types.md`,
  septembre 2026) : tests de types sur Edge 1040 et Fenix 7, correspondance RWGPS → GPX/FIT.
- [gpx-poi-karoo-fixer](https://github.com/mendalka/gpx-poi-karoo-fixer) (juin 2026) : les neuf types
  Karoo.
- Forums Garmin : [200 course points](https://forums.garmin.com/sports-fitness/cycling/f/edge-530/305771/200-course-point-max-exceeded),
  [points à 0 km](https://forums.garmin.com/sports-fitness/cycling/f/edge-1040-series/369764/all-course-points-are-0m),
  [course points et TBT](https://forums.garmin.com/sports-fitness/cycling/f/edge-540-series/412738/course-points),
  [noms retirés par Connect](https://forums.garmin.com/developer/fit-sdk/f/discussion/380633/course_point-name).
- the5krunner, [Strava custom waypoints → Garmin](https://the5krunner.com/2023/10/19/strava-add-custom-waypoints-in-route-sync-to-garmin) (2023).

**Non vérifié, à lever par un essai (C3a)** : sort des `course_point` d'un FIT poussé aux API
Hammerhead et Wahoo (et icône sur Wahoo) ; forme actuelle des course points de la Courses API
Garmin (`geoPoints[].information`, longueur de `name`) ; perte des noms à l'import d'un FIT dans
Connect ; contournement GPX aux neuf types sur Karoo ; limite de 200 points et troncature des noms sur Edge x40/x50 ; icônes par
type sur Edge 1040.
