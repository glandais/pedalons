# Profil et revêtement par osm-route-details

Écrit le 5 novembre 2026. **État : conception, rien d'implémenté.** Ledger `API-150` (backend),
`OPS-58` (déploiement). Branche `feat/osm-route-details`, partie de `3d23f160` (`API-149`, trace
brute). Numéros vérifiés libres le 5 novembre 2026 : `API-150`, `OPS-58`, migration `V83`, contrat
`13.1.0` aujourd'hui.

Chemins relatifs à `backend/src/main/java/fr/pedalons/` sauf mention contraire.

---

## 1. En une page

[osm-route-details](https://github.com/glandais/osm-route-details) (Rust, API `1.4`,
`POST /v1/route-details`) rend en **un appel** le profil d'élévation (IGN LiDAR HD en France, repli
Mapterhorn, GLO-30 ailleurs ; ponts lus dans le MNS, tunnels, ouvrages hors OSM) et la typologie
(structure, revêtement, type de voie) le long d'une trace. Il reprend le moteur d'élévation de
vcyclist 6.11 et la chaîne HMM d'osm-surface, en mieux sur les ouvrages.

On remplace :

| Aujourd'hui | Demain |
|---|---|
| `GpxPipeline` + `VcyclistProducer` (deux `ElevationProvider`, `DemTileStore`) — altitude FAST (Mapterhorn) et HD (IGN) **dans la JVM** | `RouteDetailsClient` : mode `fast` pour FAST, mode `full` pour HD |
| osm-surface (`TraceAttributesClient`, `trace_attributes` Valhalla) + file `surface_refresh` | la typologie de **la même réponse `full`** que l'altitude HD |
| deux files, deux workers, deux backfills (`elevation_refresh`, `surface_refresh`) | **une** file, `elevation_refresh`, qui écrit profil et revêtement ensemble |

Ce qui **reste sur vcyclist** : modèle GPX (parse, écriture), `Path`, lissage, Douglas-Peucker,
détection des montées (`ClimbDetectorJvm`), export FIT, vent, vignettes de carte (`TileMapProducer`).
Seule la lecture du terrain et la correction des ouvrages sortent.

Gains : plus de tuiles MNT dans le tas du backend (`OPS-55`), plus de cadence IGN partagée entre
backends, un seul service tiers au lieu de deux, meilleurs ponts et tunnels, provenance du terrain
par tronçon.

## 2. Ce qu'on attend d'osm-route-details

Demandé à la session osm-route-details le 5 novembre 2026, formulé pour tout client interactif ;
**livré côté service en api `1.5`** (osm-route-details `b7a5709` sur `develop`, le 6 novembre 2026, pas encore poussé ni publié en image) :

1. **`options.profile: "fast" | "full"`** (défaut `full`, inchangé) ; `meta.profile` rend le profil
   effectif (il entre dans la clé d'idempotence). En `fast` :
   - aucune lecture IGN, Mapterhorn z12 partout (`mapterhorn_measured` en France) ;
   - file d'admission à part (`budget.fast_max_in_flight` / `fast_max_queued`), aucun créneau du
     budget IGN ; caches Mapterhorn et tuiles de rues partagés avec `full` ;
   - corrigés : ponts et tunnels OSM en droite entre culées ou portails (`interpolated_structure`),
     bosse sous un pont qui enjambe la route ; **pas** de tablier MNS (`dsm_deck`, `kept_ground`),
     pas d'heuristiques (ouvrages hors OSM, couvertures) ;
   - la typologie tourne toujours (elle porte les ouvrages) ; `segments[]` est donc disponible en
     `fast` aussi, sans surcoût notable.
   - `/v1/capabilities` : `defaults.profile`, `enums.profiles`, `profiles[]` avec
     `latency_target` (fast : 5 s à froid / 0,5 s à chaud pour 130 km ; full : 30 s / 0,5 s).
   - Mesuré le 5 novembre 2026 (release, caches vides) : fast 140 km 1,6 s à froid, 76 ms à
     chaud ; 0,8 s pendant un `full` à froid de 24 s ; full 140 km 16,9 s à froid. Écart de D+
     fast/full : +0,5 % en vallonné, −4,5 % en plat (Nantes, Mapterhorn z12 plus lisse).
2. **`points[].gain_cum_m` / `loss_cum_m`**, toujours présents : cumuls sur le profil interne
   densifié et lissé, non décroissants, constants sur un trou d'altitude, dernière valeur =
   `summary.gain_m` / `loss_m` (au cm). D+ d'une sous-plage = différence des cumuls aux bornes :
   c'est le `climb[]` de `processWithClimb`.

Le client vise l'api **≥ 1.6** (§2.3) (vérifiée au démarrage par `/v1/capabilities` : `fast` absent
de `enums.profiles` → log error, tout en `full`).

