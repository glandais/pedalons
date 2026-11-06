# Profil et revêtement par osm-route-details

Écrit le 5 novembre 2026. **État : phases A, B, C et D faites (§10), le recalcul du parc reste à allumer par environnement, phases E et F à venir.** Ledger `API-150` (backend),
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
  appel `full` ne tourne que dans le worker, sauf `pedalons.elevation.async-hd.enabled=false` : il
  tourne alors dans la requête. Ces timeouts bornent **un appel**, donc une tranche : un appel `fast`
  resté sans réponse suspend les suivants 30 s (`RouteDetailsGateway`), pour qu'une boucle sur des
  lignes ou des traces ne cumule pas un timeout par élément.

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
| Terrain + ouvrages | `ElevationCorrectionJvm.fixAndCorrectBlocking` sur provider FAST/HD | un appel `RouteDetailsGateway.details` (mode `fast` / `full`, `sections: [elevation, summary]`, plus `typology` pour un calcul `full` qui écrit le revêtement, §5.1) ; `accept_partial` en `fast` seulement |
| Rééchantillonnage | pas ≤ 10 m (`GpxLimits.RESAMPLING_STEP_METERS`) | densification à ≤ 50 m avant l'envoi (`GpxPipeline.SENT_MAX_GAP_M`), jamais de point source retiré ; la réponse rend ces points plus les points de rupture du service |
| Lissage 150 m | `ElevationStepJvm.smoothElevation` | `ele_smoothed` du service (`smoothing_m = 150`) |
| D+ et D- | `ElevationGainJvm.annotate` (bande morte, avant DP) | `gain_cum_m` et `loss_cum_m` du service, reportés sur le `Path` : les cumuls plutôt que `summary`, que le contrat ne garantit qu'au centimètre, pour que le dernier point de `climb[]` égale exactement le D+ affiché |
| Douglas-Peucker 3/3 | vcyclist | vcyclist, inchangé |
| Montées | `ClimbDetectorJvm` | vcyclist, inchangé, sur le chemin simplifié |
| `fallbackAfterErrorKm` | `TerrainProvenance` | somme des `quality.terrain[]` où `fallback_after_error`, plus les plages `elevation_unavailable` (source en panne) ; toute la longueur si l'appel échoue. `elevation_missing` n'y entre pas : hors de l'emprise des données, l'absence est définitive, un nouvel essai n'y changerait rien (même règle que le `noDataKm` de vcyclist). Ces trous sont interpolés et journalisés |

Le `Path` passé au DP est construit à partir des points de la réponse (`lat`/`lon` : ceux du client
pour `origin: input` via `index`, ceux du service pour `inserted`), altitude `ele_smoothed`. Les
points de rupture (sommets, extrémités d'ouvrage) entrent donc dans le DP, qui a toutes les chances
de les garder.

**Pourquoi densifier.** Le service ne rend que les points d'entrée et ses points de rupture (DP
vertical de 2 m, 20 points insérés par km au plus) : une ligne droite de deux points n'aurait
d'`ele_smoothed` qu'à ces endroits. 50 m, c'est `smoothing_m / 3`, plus fin que ce que garde le DP 3/3.
Seuls les trous de plus de 50 m reçoivent des points, sur le segment en lat/lon : une trace déjà dense
n'en consomme aucun. La passerelle reste seule à éclaircir (points à moins de 5 m).

**Échec en FAST** (planificateur, enregistrement) : comportement actuel — altitudes d'origine, lissage
et D+ par vcyclist sur ces altitudes, `elevationFallback = true`, le reste du pipeline tourne. Un
service en panne ne bloque jamais un enregistrement. Une trace de moins de 2 points ou de moins de
1 m ne part pas au service (il répondrait 400) : son altitude est lue au premier point, sur une ligne
de 10 m envoyée à sa place, et appliquée à plat — une source du planificateur porte 0 m. Si l'appel
échoue : altitudes d'origine, repli signalé.

### 4.2 Ce qui change dans les chiffres → `GpxPipeline.VERSION = 3`

Le D+ n'est plus celui de `ElevationGainJvm` mais celui du preset `dem` du service, et les ouvrages
sont mieux corrigés : les chiffres bougent. `VERSION` passe à 3 : la migration biketeam rejoue chaque
parcours une fois (empreinte `@p3`, `API-107`), comme lors du passage à la v2. Les parcours Pédalons
existants sont **tous recalculés** en HD par le backfill (§6, décision D2) : la décision D1
d'`API-131` (« parcours v1 laissés en l'état ») est levée. Chaque parcours et aperçu porte désormais
la version du pipeline qui a calculé son profil (`elevation_pipeline`, §7), écrite à chaque
écriture HD revêtement allumé.

Bancs à refaire avant la bascule (§8) : écart de D+ v2 → v3 sur un échantillon de parcours réels,
pour l'annoncer dans les notes de version si besoin.

### 4.3 FAST et HD

- `saveQuality()` inchangé : FAST quand `async-hd` est actif.
- Le rattrapage HD (`ElevationRefreshWorker`) appelle le mode `full` ; à partir de la phase C, avec
  **toutes les sections** : la même réponse sert au profil (§4.1) et au revêtement (§5). Critère de
  réussite : `fallbackAfterErrorKm` nul, donc aucune plage `fallback_after_error` (même règle
  qu'`API-131`) ; sinon `ElevationUnavailableException` et backoff, profil FAST gardé. Sans
  `accept_partial` en `full`, une source en panne arrive en 503 et réessaie ; une réponse `partial`
  (données absentes, définitivement) est écrite, trous interpolés. Le revêtement d'une réponse
  `complete` avec repli Mapterhorn est quand même écrit (voir §5.2).

## 5. Revêtement

### 5.1 Une seule file

Plus aucun enregistrement n'alimente `surface_refresh` : chaque enregistrement qui demandait un
revêtement demande déjà un rattrapage HD (`elevation_refresh`). Le worker HD écrit profil **et**
revêtement dans la même transaction d'écriture (`applyRecompute` / écriture de l'aperçu), sur le même
`source_revision`, et retire la demande `surface_refresh` éventuelle de la cible.

Depuis la phase D, plus rien n'alimente `surface_refresh` : `SurfaceBackfill` a disparu.
`SurfaceRefreshWorker`, `SurfaceRefreshService`, `TraceSurfaceComputer` et `TraceAttributesClient`
restent jusqu'à la phase E, sans autre rôle que drainer ce que la version précédente a laissé : une
demande restante à moins de 5 tentatives fait lire `PENDING` à l'API, il faut donc la servir, et la
version précédente peut encore en écrire pendant la minute du déploiement. File vide, le worker lit
la table et n'appelle rien. La demande est retirée sous le verrou de la cible avant l'écriture
(`deleteIfRevision`) : si le rattrapage HD est passé pendant le calcul, le document v1 n'est pas
écrit par-dessus le v2.

Conséquences :

- `pedalons.surface.enabled=false` → le worker HD demande `sections: [elevation, summary]` et
  n'écrit pas de revêtement (e2e, comme aujourd'hui). `elevation_pipeline` reste alors nul : le
  tampon veut dire « profil calculé par ce pipeline, revêtement demandé », et un parcours recalculé
  ainsi redevient candidat du backfill une fois l'interrupteur rallumé (§6).