Image publiée : `ghcr.io/glandais/osm-route-details:1.5.0` (tag `v1.5.0`, `eff6d50`).

Demandé le 6 novembre 2026 (décision D1, §9) ; **livré côté service en api `1.6`** (règles
`2026.11.13`), image `ghcr.io/glandais/osm-route-details:1.6.0` (tag `v1.6.0`, `fb692ce`) :

3. **`segments[].surface.detail`** : v1 ne rend que `paved` / `unpaved` / `unknown`. Pédalons expose
   sept valeurs (`TrackSurface` : `PAVED`, `PAVED_ROUGH`, `GRAVEL`, `DIRT`, `PATH`, `UNKNOWN`,
   `OFF_NETWORK`). Le service a la valeur brute (VersaTiles shortbread@1.1 depuis le 27 octobre),
   prévue « V2 » à son contrat. Livré :
   - `segments[].surface.detail`, **omis** (pas `null`) sans valeur fine ; les segments se coupent
     aussi sur un changement de `detail` à classe égale (plus de segments qu'en 1.5) ;
   - `summary.by_surface_detail_m` (somme ≤ `length_m`) ; `/v1/capabilities` :
     `data.surface_detail = true`, `enums.surface_detail` ;
   - 13 valeurs, liste **ouverte** (tolérer l'inconnu, se replier sur `class`) : `paved` →
     `asphalt`, `concrete`, `paving_stones`, `sett`, `cobblestone` ; `unpaved` → `compacted`,
     `fine_gravel`, `gravel`, `dirt`, `sand`, `grass`, `wood`, `rock`. Chaque valeur implique une
     seule classe ;
   - **aucune inférence** : `detail` seulement avec `surface.source = tagged` sur un tag reconnu ;
     absent sans tag, sur `paved`/`unpaved`, sur une valeur rare, en `inferred_tracktype` et
     `inferred_highway`. Environ la moitié des routes françaises n'ont pas de tag : beaucoup de
     segments sans `detail` (mesuré : 72,6 km sur 140 km, exactement la longueur taguée).

   La phase C cible donc l'api **≥ 1.6**.

Rien d'autre n'est spécifique à Pédalons : costing (vélo seulement en v1, cf. §5.3), découpage
au-delà de 200 km et hors-réseau du planificateur restent côté client.

## 3. Client

`infrastructure/routedetails/` (nouveau paquet, à côté de `valhalla/` qui reste pour le routeur
Stadia) :

- `RouteDetailsClient` — MicroProfile REST client, configKey `osm-route-details`,
  `POST /v1/route-details`, `GET /v1/capabilities`. Décompression activée (gzip).
- DTO Java en records, **sous-ensemble** du contrat (les champs inconnus ignorés, règle d'évolution
  du contrat §6) : `meta` (`api_version`, `rules_version`, `data_versions`, mode), `status`,
  `points[]` (`d_m`, `index`, `origin`, `lat`, `lon`, `ele`, `ele_smoothed`, `ele_method`,
  `gain_cum_m`), `segments[]` (`from_m`, `to_m`, `structure`, `surface`, `way_kind`, `matched`),
  `summary` (`length_m`, `gain_m`, `loss_m`, `structures[]`, `terrain_m`), `quality` (`terrain[]`,
  `warnings[]`, `structure_correction`).
- Entrée : `polyline` précision 6 (on a déjà `Polyline6Encoder`), `sampling.mode =
  input_with_breakpoints`, `elevation.smoothing_m = 150` (le lissage de gpx2web, §4.2).
- Erreurs RFC 9457 → `RouteDetailsErrors` : `503 data_unavailable` / `overloaded` / `504` →
  transitoires (retry de la file) ; `413` → bug de découpage (log error, pas de retry) ; `422
  out_of_coverage` → définitif ; `400` → bug (log error).
- Config :

  ```properties
  quarkus.rest-client.osm-route-details.url=${OSM_ROUTE_DETAILS_URL:http://osm-route-details:8080}
  %dev.quarkus.rest-client.osm-route-details.url=${OSM_ROUTE_DETAILS_URL:http://localhost:18003}
  quarkus.rest-client.osm-route-details.connect-timeout=3000
  # fast : quelques secondes ; full : jusqu'à 90 s côté service (budget publié), d'où deux timeouts
  pedalons.route-details.fast-timeout=PT15S
  pedalons.route-details.full-timeout=PT100S
  ```

  Le timeout `full` dépasse le budget de 90 s du service, comme le contrat le demande au proxy. Un
  appel `full` ne tourne **que** dans le worker (jamais dans une requête HTTP).

### 3.1 Découpage (> 200 km, > 16 000 points)

Bornes lues dans `/v1/capabilities` au démarrage (repli : 200 km, 16 000 points). On reprend le
découpage de `TraceSurfaceComputer` (cœur de 188 km, recouvrement de 500 m de chaque côté, amincissement
à ≥ 5 m de la ligne brute), repris dans `infrastructure/routedetails/RouteSlicer` (phase A ;
`TraceSurfaceComputer` garde sa copie jusqu'à la phase E), bornes dérivées de `/v1/capabilities`,
cœurs bornés sur un point envoyé, partagé par deux tranches voisines. Recollage
(`RouteDetailsStitcher`, ancré sur ce point : `d_m` et cumuls de chaque tranche décalés de ce que
les cœurs précédents ont ajouté) :

- altitude et points : chaque tranche garde son cœur ; le recouvrement absorbe les effets de bord
  (un ouvrage coupé reste corrigé, contrat §5.3) ;
- D+ : somme des `gain_cum_m` aux bornes des cœurs (pas exactement le D+ d'un seul appel, écart
  assumé, le contrat le dit) ;
- segments : bornes du cœur, puis `SurfaceRanges.normalize` comme aujourd'hui.

Les tranches d'un même parcours partent **en séquence** (pas de rafale sur la file `full` du
service).

## 4. Profil d'élévation

### 4.1 `GpxPipeline` derrière une interface

`GpxPipeline` garde sa signature publique (`process`, `processReported`, `processWithClimb`,
`climbs`) : aucun appelant ne change (planificateur, import, `computeGpx`, rattrapage, migration).
Seul `processDense` change :

| Étape | Aujourd'hui (vcyclist) | Demain |
|---|---|---|
| Terrain + ouvrages | `ElevationCorrectionJvm.fixAndCorrectBlocking` sur provider FAST/HD | un appel `RouteDetailsClient` (mode `fast` / `full`, `sections: [elevation, summary]` en FAST) |
| Rééchantillonnage | pas ≤ 10 m (`GpxLimits.RESAMPLING_STEP_METERS`) | aucun : points d'entrée + points de rupture du service |
| Lissage 150 m | `ElevationStepJvm.smoothElevation` | `ele_smoothed` du service (`smoothing_m = 150`) |
| D+ | `ElevationGainJvm.annotate` (bande morte, avant DP) | `summary.gain_m` / `gain_cum_m` du service, reportés sur le `Path` |
| Douglas-Peucker 3/3 | vcyclist | vcyclist, inchangé |
| Montées | `ClimbDetectorJvm` | vcyclist, inchangé, sur le chemin simplifié |
| `fallbackAfterErrorKm` | `TerrainProvenance` | somme des `quality.terrain[]` où `fallback_after_error`, plus les plages `elevation_missing` ; toute la longueur si l'appel échoue |

Le `Path` passé au DP est construit à partir des points de la réponse (`lat`/`lon` : ceux du client
pour `origin: input` via `index`, ceux du service pour `inserted`), altitude `ele_smoothed`. Les
points de rupture (sommets, extrémités d'ouvrage) entrent donc dans le DP, qui a toutes les chances
de les garder.

**Échec en FAST** (planificateur, enregistrement) : comportement actuel — altitudes d'origine,
`elevationFallback = true`, le reste du pipeline tourne. Un service en panne ne bloque jamais un
enregistrement.

### 4.2 Ce qui change dans les chiffres → `GpxPipeline.VERSION = 3`

Le D+ n'est plus celui de `ElevationGainJvm` mais celui du preset `dem` du service, et les ouvrages
sont mieux corrigés : les chiffres bougent. `VERSION` passe à 3 : la migration biketeam rejoue chaque
parcours une fois (empreinte `@p3`, `API-107`), comme lors du passage à la v2. Les parcours Pédalons
existants sont **tous recalculés** en HD par le backfill (§6, décision D2) : la décision D1
d'`API-131` (« parcours v1 laissés en l'état ») est levée. Chaque parcours et aperçu porte désormais
la version du pipeline qui a calculé son profil (`elevation_pipeline`, §7), écrite à chaque
écriture HD.

Bancs à refaire avant la bascule (§8) : écart de D+ v2 → v3 sur un échantillon de parcours réels,
pour l'annoncer dans les notes de version si besoin.

### 4.3 FAST et HD

- `saveQuality()` inchangé : FAST quand `async-hd` est actif.
- Le rattrapage HD (`ElevationRefreshWorker`) appelle le mode `full` avec **toutes les sections** :
  la même réponse sert au profil (§4.1) et au revêtement (§5). Critère de réussite : `status:
  complete` et aucune plage `fallback_after_error` (même règle qu'`API-131`) ; sinon
  `ElevationUnavailableException` et backoff, profil FAST gardé. Le revêtement d'une réponse
  `complete` avec repli Mapterhorn est quand même écrit (voir §5.2).

## 5. Revêtement

### 5.1 Une seule file

`surface_refresh` cesse d'être alimentée : chaque enregistrement qui demandait un revêtement demande
déjà un rattrapage HD (`elevation_refresh`). Le worker HD écrit profil **et** revêtement dans la même
transaction d'écriture (`applyRecompute` / écriture de l'aperçu), sur le même `source_revision`.

Conséquences :

- `pedalons.surface.enabled=false` → le worker HD demande `sections: [elevation, summary]` et
  n'écrit pas de revêtement (e2e, comme aujourd'hui).
- `async-hd.enabled=false` (HD synchrone à l'enregistrement, interrupteur de secours) : l'appel
  `full` a lieu dans la requête HTTP, et le revêtement de la même réponse est écrit à
  l'enregistrement. Rien n'est mis en file.
- Aperçu promu en parcours : les documents copiés comme aujourd'hui (`storeOrRequestSurfaces`).

### 5.2 Conversion vers `TrackSurfaceDocument`

`TrackSurfaceDocument` version 2 : `surfaces` `[from, to, code]` où `code` est la valeur du service
(`surface.detail` si présent, sinon `surface.class`), plus `way_kind`, `structure` et `matched` dans
`ways` (au lieu de `use` / `cycle_lane` Valhalla). `osmChangeset` → `dataVersions` (`meta`).
Version 1 relue telle quelle : les parcours déjà traités par osm-surface ne sont pas recalculés pour
ça.

Plus de `TrackAxisMapping` sur ce chemin : les `d_m` de la réponse sont l'axe dont sont tirés les
`track_points` HD (§4.1), donc les plages tombent déjà sur l'axe stocké (au facteur d'échelle près,
`doc.distance`, comme aujourd'hui). Comme tout parcours est recalculé (§6), il n'existe pas
d'écriture « revêtement seul » : `TrackAxisMapping` ne sert plus qu'à relire les documents v1 tant
que le backfill ne les a pas remplacés, puis part au ménage (phase E).

Hors réseau du planificateur (morceaux `DIRECT`) : `SurfaceRanges.overlay` inchangé.

Projection vers `TrackSurface` (le contrat d'API **ne change pas**, ni web ni mobile) :

| Service | `TrackSurface` |
|---|---|
| `detail` `asphalt`, `concrete`, `paving_stones`, `wood` | `PAVED` |
| `detail` `sett`, `cobblestone` | `PAVED_ROUGH` |
| `detail` `compacted`, `fine_gravel`, `gravel` | `GRAVEL` |
| `detail` `dirt`, `sand`, `grass` | `DIRT` |
| `detail` `rock` | `PATH` |
| sans `detail` (ou `detail` inconnu), `class: paved` | `PAVED` |
| sans `detail`, `class: unpaved`, `way_kind` `path` / `footway` / `steps` | `PATH` |
| sans `detail`, `class: unpaved`, autre `way_kind` (`track`…) | `GRAVEL` |
| `class: unknown`, ou `matched: false` sans typologie | `UNKNOWN` |
| morceau `DIRECT` du planificateur | `OFF_NETWORK` |

Proche de ce qu'osm-surface rendait par la table Valhalla (`paving_stones` revêtu, `sett` et
`cobblestone` dégradés). Différence assumée : sur un non revêtu sans tag fin (`tracktype` ou déduit),
osm-surface pouvait rendre `dirt` ; ici c'est `GRAVEL` (ou `PATH` sur un sentier), `DIRT` ne vient
plus que d'un tag. Un parcours sur voie interdite au vélo (`matched: false` avec typologie, api 1.1)
garde le revêtement de cette voie. `wood` (passerelles, platelages, le plus souvent courts) compte
comme revêtu bien que le service le classe `unpaved`. Table validée le 6 novembre 2026 (D6, §9). Elle vit dans un seul fichier
(`service/surface/RouteDetailsSurfaces`), avec son test.

### 5.3 Costing

osm-route-details v1 suppose un tracé vélo (pas de paramètre de mode). Les profils `pedestrian` et
`auto` de `costingOf(profile)` sont appariés comme du vélo : une voie interdite au vélo reste
`matched: false` avec la typologie de la voie (api 1.1, `bicycle_forbidden`), donc le revêtement
reste juste ; seul l'appariement des rues piétonnes peut différer. Accepté (décision D3, §9) ; le paramètre
de mode V2 du service le réglera.

## 6. Backfill : tout recalculer (décision D2)

`SurfaceBackfill` devient `RouteDetailsBackfill`, le backfill de la file unique. Toutes les 5 min,
sous verrou consultatif, il met en file (`backfill = true`) les parcours puis les aperçus dont
`elevation_pipeline` est nul ou inférieur à `GpxPipeline.VERSION`, les plus récents d'abord, sous le
plafond horaire et la fenêtre actuels (`per-hour`, une tranche de 188 km = un appel). Le worker les
traite comme un rattrapage HD ordinaire (`recomputeHd`, depuis l'`original.gpx` stocké) : profil,
D+, montées, GPX filtré, FIT, chiffres du parcours, distances des points de passage **et**
revêtement, en une écriture. Priorité stricte : demandes normales, puis backfill.

Ce que ça implique, accepté avec D2 :

- les D+ affichés changent sous les yeux des membres (bancs du §8 pour en mesurer l'ampleur, à
  annoncer dans les notes de version) ;
- les heures de fin des sorties sont rafraîchies si la distance bouge (comportement actuel du
  rattrapage) ;
- les parcours envoyés aux GPS sont repoussés une fois (`API-120`, comme D4 d'`API-131`) ;
- les parcours d'avant `API-104` (pipeline v1) sont recalculés aussi ;
- débit : un appel `full` à froid sur l'IGN dure ~17 s pour 140 km, le worker en traite un à la
  fois (budget de 60 s par tick de 30 s). `per-hour` borne la charge ; la durée totale du
  rattrapage se calcule au déploiement (`OPS-58`) d'après le nombre de parcours et leur longueur.
  Le service étant unique (D5), staging et prod se partagent son budget IGN : ne pas lancer le
  backfill des deux en même temps (staging d'abord, `per-hour` bas, puis prod).

Échec définitif (5 tentatives) : le parcours garde son profil et son revêtement d'avant, et sa
version reste < 3 ; le retry admin existant (`POST /api/admin/elevation-refresh/retry`) le remet en
file. `raw_track_resurface` (`API-149`) devient inutile : le recalcul part de la ligne brute de
l'original.

## 7. Base de données (`V83`, compatible avec la version précédente)

- `team_entities.elevation_pipeline smallint` et `gpx_previews.elevation_pipeline smallint`,
  nullables (nul = calculé avant cette version, donc à recalculer) ; index partiel des parcours à
  rattraper.
- `elevation_refresh` : `backfill boolean not null default false`, index partiel du backfill comme
  `V77`.
- `surface_refresh` : **gardée** dans cette version (le backend précédent la draine encore pendant
  le déploiement start-first). Le nouveau backend ne l'alimente plus et ne la draine pas : ses cibles
  sont toutes reprises par le backfill. Suppression de la table, et de `raw_track_resurface`, dans
  une migration ultérieure (`V84+`, version suivante).

Pas de changement de contrat d'API attendu ; s'il en faut un (nouvelle valeur d'enum, crédit), bump
de `pedalons.api.version` et skill `contract-first-api`.

## 8. Tests (hors réseau, comme D7 d'`API-131`)

- `FakeRouteDetailsClient`, servi par `FakeRouteDetailsGateway` (un `@Mock` qui sous-classe
  `RouteDetailsGateway` et surcharge `client(profil)` : la passerelle construit elle-même ses deux
  clients REST, un `@Mock @RestClient` ne serait jamais utilisé et les tests ouvriraient de vraies
  connexions), remplace `FakeElevationProducer` : altitude plate
  100 m en `fast`, 200 m en `full` (les tests distinguent déjà les tiers ainsi), segments `paved`
  sur toute la longueur ; interrupteurs `failFull`, `partial`, `fallbackAfterError`.
- Tests purs : conversion réponse → `Path` (points insérés, indices), recollage des tranches,
  `gain_cum_m` → `climb[]`, projection `TrackSurface`, document v1 relu.
- `ElevationRefreshTest` / `GpxPreviewElevationRefreshTest` : une seule passe écrit profil et
  revêtement et la version du pipeline ; le backfill ne met en file que les cibles < `VERSION`.
- `GpxPipelineTest` réécrit sur le client factice ; `RouteQueryCountTest` inchangé.
- Fixture réelle : une réponse `full` enregistrée (Nantes, un pont + un tunnel) en ressource de
  test, pour figer le parsing.
- Banc manuel (pas en CI) : 30 parcours réels, D+ v2 vs v3, revêtement osm-surface vs
  osm-route-details, temps `fast` à froid et à chaud.

Rappel : les tests backend sont lancés par l'utilisateur.

## 9. Décisions

Prises avec l'utilisateur le 6 novembre 2026 :

| # | Question | Décision |
|---|---|---|
| D1 | Revêtement fin : `paved`/`unpaved` + `way_kind`, ou demander `surface.detail` au service ? | **Demander `surface.detail`** (§2.3) ; l'enum `TrackSurface` de Pédalons ne change pas |
| D2 | Recalculer les parcours existants (v2, et v1 d'avant `API-104`) ? | **Tout recalculer en HD** : profil, D+, montées, fichiers et revêtement (§6) ; lève D1 d'`API-131` |
| D3 | Profils piéton et voiture | **Appariés comme du vélo**, en attendant le mode V2 du service (§5.3) |
| D4 | vcyclist en repli si osm-route-details est en panne ? | **Non, une seule source** : FAST en échec garde les altitudes d'origine (`elevationFallback`), le HD réessaie ; providers et `DemTileStore` supprimés (phase E) |
| D6 | Table `detail` → `TrackSurface` | **Validée** (§5.2) : non revêtu sans détail hors sentiers → `GRAVEL` ; `paving_stones` → `PAVED` ; `sand`, `grass` → `DIRT` ; `wood` → `PAVED`, `rock` → `PATH` |
| D5 | Un service par environnement (staging, prod) ou un seul ? | **Un seul, dans la pile partagée**, comme osm-surface : caches IGN, Mapterhorn et VersaTiles communs ; staging et prod partagent ses files d'admission (`fast` et `full`) |

## 10. Phases

| Phase | Contenu | Livrable |
|---|---|---|
| A — **faite le 6 novembre 2026** | Client, DTO, erreurs, découpage, client factice, fixture ; service dans `docker-compose.shared.yml` et `.local.yml` | aucun comportement changé |
| B | `GpxPipeline` sur le service (FAST et HD), `VERSION = 3` ; vcyclist n'est plus appelé pour le terrain | profil par osm-route-details |
| C | Le worker HD écrit le revêtement (`TrackSurfaceDocument` v2, projection sur `surface.detail`) ; `surface_refresh` n'est plus alimentée, `V83` — api ≥ 1.6 | une seule file |
| D | `RouteDetailsBackfill` : recalcul HD de tous les parcours et aperçus < `VERSION` | osm-surface plus appelé ; tout le parc en v3 |
| E | Ménage : `ElevationTier`, providers de `VcyclistProducer`, `DemTileStore` (+ `OPS-55` : réglage `tile-cache-size` retiré), `TraceAttributesClient` et le reste d'osm-surface, service osm-surface de la pile partagée (`OPS-58`), crédit « Altitude : IGN LiDAR HD, Mapterhorn » complété d'OSM (attribution du service), `docs/OPERATIONS.md` | — |
| F (version suivante) | `V84` : suppression de `surface_refresh` et `raw_track_resurface` | — |

## 11. Déploiement (`OPS-58`)

- `docker-compose.shared.yml` : service `osm-route-details` (`ghcr.io/glandais/osm-route-details:1.6.0`,
  tag figé), réseau `pedalons-shared`, volume de cache (IGN, Mapterhorn, VersaTiles ;
  régénérable), limite mémoire à mesurer. VersaTiles en fichier local en production (contrat §7) :
  taille de l'extrait France à prévoir sur le disque du serveur.
- `docker-compose.local.yml` : port `127.0.0.1:18003`.
- `.env.example` : `OSM_ROUTE_DETAILS_URL`. La pile e2e : client factice côté tests, service absent
  (les e2e ne doivent pas dépendre de l'IGN).
- Le cache DEM du backend (`./data/cache/mapterhorn`, `ign…`) devient inutile après la phase E ; le
  cache carto des vignettes reste.
- osm-surface retiré de la pile partagée seulement quand plus aucun backend ne l'appelle (phase D
  déployée, `surface_refresh` vide).
- Avant la phase D : estimer la durée du recalcul complet (nombre de parcours × longueur, plafond
  `per-hour`) et la charge IGN, et prévenir les équipes que les D+ vont bouger.