- `async-hd.enabled=false` (HD synchrone à l'enregistrement, interrupteur de secours) : l'appel
  `full` a lieu dans la requête HTTP, et le revêtement de la même réponse est écrit à
  l'enregistrement. Rien n'est mis en file : un appel en échec ne laisse ni document ni demande, et
  `elevation_pipeline` reste nul (repris par le backfill de la phase D, une fois allumé).
- Aperçu promu en parcours : les documents copiés comme aujourd'hui (`storeCopiedSurfaces`), seule
  la demande de revêtement a disparu.
- `surfaceState` reste `PENDING` tant que la cible est en `elevation_state = PENDING`, ou qu'il reste
  une demande `surface_refresh` : sans requête de plus pour la colonne, donc sans effet sur les
  comptages de `RouteQueryCountTest`. Rattrapage abandonné : pas de document, l'API ne dit rien, comme
  après cinq échecs jusqu'ici.

### 5.2 Conversion vers `TrackSurfaceDocument`

`TrackSurfaceDocument` version 2 (`VERSION_ROUTE_DETAILS`) :

- `surfaces` `[from, to, code]` où `code` est la **classe projetée** en minuscules (table ci-dessous,
  `TrackSurface.code()`), pas la valeur du service. La version précédente lit ces codes tels quels :
  un document v2 reste juste pendant la minute du déploiement start-first et après un retour arrière,
  alors que `asphalt`, `unpaved` ou `sett` y deviendraient `UNKNOWN`. Le chemin de lecture ne change
  pas (v1 et v2 se lisent pareil), et l'absorption des morceaux de moins de 20 m travaille sur ce que
  les clients dessinent.
- `ways` `[from, to, way_kind, null, structure, matched, class, detail]` : les valeurs brutes du
  service, en remplacement de `use` / `cycle_lane` Valhalla ; éléments de fin omis quand ils sont
  nuls. Le lecteur précédent y voit `way_kind` à la place de `use`. Changer la table D6 revient donc à
  reprojeter depuis `ways`, sans appel au service.
- `osmChangeset` → `dataVersions` (`meta.data_versions`, celui de la première tranche sur un parcours
  découpé) ; `costing` vaut toujours `bicycle` (§5.3).
- Un document `unavailable` porte la raison `too-short` (trace trop courte) ou `no-typology` (rien
  que du `UNKNOWN` après superposition du hors-réseau : une trace entièrement `DIRECT` reste donc
  valable).

Version 1 relue telle quelle : les parcours déjà traités par osm-surface ne sont pas recalculés pour
ça.

Plus de `TrackAxisMapping` sur ce chemin (il reste à `TraceSurfaceComputer`, et au planificateur par
`RawShapes`), mais les `d_m` de la réponse ne sont pas l'axe stocké : `track_points.dist` est recalculé
sur les seuls points gardés par le DP, plus court et inégalement (le bruit GPS et les arrêts
disparaissent), et un simple facteur d'échelle décalerait chaque borne après un arrêt. Les bornes
passent donc par des ancres : pour chaque point gardé, le couple (`d_m` du point, distance stockée),
avec interpolation par morceaux, bornée aux extrémités. `doc.distance` vaut alors la longueur
stockée.

**Écriture « revêtement seul »**, une seule : la réponse `complete` avec repli (§4.3), où le profil
reste en FAST et réessaie. Quand **toutes** les traces ont une réponse `complete`, le revêtement est
écrit seul (`writeSurfaceOnly`, `writePreviewSurfaceOnly`) sur le `source_revision` lu, sans toucher
à l'état d'altitude, à `elevation_pipeline`, aux fichiers ni aux points, puis la tentative compte
comme un échec ; réécrit à chaque essai. Une réponse `partial` avec repli n'écrit rien. Les bornes
sont sur l'axe HD et se recalent à la lecture sur la trace FAST, à quelques mètres près.

Hors réseau du planificateur (morceaux `DIRECT`) : `SurfaceRanges.overlay` inchangé, avant la
normalisation, comme `TraceSurfaceComputer`. Le rattrapage relit l'état du planificateur, s'il porte
sur la révision calculée et sur une seule trace.

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
de mode V2 du service le réglera. `costingOf` ne sert plus sur ce chemin : un document v2 enregistre
toujours `bicycle`.

## 6. Backfill : tout recalculer (décision D2)

`SurfaceBackfill` devient `RouteDetailsBackfill` (`service/elevation/`), le backfill de la file
unique. **Il est éteint par défaut** (`pedalons.route-details.backfill.enabled`,
`ROUTE_DETAILS_BACKFILL_ENABLED`) : déployer ne lance jamais le recalcul du parc, on l'allume
environnement par environnement, staging d'abord, une fois le déploiement stabilisé. Pas de repli
sur `SURFACE_BACKFILL_*` : un hôte qui porte encore `SURFACE_BACKFILL_ENABLED=true` ne doit pas le
démarrer. Tant qu'il est éteint, une trace sans revêtement n'en reçoit pas et s'affiche comme
aujourd'hui.

Allumé, toutes les 5 min, sous verrou consultatif, il met en file (`elevation_refresh`,
`backfill = true`) les parcours puis les aperçus dont `elevation_pipeline` est nul ou inférieur à
`GpxPipeline.VERSION`, les plus récents d'abord, sous le plafond horaire (`per-hour`,
`ROUTE_DETAILS_BACKFILL_PER_HOUR`, 60 par défaut, une tranche de 188 km = un appel) et la fenêtre de
10 min. Il journalise à chaque passe ce qui reste (parcours, km, aperçus, abandons) et ne touche pas
à `elevation_state` : l'API continue de montrer le profil et le revêtement actuels, rien ne se lit
comme en attente. Le worker les traite comme un rattrapage HD ordinaire (`recomputeHd`, depuis
l'`original.gpx` stocké) : profil, D+, montées, GPX filtré, FIT, chiffres du parcours, distances des
points de passage **et** revêtement, en une écriture. Priorité stricte : demandes normales, puis
backfill ; un enregistrement qui rattrape une ligne de backfill la repasse en normale
(`backfill = false`). Le worker vide la file quel que soit l'interrupteur : l'éteindre arrête de
mettre en file, ce qui y est (10 min au plus) finit de passer.

Revêtement éteint (`pedalons.surface.enabled=false`), le backfill ne met rien en file : un recalcul
n'est pas tamponné (§5.1), une passe reprendrait sans fin les mêmes traces. Une seule ligne de
journal le signale. Rallumé, ces traces sont des candidates ordinaires, sans branche de requête en
plus.

Un parcours jamais recalculé reste valable : profil intact, document v1 toujours lu. Les
parcours sans trace ou sans original ne sont jamais candidats et restent tels quels. La migration
biketeam ne passe pas par là : ses parcours passent par un enregistrement normal, donc par une
demande normale du rattrapage HD (`leaveToBackfill` n'avait aucun appelant en production, il est
retiré).

Ce que ça implique, accepté avec D2 :

- les D+ affichés changent sous les yeux des membres (bancs du §8 pour en mesurer l'ampleur, à
  annoncer dans les notes de version) ;
- les heures de fin des sorties sont rafraîchies si la distance bouge (comportement actuel du
  rattrapage) ;
- les parcours envoyés aux GPS sont repoussés une fois (`API-120`, comme D4 d'`API-131`) ;
- les parcours d'avant `API-104` (pipeline v1) sont recalculés aussi ;
- débit : un appel `full` à froid sur l'IGN dure ~17 s pour 140 km, le worker en traite un à la
  fois (budget de 60 s par tick de 30 s), soit environ 200 appels par heure au plus. `per-hour`
  borne la charge (60 : un appel par minute, ce qui laisse de la place aux demandes normales) ; la
  durée totale se calcule avant d'allumer, d'après le nombre de parcours et leur longueur
  (requête dans `docs/OPERATIONS.md`, `OPS-58`). Le service étant unique (D5), staging et prod se
  partagent son budget IGN : ne pas lancer le backfill des deux en même temps (staging d'abord,
  `per-hour` bas, puis prod).

Échec définitif (5 tentatives) : le parcours garde son profil et son revêtement d'avant, et sa
version reste < 3. Sa ligne reste dans `elevation_refresh` avec son erreur et **il n'est plus remis
en file par le backfill** : toute ligne exclut sa cible, quelles que soient ses tentatives, sinon il
tournerait en boucle. Les seuls chemins de retour sont un enregistrement et le retry admin existant
(`POST /api/admin/elevation-refresh/retry`, à essayer d'abord en `dryRun`), qui voit désormais ces
lignes malgré un état `HD` ou nul : la ligne reste `backfill`, derrière les demandes normales, et
l'état de sa cible ne bouge pas. Il marche interrupteur éteint.

`raw_track_resurface` (`API-149`) devient inutile : le recalcul part de la ligne brute de
l'original. `pedalons.raw-backfill.resurface` est retiré et plus rien ne lit ni n'écrit la table,
gardée jusqu'à la phase F : la clé ne peut donc plus poser un document v1 sur un v2.

## 7. Base de données (`V83`, compatible avec la version précédente)

- `team_entities.elevation_pipeline smallint` et `gpx_previews.elevation_pipeline smallint`,
  nullables (nul = calculé avant cette version, profil FAST d'un enregistrement que le rattrapage
  n'a pas remplacé, ou profil HD calculé revêtement éteint, donc à recalculer) ; index partiel des parcours à rattraper. Un enregistrement
  FAST remet la colonne à nul : un rattrapage abandonné ne laisse pas sur une trace neuve la version
  de l'ancienne. Le backfill de la phase D saute donc toute cible qui a une ligne dans
  `elevation_refresh`, demande ouverte ou abandonnée.
- `elevation_refresh` : `backfill boolean not null default false`, index partiel du backfill comme
  `V77`.
- `surface_refresh` : **gardée** dans cette version (le backend précédent la draine encore pendant
  le déploiement start-first). Le nouveau backend ne l'alimente plus depuis la phase D, et
  continue de la drainer tant que `SurfaceRefreshWorker` existe (§5.1). Suppression de la table, et de
  `raw_track_resurface`, dans une migration ultérieure (`V84+`, version suivante).

Pas de changement de contrat d'API attendu ; s'il en faut un (nouvelle valeur d'enum, crédit), bump
de `pedalons.api.version` et skill `contract-first-api`.

## 8. Tests (hors réseau, comme D7 d'`API-131`)

- `FakeRouteDetailsClient`, servi par `FakeRouteDetailsGateway` (un `@Mock` qui sous-classe
  `RouteDetailsGateway` et surcharge `client(profil)` : la passerelle construit elle-même ses deux
  clients REST, un `@Mock @RestClient` ne serait jamais utilisé et les tests ouvriraient de vraies
  connexions), remplace `FakeElevationProducer` : altitude plate
  100 m en `fast`, 200 m en `full` (les tests distinguent déjà les tiers ainsi), segments `paved`
  sur toute la longueur ; interrupteurs `failFast`, `failFull`, `partial`, `fallbackAfterError`,
  `terrain` (relief donné par une fonction de `d_m`).
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
| B — **faite le 6 novembre 2026** | `GpxPipeline` sur le service (FAST et HD), `VERSION = 3` ; vcyclist n'est plus appelé pour le terrain, sauf lissage et D+ des altitudes d'origine quand l'appel échoue ; pile e2e dotée de son propre service | profil par osm-route-details |
| C — **faite le 6 novembre 2026** | Le worker HD écrit le revêtement (`TrackSurfaceDocument` v2, projection sur `surface.detail`) ; plus aucun enregistrement n'alimente `surface_refresh`, `V83` — api ≥ 1.6 | une seule file pour tout enregistrement ; `SurfaceBackfill` et osm-surface tournent encore jusqu'à la phase D |
| D — **faite le 6 novembre 2026** | `RouteDetailsBackfill` : recalcul HD de tous les parcours et aperçus < `VERSION`, éteint par défaut ; `surface_refresh` n'est plus que drainée ; `pedalons.raw-backfill.resurface` et `SURFACE_BACKFILL_*` retirés. Pas de migration | osm-surface plus appelé une fois `surface_refresh` vidée ; le parc passe en v3 quand le recalcul est allumé, environnement par environnement |
| E | Ménage : `ElevationTier`, providers de `VcyclistProducer`, `DemTileStore` (+ `OPS-55` : réglage `tile-cache-size` retiré), `TraceAttributesClient` et le reste d'osm-surface **côté backend**, crédit « Altitude : IGN LiDAR HD, Mapterhorn » complété d'OSM (attribution du service), `docs/OPERATIONS.md` | — |
| F (version suivante, après la bascule de prod) | `V84` : suppression de `surface_refresh` et `raw_track_resurface` ; service osm-surface et son volume retirés de la pile partagée (`OPS-58`) | — |

## 11. Déploiement (`OPS-58`)

- `docker-compose.shared.yml` : service `osm-route-details` (`ghcr.io/glandais/osm-route-details:1.6.0`,
  tag figé), réseau `pedalons-shared`, volume de cache (IGN, Mapterhorn, VersaTiles ;
  régénérable), limite mémoire à mesurer. VersaTiles en fichier local en production (contrat §7) :
  taille de l'extrait France à prévoir sur le disque du serveur.
- `docker-compose.local.yml` : port `127.0.0.1:18003`.
- `.env.example` : `OSM_ROUTE_DETAILS_URL`.
- Pile e2e : son propre service (`docker-compose.e2e.yml`), sur son seul réseau, sans port publié,
  caches à 64 Mo. Il n'y a pas de client factice possible dans les images e2e, et sans service le
  planificateur rendrait une ligne à 0 m. Pour ne pas dépendre de l'IGN, `.env.e2e` repousse le
  rattrapage HD de 24 h : une exécution ne fait que des appels `fast`. Le CI dépend donc de
  ghcr.io et des tuiles publiques lues par le service.
- Le cache DEM du backend (`./data/cache/mapterhorn`, `ign…`) devient inutile après la phase E ; le
  cache carto des vignettes reste.
- **Staging d'abord, prod ensuite (décision du 6 novembre 2026).** La pile partagée sert les deux
  environnements : pendant toute la période, elle doit faire tourner staging en nouvelle version et
  prod en ancienne. Elle ne fait donc qu'**ajouter** osm-route-details ; osm-surface (appelé par la
  prod) et le tileserver ne bougent pas, et le réseau `pedalons-shared` non plus. Ordre :
  `scripts/deploy.sh --shared` depuis `~/shared` sur un commit qui contient le service, puis
  staging, recette, puis prod. La suppression d'osm-surface de `docker-compose.shared.yml` est une
  étape à part (phase F), jamais dans le commit qui bascule un environnement : seulement quand
  prod tourne en nouvelle version et que plus aucun backend ne l'appelle (plus aucune ligne de `surface_refresh` à servir : requête de `docs/OPERATIONS.md`, la table elle-même garde les demandes abandonnées).
  Rien côté bases : chaque environnement a la sienne.
- Avant d'allumer `ROUTE_DETAILS_BACKFILL_ENABLED` (phase D, éteint par défaut) : estimer la durée
  du recalcul complet et la charge IGN avec la requête de `docs/OPERATIONS.md`, attendre que le
  déploiement soit stabilisé (la version précédente calcule sur vcyclist et laisse la version
  nulle), et prévenir les équipes que les D+ vont bouger. Staging d'abord, prod ensuite, jamais les
  deux en même temps.
