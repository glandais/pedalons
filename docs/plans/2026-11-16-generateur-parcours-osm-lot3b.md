# Générateur de parcours sur graphe OSM, lot 3b : le backend appelle le moteur, dépôt nocturne, retrait de la recherche Java

Lot 3b du plan [`2026-11-15-generateur-parcours-osm.md`](2026-11-15-generateur-parcours-osm.md) (§11, §12 quater et décisions du 16 novembre 2026, qui priment).
Entrée : le lot 3a d'osm-route-details, api **1.9** (`docs/design/technique/ord-loops-lot3a.md`, `…-lot3a-mesures.md` et `contract/openapi.json` de ce dépôt).
Remplace le générateur d'`API-198` ([`…-lot3.md`](archive/2026-11-13-generateur-boucles-equipe-lot3.md), [`…-lot4.md`](archive/2026-11-13-generateur-boucles-equipe-lot4.md)).

Écrit le 16 novembre 2026. Statut : **codé le 16 novembre 2026** (backend, site, configuration, registre : `API-206`) ; tests backend et e2e
**pas encore lancés**, rien de déployé (§16, §17). Contrat `14.15.0` → **`15.0.0`** (cassant ; version relue dans `application.properties` le 16
novembre 2026). Aucune migration (dernière : `V93`). Chemins relatifs à `backend/src/main/java/fr/pedalons/` sauf mention. Ni secret, ni identifiant, ni
coordonnée d'équipe réelle ici.

---

## 0. Décisions en un écran

| Question | Décision |
|---|---|
| Client | `java.net.http.HttpClient` en HTTP/1.1, sans redirection, connexion 3 s, classe `RouteGeneratorGateway` à côté de `RouteDetailsGateway` ; `Ord-Namespace-Key` et `Ord-Team` (TSID de l'équipe, `TsidUtils.toString`) **toujours** envoyés, même au curseur 1 |
| Délais | génération 10 s (budget du service 8 s, file comprise, + 2 s) ; état et effacement 10 s ; dépôt 16 min (budget dur du service 900 s, plus l'attente) |
| Ce qui ne bouge pas | droits (`PlannerAccess.check`), interrupteur `enabled`, fenêtre de 30 demandes par 15 min et par personne, aucun quota tiré |
| Garanties | vérifiées par le contrôleur du service ; le backend ne refait qu'un contrôle géométrique bon marché (§4) |
| Curseur | `discovery` ∈ [0, 1], défaut **0,25**, à la place de `familiarity` ; distance 10 à **200 km** |
| D+ | **calculé** : trois appels `fast` à `/v1/route-details` en parallèle, budget de 2,5 s, `null` au-delà (§5) |
| Surcouche | déposée **la nuit** (02:10 UTC) par `RouteGeneratorOverlayJob`, une équipe à la fois, verrou consultatif, empreinte comparée au `source_digest` ; jamais à la demande |
| À la main | `POST /api/admin/route-generator/overlays/refresh` (administration de la plateforme) : `dryRun`, `force`, `teamId` |
| Flux du dépôt | curseur JDBC (lots de 8) dans une transaction de lecture, une ligne NDJSON par trace dans un tuyau de 1 Mio lu par le client HTTP : mémoire indépendante de l'équipe |
| Secret | `ROUTE_GENERATOR_NAMESPACE_KEY`, sans défaut en `%prod`, `:?` dans `docker-compose.yml`, format vérifié au démarrage, jamais journalisé |
| Recherche Java | **retirée** : `service/route/generator/` (55 fichiers, 8 149 lignes), cache d'équipe, 27 fichiers de test, neuf clés, une section d'OPERATIONS |
| e2e | la pile e2e n'a pas de graphe : l'appel réel attend `GENERATOR_UNAVAILABLE`, les autres specs bouchonnent l'endpoint |

## 1. Le client du moteur

`infrastructure/routedetails/RouteGeneratorGateway` (`@ApplicationScoped`), sur `quarkus.rest-client.osm-route-details.url` (même service que l'altitude). Pas de
REST client déclaratif : en-têtes par appel, corps en flux, délais propres (même choix que `BiketeamExportClient`). Méthodes `generate`, `status`,
`deposit(teamId, digest, BodyWriter)`, `delete` ; records Jackson `snake_case` calqués sur le contrat 1.9 (`GenerateRequestV1`, `GenerateResponseV1`, `RouteV1`,
`OverlayStatusV1`, `DepositReportV1`), clés inconnues ignorées.

- **Bouchon, comme pour l'altitude** : tout passe par une couture package-private `Exchange exchange(Call)` (méthode, chemin, en-têtes, octets ou `BodyWriter`) ;
  `FakeRouteGeneratorGateway` (`@Mock`, sources de test) y répond par un moteur en mémoire au niveau du message HTTP. JSON, problèmes RFC 9457, en-têtes et
  cadrage NDJSON tournent en test comme en production, hors réseau.
- **Capacités** : `RouteDetailsCapabilities` gagne `generator` (`enabled`, `reason`, `graph.id`, `limits.distance_m_max`, `limits.deposit.max_document_bytes` et
  `max_tracks`, `overlay_ttl_days`, `ascent`), lu par `RouteDetailsGateway.capabilities()` (cache d'une heure). Une génération n'appelle pas un service connu sous
  l'api 1.9 ou éteint ; le travail nocturne et le déclencheur relisent sans cache.
- **Clé** : `NamespaceKey`, base64url sans remplissage, 32 octets exactement, `toString()` masqué. En `%prod`, une clé mal formée **arrête** le démarrage (le
  déploiement start-first garde l'ancien backend) ; en `%dev` sans clé, `GENERATOR_UNAVAILABLE` et un `WARN`.
- **Problèmes** : `RouteGeneratorProblems`, classe pure comme `RouteDetailsErrors` : `status`, `code`, `details.reason`, `details.state`, `Retry-After` ; un corps
  qui n'est pas un problème (page d'un proxy) se classe sur son statut seul.

## 2. Contrat (`15.0.0`)

Cassant, accepté (plan §12 quater, décision 4 : seul le propriétaire s'en sert, l'app ne l'appelle pas). Régénéré par le skill `contract-first-api`, clients web
et mobile compris ; rien d'autre ne change dans l'app (`MOB-154` reste dehors).

| DTO | Avant (`14.15.0`) | Après (`15.0.0`) |
|---|---|---|
| `RouteGeneratorRequest` | `familiarity` (0..1, défaut 0,5) | **retiré** ; `discovery` (Double, `@DecimalMin 0`, `@DecimalMax 1`, absent = 0,25) : « 0 : les seules routes de l'équipe ; 1 : découverte ; arrondi au centième par le moteur » |
| | `distanceKm` 10..300 ; `seed` Integer | 10..**200** (`distance_m_max`) ; `seed` `@PositiveOrZero` (u64 côté moteur) |
| `GeneratedRouteDto` | `familiarity` (requis) | **retiré** ; `teamShare` (double requis, 0..1) = `team_share` : part sur les routes de l'équipe, petits trous comblés compris |
| | `ascentM`, `descentM` (double requis) | `Double` nullable, non requis : absents quand le calcul n'a pas tenu dans son budget |
| | `polyline`, `distanceM`, `bearingDeviationDeg`, `unpavedShare`, `sharedM`, `crossings`, `bounds` | inchangés ; polyligne précision 6 (lat, lon) du moteur telle quelle, `sharedM` = `tail_m`, `bounds` calculé au contrôle (§4) |
| `RouteGeneratorResponse` | `network`, `familiarityFallback` | **retirés** ; `networkPreparedAt` (Instant nullable, `overlay.deposited_at`) ; `partialCoverage` (bool requis, `coverage = partial`) |
| Erreurs | `RouteGeneratorNetworkDto`, `RouteGeneratorNetworkDetails` (détails de `GENERATOR_NETWORK_TOO_SMALL`), `GENERATOR_NETWORK_TOO_LARGE` | **retirés** ; `ErrorCode` gagne `GENERATOR_OUT_OF_COVERAGE`, `GENERATOR_NETWORK_NOT_READY`, `GENERATOR_UNAVAILABLE` |
| Administration | — | `POST /api/admin/route-generator/overlays/refresh`, `{teamId?, force, dryRun}` → 200 (essai) ou 202 `{started, graphId?, items[]}`, item `{teamId, teamSlug, action DEPOSIT\|DELETE\|KEEP, reason ABSENT\|STALE\|CHANGED\|EXPIRING\|FORCED\|CURRENT\|TEAM_GONE\|PLANNER_OFF, state?, depositedAt?, expiresAt?}` |

Corps envoyé : `start` (demandé, sinon localisation de l'équipe, sinon 400 `VALIDATION` comme aujourd'hui), `end`, `bearing`, `distance_m` = km × 1000,
`ride_type` (`road` par défaut), `cursor` = `discovery`, `seed`. La description de `RouteGeneratorResource` est réécrite (plus de « chaque mètre sur une route de
l'équipe », plus de règle des 2 km).

## 3. Erreurs : chaque réponse du moteur

| Réponse du moteur | Code Pédalons, HTTP | Ancien code ? |
|---|---|---|
| 422 `out_of_coverage` | `GENERATOR_OUT_OF_COVERAGE`, 400 | nouveau |
| 422 `generation_failed`, `start_too_far`, `end_too_far`, `distance_too_short` | `GENERATOR_START_TOO_FAR`, `…_END_TOO_FAR`, `…_DISTANCE_TOO_SHORT`, 400 | gardés |
| 422 `generation_failed`, `network_too_small` | `GENERATOR_NETWORK_TOO_SMALL`, 400, sans détails | gardé |
| 422 `generation_failed`, `end_unreachable`, `no_way_back`, `tail_too_long`, `no_candidate`, `budget`, `checker_rejected`, raison inconnue | `GENERATOR_NO_ROUTE`, 400 (raison au journal et à la métrique) | gardé |
| 200 sans parcours, ou tous refusés au contrôle (§4) | `GENERATOR_NO_ROUTE`, 400 | gardé |
| 409 `overlay_required` (`state` `absent` ou `stale`) | `GENERATOR_NETWORK_NOT_READY`, 400 | nouveau |
| 503 `overloaded`, 504 `timeout`, délai de lecture dépassé | `ROUTE_GENERATOR_BUSY`, 503 | gardé |
| 503 `data_unavailable`, 502, connexion refusée, générateur éteint ou api < 1.9, clé absente en `%dev` | `GENERATOR_UNAVAILABLE`, 503 | nouveau |
| 400 `invalid_input`, 413, 415, 404, 500, 200 illisible (dérive du contrat) | `GENERATOR_UNAVAILABLE`, 503, et un `ERROR` | nouveau |

Les refus restent en 400 comme les autres `GENERATOR_*`. `RouteGeneratorErrors.of` : `switch` exhaustif sur un enum Java des dix raisons du contrat ; une raison
ajoutée côté Rust tombe dans « inconnue ».

## 4. Contrôle géométrique de chaque parcours

`GeneratedRouteSanity.check(request, RouteV1)`, pur. Un parcours refusé est retiré, compté (`pedalons.route_generator.dropped{check}`) et journalisé en `WARN`
(contrôle, équipe, tranche de distance, jamais de coordonnée). Le même passage calcule `bounds`, en temps linéaire.

1. la polyligne se décode (décodeur borné, aucune exception ne sort), 2 à 100 000 points, latitudes et longitudes finies et bornées ;
2. longueur géodésique L à ±10 % de la distance demandée, et `distance_m` du moteur à ±1 % de L ;
3. premier point à 2 km au plus du départ ; dernier à 2 km au plus de l'arrivée, ou à 50 m au plus du premier pour une boucle ;
4. aucun saut de plus de 10 km entre deux points (garde-fou contre un téléport ; aucune arête de la région n'est plus large que 5,6 km, lot 3a §4) ;
5. `team_share` et `unpaved_share` dans [0, 1], `tail_m` et `crossings` positifs ou nuls.

## 5. Le D+ des propositions : calculé avant la réponse

Chiffres cités, mesurés ailleurs : génération au curseur 0,25 en **255 ms au médian, 826 ms au P90** côté client (relevé du lot 3a, §3.3) ; `fast` sur 140 km en
**76 ms à chaud, 1,6 s à froid** (osm-route-details, `docs/design/02-contrat-interface.md` §3.2, 2026-11-05), pas ralenti par des générations en cours (relevé du
lot 3a, §4.1). Trois appels **en parallèle** coûtent à chaud à peu près le plus long (≈ 0,1 s), soit + 30 à 40 % au médian ; à froid, les trois lisent les mêmes
tuiles. Sans D+, la carte perd le critère qu'on lit en premier. **Choix : calculer.** `GeneratedRouteAscent` lance par parcours gardé un
`RouteDetailsGateway.details(lat, lon, fast, section summary)` (découpage existant compris) sur des fils virtuels et attend au plus `ascent-budget` (2,5 s) ; un
appel en échec, en pause (`FAST_PAUSE`) ou en retard laisse `ascentM` et `descentM` à `null` pour ce seul parcours. Valeur approchée que l'éditeur recalcule ;
compteur `pedalons.route_generator.ascent{outcome}` ; ni quota ni appel Stadia.

**Mesuré à la vérification finale** (16 novembre 2026, §16) : sur ce poste, binaire natif 1.9 (pas en conteneur), trois appels
`fast` en parallèle, section `summary`, sur les trois parcours qu'il venait de rendre : **1,04 s** (40 km, cache de tuiles vide),
**0,12 s** à chaud ; 100 km : 0,20 s à chaud (1,26 s au second passage « froid », cache déjà en partie rempli par le premier).
Les six appels ont tous rendu un D+. Le budget de 2,5 s tient donc même à froid ; le choix reste « calculer ».

## 6. La surcouche d'équipe, déposée la nuit

### 6.1 Qui, quand, quoi

`service/route/network/RouteGeneratorOverlayJob`, `@Scheduled(cron = "{pedalons.route-generator.overlay.cron}", timeZone = Crons.ZONE, concurrentExecution =
SKIP)`, défaut `0 10 2 * * ?` (avant les tâches de 03:00 à 04:50) ; `runOnce(now, options)` public, appelé par le cron, le déclencheur et les tests. Pas de
table : l'état est chez le service (`GET`), les équipes en base.

- **Une instance** : `pg_try_advisory_lock(hashtextextended('route-generator-overlays', 0))` sur une connexion à part, sans attendre (modèle de
  `RawTrackBackfill`) ; qui ne l'obtient pas saute la passe. En déploiement roulant, l'ancienne version (recherche Java) n'a pas ce travail, deux nouvelles se
  départagent au verrou, et le service refuse de toute façon un second dépôt du même environnement.
- **Idempotent** : empreinte égale → rien n'est envoyé ; un même flux donne la même surcouche (agrégation séquentielle) ; `DELETE` rend toujours 204 ; rien
  n'est réclamé ni écrit en base. **Préalables** : `overlay.enabled`, clé, capacités relues, api ≥ 1.9, `generator.enabled` ; sinon une ligne `INFO`.
- **Équipes** : une requête native, toutes les équipes de tous les domaines par identifiant croissant, `served` = non supprimée, planificateur actif, domaine actif.

| Équipe | État au service | Action |
|---|---|---|
| servie | `absent` / `stale` | dépôt (`ABSENT` / `STALE`) |
| servie | `ready`, `source_digest` différent | dépôt (`CHANGED`) |
| servie | `ready`, `expires_at` à moins de `refresh-before-expiry` (7 j ; durée de vie au service 14 j) | dépôt (`EXPIRING`) |
| servie | sinon | rien (`CURRENT`) ; avec `force`, dépôt (`FORCED`) |
| supprimée, planificateur coupé, domaine inactif | — | `DELETE` (`TEAM_GONE`, `PLANNER_OFF`) |

Une équipe servie sans parcours ou hors région (0 arête) est déposée quand même (0,02 s mesurées au lot 3a pour une équipe hors région).

### 6.2 L'empreinte

`OverlayDigest.of(Fingerprint)` : `p1-` suivi du SHA-256 hexadécimal des sept champs de `Fingerprint` et de `FORMAT` (1, monté quand ce que le backend envoie
change). `Fingerprint` et sa requête sont **gardés** du lot 3 : une instruction par équipe, agrégats sur colonnes étroites, `pg_column_size` sans détoaster.
Envoyée en `Ord-Source-Digest`, relue par `GET`, jamais journalisée. Limite : des sommes peuvent se compenser ; le redépôt à 7 jours borne l'écart à une semaine.

### 6.3 Le flux, de la base au service

- `repository/route/GeneratorSourceRepository` (renommé de `TeamNetworkRepository`) garde `fingerprint` et `streamTracks` : même requête native liée à l'équipe et
  au domaine, routes non supprimées, `order by t.id`, `getResultStream`, lots de **8** au lieu de 32, dans `QuarkusTransaction.requiringNew().timeout(1000)` (le
  défaut de 60 s couperait la plus grosse équipe : 45 s de dépôt mesurées).
- `OverlayNdjsonWriter` écrit par trace `{"type":"…","excluded":…,"network_edges":…}` puis `{"end":{"tracks":N}}`, une ligne chacune : `type` = `surface_type`
  (`MIXED` si nul), `excluded` = `excluded_from_generator`, `network_edges` = le texte `jsonb` tel quel s'il est **actuel** (règle du lot 1 : `v` =
  `NetworkEdgesDocument.VERSION`, `rev` = `file_id` de l'original, `status` `ok` ou `too_short`, lus par `NetworkEdgesHeader`, analyseur Jackson en flux qui saute
  `nodes` et `edges`), sinon `null`. Un document plus long que `max_document_bytes` part en `null`, avec un `WARN` qui cite l'identifiant de la trace.
- **Tuyau** `DepositBodyPipe` : file de 16 blocs de 64 Kio, lue par `BodyPublishers.ofInputStream` (`sendAsync`), écrite par le fil du travail dans la
  transaction. Chaque écriture attend au plus 1 s et regarde la réponse : si le service a déjà répondu (503, 409, 413) ou si l'échéance passe, l'écriture
  s'arrête, la transaction de lecture est annulée et la réponse décide. Pas de gzip (réseau local).
- **Mémoire** : 8 documents en tampon JDBC, un en cours, 1 Mio de tuyau : ≤ 40 Mo au pire (plus gros document relevé 4,2 Mo, borne 16 Mio), **quelle que soit
  l'équipe** (la plus grosse : 2 726 traces, 703 Mo de documents, jamais tenus à la fois).

### 6.4 Échecs, journaux, métriques

Aucun échec n'efface : l'ancienne surcouche sert jusqu'à son expiration, soit sept nuits de marge.

| Réponse au dépôt | Effet |
|---|---|
| 200 | `INFO` : équipe, raison, traces lues, exclues, illisibles, arêtes, km appariés, Mo envoyés, durée |
| 503 `overloaded` | attendre `Retry-After` (≤ 120 s), trois essais, puis équipe suivante (`WARN`) |
| 409 `deposit_in_progress`, 504 | équipe suivante (`WARN`) |
| 413, 400 | équipe suivante (`ERROR` : borne du service ou dérive du contrat) |
| 507, 503 `data_unavailable`, connexion impossible, base en échec | **fin de passe** (`WARN` ; `ERROR` pour 507) |

En fin de passe, une ligne `INFO` (équipes, déposées, effacées, gardées, en échec, durée, `graph_id`). Métriques :
`pedalons.route_generator.overlay.deposits{outcome}`, minuteurs `…overlay.deposit` et `…overlay.pass`, jauge `…overlay.last_success`. Jamais : clé, empreinte,
coordonnée, nom d'équipe ou de parcours.

### 6.5 Déclencheur à la main

`api/admin/AdminRouteGeneratorResource`, `@Admin` (administration de la plateforme, comme `AdminElevationRefreshResource`). `dryRun` : 200 et le tableau du §6.1
sans rien envoyer. Sinon 202 aussitôt, la passe tourne sur un fil géré sous le même verrou ; `started = false` si une passe tourne déjà sur cette instance. Pour
l'exploitation après un déploiement ou un nouveau graphe, un poste (Swagger UI en `%dev`), la pile e2e.

## 7. Configuration et déploiement

| Clé `pedalons.route-generator.…` | Défaut | Note |
|---|---|---|
| `enabled` (`ROUTE_GENERATOR_ENABLED`), `rate.max-per-window`, `rate.window-minutes` | `true`, 30, 15 | gardées |
| `namespace-key` (`ROUTE_GENERATOR_NAMESPACE_KEY`) | — | `%prod` `${ROUTE_GENERATOR_NAMESPACE_KEY}` sans défaut ; `%dev` `${…:}` ; `%test` vecteur synthétique `AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8` (octets 0x00 à 0x1f, comme la clé de test biketeam) |
| `generate-timeout`, `ascent-budget` | `PT10S`, `PT2.5S` | le premier remplace `time-budget` |
| `overlay.enabled` (`ROUTE_GENERATOR_OVERLAY_ENABLED`), `overlay.cron`, `overlay.deposit-timeout`, `overlay.refresh-before-expiry` | `true`, `0 10 2 * * ?`, `PT16M`, `P7D` | ordonnanceur déjà coupé en `%test` |

**Retirées** : `cache.max-weight-mb`, `cache.expire-after-access`, `cache.expire-after-write`, `cache.min-rebuild-interval`, `max-concurrent`, `permit-wait`,
`time-budget`, `build-wait`, `max-observations`, et `ROUTE_GENERATOR_CACHE_MB`, `ROUTE_GENERATOR_MAX_OBSERVATIONS` de `.env.example`. File et places de calcul
sont celles du service (503 → `ROUTE_GENERATOR_BUSY`).

- **`docker-compose.yml`**, `environment` du backend : `ROUTE_GENERATOR_NAMESPACE_KEY: ${ROUTE_GENERATOR_NAMESPACE_KEY:?set it in .env}`, commentaire à la manière
  d'`OPS-48` (sans lui, un backend sans clé démarre puis répond 503 à chaque génération).
- **`docker-compose.shared.yml`** : image `ghcr.io/glandais/osm-route-details:1.9.0` ; montage en lecture seule
  `./data/osm-route-details-graph:/var/lib/osm-route-details/graph:ro` ; `ORD_GENERATOR__GRAPH`, `__VIEW_ROAD`, `__VIEW_GRAVEL`, `__COVERAGE_POLY` =
  `/var/lib/osm-route-details/graph/${ORD_GRAPH_NAME:-absent}` suivi de `.ordg`, `.road.ordv`, `.gravel.ordv`, `.poly` (`ORD_GRAPH_NAME` dans `~/shared/.env`, que
  `deploy.sh --shared` lit déjà ; sans lui le générateur est éteint et l'altitude servie) ; surcouches sous le volume existant ; mémoire 2G inchangée (1,07 Gio au
  pire relevé hors conteneur, lot 3a §2.1). Commentaire : un graphe arrive sous un **nouveau nom**, jamais par-dessus un fichier projeté.
- **`docker-compose.local.yml`** : rien (hérite du partagé ; un poste pose un graphe dans `data/osm-route-details-graph/` et `ORD_GRAPH_NAME` dans son `.env`).
  **`.gitignore`** : `data/osm-route-details-graph/`.
- **`docker-compose.e2e.yml`** : `osm-route-details` reprend `volumes: !override` (le seul volume de cache). **La pile e2e ne fait pas tourner le moteur** : aucun
  graphe distribuable (125 + 65 + 92 Mo bâtis d'un PBF de 374 Mo), et les départs des specs sont hors région.
- **`scripts/dev-env.sh`** exporte aussi la clé. **`scripts/e2e.sh`**, dans `compose()` comme la clé Stadia : la clé du shell, sinon `.e2e/namespace-key`, sinon
  une clé tirée (`head -c32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'`, `umask 077`) et écrite là, jamais affichée ; `.env.e2e` n'en porte aucune.
- **`.env.example`**, **README** (« differ in five keys » → six) : la clé, sa recette, sa règle.
- **`docs/OPERATIONS.md`** : « The team route generator » devient **« The route generator »** : clés ; secret (recette, **un par environnement**, jamais dans
  `~/shared/.env`, sauvegardé avec le `.env`) ; rotation (`force` redépose tout dans le nouvel espace, l'ancien part par `DELETE /v1/generator/overlays` avec
  l'ancienne clé ou par la purge à 14 jours) ; graphe (bâti sur un poste, quatre fichiers 0444 sous un nouveau nom, `ORD_GRAPH_NAME`, `deploy.sh --shared`,
  déclencheur avec `force`, ancien dossier `graph-*` purgé après 48 h) ; première mise en service ; suivi (§6.4) ; `/metrics` 9090 jamais publié.

## 8. Le site (`WEB-179`)

- `hooks/filters/routeGeneratorFilters.ts` : `familiarity`/`f` → `discovery`/`dec`, défaut 0,25, arrondi au quart ; `GENERATOR_MAX_KM` 200.
  `lib/routeGenerator.ts` : `GeneratorParams.discovery`, envoyé dans la requête.
- `RouteGeneratorPanel.tsx` : « Fréquentation » devient **« Routes de l'équipe ↔ Découverte »**, cinq crans au pas de 0,25 (part d'équipe médiane relevée au lot
  3a §5 : 1,0 ; 0,80 ; 0,75 ; 0,68 ; 0,30) : « Uniquement les routes de l'équipe », « Surtout les routes de l'équipe » (défaut), « Équilibre », « Surtout de
  nouvelles routes », « Découverte ». Les avis `fallback` et `incomplete` partent ; viennent `networkPreparedAt` (« Routes de l'équipe prises en compte jusqu'au
  {{date}} : un parcours enregistré depuis comptera dès la nuit prochaine. ») et `partialCoverage` (« Une partie de la zone sort de la région couverte : les
  propositions y sont plus rares. »). `slow` : « La génération peut prendre quelques secondes. » Sous-titre : « Des propositions qui privilégient les routes de
  l'équipe et les relient par d'autres routes quand il le faut. »
- `GeneratedRouteCard.tsx` : la bande de familiarité devient « {{share}} sur les routes de l'équipe » ; sans `ascentM`, pas de ligne de D+. Type par défaut,
  lieux, rose des vents, carte, modale et passage à l'éditeur : inchangés.
- Erreurs, dans la table typée : `GENERATOR_OUT_OF_COVERAGE` « Le départ ou l'arrivée est hors de la région que couvre le générateur pour l'instant. » ;
  `GENERATOR_NETWORK_NOT_READY` « Les routes de l'équipe sont en préparation pour le générateur. Réessayez demain, ou poussez le curseur jusqu'à
  « Découverte ». » ; `GENERATOR_UNAVAILABLE` « Le générateur de parcours est indisponible pour le moment. Réessayez plus tard. » ; `startTooFar` et `endTooFar` :
  « Aucune route praticable près du départ (de l'arrivée) pour ce type de parcours. » ; `noRoute` et `networkTooSmall` suggèrent aussi « un peu plus de
  découverte ». « Réessayer » sur `UNAVAILABLE` et `BUSY`, pas sur `OUT_OF_COVERAGE` ni `NETWORK_NOT_READY`. Partent : `networkTooLarge`, `networkPending*`,
  `networkEmpty`, `familiarity.*`, `card.band.*`, `errors.api.GENERATOR_NETWORK_TOO_LARGE`, en français et en anglais. Épicène, sans point médian.

## 9. Ce qui part, ce qui reste

**Supprimé** : `service/route/generator/` entier (recherche, `RouteGuarantees`, oracle) ; dans `service/route/network/`, `TeamNetworkCache`, `TeamNetwork`,
`TeamNetworkSummary`, `TrackInputMapper` ; `RouteGeneratorNetworkDto`, `RouteGeneratorNetworkDetails` ; les permis et l'échéance de `RouteGeneratorGuard`, les
mesures de cache de `RouteGeneratorMetrics` ; en test, `service/route/generator/` (24 fichiers, 7 710 lignes : unitaires, propriétés, performance,
`RealisticNetworks`, `RawInputOracle`), `RouteGeneratorCacheTest`, `TeamNetworkSummaryTest`, `TrackInputMapperTest` ; les clés du §7 ; la section d'OPERATIONS.

**Gardé** : `gpx_tracks.network_edges`, `V91` et son index, `NetworkEdgesBackfill`, l'écriture des arêtes au rattrapage HD, `NetworkEdgesDocument` — ils
nourrissent le dépôt ; `V93`, `Route.excludedFromGenerator`, son champ dans `RouteRequest` et `RouteDetailDto`, `RouteExcludedFromGeneratorResourceTest` — le
drapeau part avec chaque trace ; `Fingerprint` et sa requête (l'empreinte), `streamTracks` (le flux) ; `RouteGeneratorGuard.admit` et Caffeine (ses fenêtres ;
seul le commentaire du `pom.xml` change) ; `RouteGeneratorType`, `CompassPoint` ; `NetworkEdgesSeeder` (tests du dépôt).

## 10. Tests (écrits et compilés ici, lancés par le propriétaire ; moteur bouchonné, données synthétiques)

Backend, `@QuarkusTest` sauf mention :

1. `RouteGeneratorResourceTest`, réécrit : ce que reçoit le bouchon par défaut (curseur 0,25, `road`, graine 0, localisation de l'équipe, clé de test, `Ord-Team`
   = TSID) ; aller simple et cap ; bornes (`discovery` −0,1 et 1,1, 9 et 201 km, graine négative → `VALIDATION`) ; champs rendus ; droits (non membre 403, autre
   domaine 404, sans session 401, planificateur coupé, interrupteur) ; 429 ; `GENERATOR_UNAVAILABLE` sous l'api 1.8, sans appel au moteur.
2. Unitaires : `RouteGeneratorErrorsTest` (chaque ligne du §3, raisons tirées d'une copie de l'enum du contrat 1.9), `GeneratedRouteSanityTest` (chaque contrôle
   du §4 refuse un parcours forgé, garde le bon), `GeneratedRouteAscentTest` (gain repris ; échec, pause, budget dépassé → `null` sur ce seul parcours).
3. `RouteGeneratorOverlayJobTest` : NDJSON reçu (une ligne par trace, `type`, `excluded`, texte tel quel, document périmé → `null`, ligne de fin) ; seconde passe
   sans changement → aucun dépôt ; exclusion, trace nouvelle, `stale`, expiration proche, `force` → dépôt ; équipe supprimée, planificateur coupé → `DELETE` ;
   503 puis réussite après `Retry-After` ; connexion impossible → fin de passe ; verrou pris ailleurs → passe sautée ; générateur éteint → rien n'est envoyé.
4. Requêtes : `RouteGeneratorOverlayQueryCountTest` (une passe = 1 + 1 par équipe, + 1 par dépôt, pour 2 comme pour 20 traces) ; `RouteGeneratorQueryCountTest`
   réécrit (une génération coûte autant pour 1 ou 3 parcours rendus, pour 2 ou 20 parcours d'équipe).
5. `AdminRouteGeneratorResourceTest` : 403 hors administration, essai à blanc, 202.
6. `RouteGeneratorGatewayHttpTest` (serveur `com.sun.net.httpserver` local, comme `OpenMeteoGatewayHttpTest`) : HTTP/1.1, en-têtes, corps reçu par morceaux,
   réponse anticipée qui arrête l'écriture, `Retry-After`, délai de lecture, connexion refusée.
7. Unitaires : `NamespaceKeyTest` (43 caractères acceptés ; remplissage, 31 octets, `+` et `/` refusés ; `toString` sans la clé), `OverlayDigestTest`,
   `NetworkEdgesHeaderTest`, `OverlayNdjsonWriterTest`.

Restent : `RouteExcludedFromGeneratorResourceTest`, `RouteGeneratorGuardTest` (fenêtre seule), les tests des arêtes et du backfill. Vitest :
`routeGeneratorFilters.test.ts` (`dec`, quart, 200 km, `f` ignoré), `routeGenerator.test.ts` (requête, trois messages nouveaux, « Réessayer », part d'équipe),
`RouteGeneratorPanel.test.tsx` (crans et défaut, part d'équipe, D+ absent, deux avis ; les tests `fallback` et `incomplete` partent). `route-generator.e2e.ts` :
l'appel réel attend le message de `GENERATOR_UNAVAILABLE`, les bouchons prennent le nouveau DTO ; une génération réelle se vérifie à la main (pile locale, graphe).

## 11. Registre, dans le commit du travail

- `API-198` passe à `LEDGER_DONE`, au passé, daté, contrat `15.0.0`, tests du §10. À ne pas défaire : `network_edges` et le backfill restent, l'exclusion part
  avec chaque trace, un document non actuel part en `null`, les garanties sont vérifiées par le service.
- `API-207` reste ouvert pour les lots 4 à 7 ; **scission** : les lots 0 à 3 (graphe, surcouche, moteur, service 1.9, ce lot) prennent `API-206` dans
  `LEDGER_DONE`. `API-205` reste dans « Délibérément dehors », raison complétée (recherche retirée, rien à rouvrir).
- `WEB-179` reste ouvert, texte mis à jour ; il passe à `LEDGER_DONE` quand `route-generator.e2e.ts` a tourné vert et l'ordre des couches a été vu à l'œil.
- Nouveaux : `OPS-60` (image 1.9 et graphe dans la pile partagée, clé dans chaque `.env`, première passe à la main) ; `SEC-52` (clé en clair sur
  `pedalons-shared`, `allowed_namespaces`, `/metrics`). Derniers numéros relus le 16 novembre (`API-205`, `OPS-59`, `SEC-51`) : à relire au commit, une autre
  session écrit dans le registre.
- Les cinq notes `2026-11-13-generateur-boucles-equipe*.md` passent dans `docs/plans/archive/` (ligne au README, liens mis à jour) ; le plan du 15 renvoie ici.

## 12. Questions au propriétaire (défaut pris entre parenthèses)

1. `15.0.0` pour un changement que seul le propriétaire voit, ou `14.16.0` ? (`15.0.0`, la règle du dépôt pour un contrat cassant.)
2. D+ calculé en `fast` avant la réponse, ou absent jusqu'à l'éditeur ? (calculé, 2,5 s au plus.)
3. Cinq crans au quart, dont un cran strict nommé à 0 ? (oui.)
4. `GENERATOR_NETWORK_NOT_READY` : message seul, ou nouvel essai silencieux en découverte ? (message seul.)
5. Équipes hors région : bouton gardé avec le message, ou masqué d'après le polygone des capacités ? (gardé.) Planificateur coupé : surcouche effacée ? (oui.)
6. `RouteGuarantees` et l'oracle : le registre du 15 novembre les gardait, le lot 3a les retire. Les supprimer ? (oui.)
7. `allowed_namespaces` en production, réseau partagé chiffré (lot 3a, questions 8) ? (ni l'un ni l'autre pour l'instant, `SEC-52`.)
8. Passe à 02:10 UTC, redépôt à 7 jours de l'expiration ? (oui.) Un bouton du déclencheur dans l'administration du site ? (non : Swagger UI ou `curl`.)

## 13. Risques ouverts

- **L'image 1.9.0 n'est pas publiée** (dernière étiquette d'osm-route-details : `v1.8.0`, branche `feat/ord-graph` non poussée) : la CI e2e, qui tire l'image du
  fichier partagé, échoue tant qu'elle n'existe pas. Une équipe hors des Pays de la Loire n'a plus de générateur : voulu (plan §12 quater).
- Empreinte par sommes : un changement qui se compense attend le redépôt hebdomadaire. Transaction de lecture ouverte le temps d'un dépôt. D+ : trois appels
  `fast` de plus par génération sur le service partagé, propositions sans D+ à froid. La pile e2e n'exerce jamais le moteur.
- Côté service : clé en clair sur le réseau partagé, durée d'un dépôt d'un autre environnement mesurable (lot 3a §5.3), 2G non mesurés en conteneur avec une
  altitude à froid, contrôleur à +120 ms en strict (relevé §3.3).

## 14. Ordre

(1) Backend : client, capacités, clé, erreurs, contrôle, D+, service réécrit, retrait de la recherche, contrat `15.0.0`, `mvn -q -DskipTests test-compile` ; (2)
travail nocturne, flux, déclencheur et leurs tests ; (3) configuration, compose, scripts, OPERATIONS, README, `.env.example` ; (4) site, Vitest, e2e,
`./format.sh`, registre, archivage. Hors lot (`OPS-60`) : pile partagée en 1.9 avec le graphe, chaque environnement avec sa clé, déclencheur avec `force`.

## 15. Écarts du codage (backend)

Ce qui diffère de la note, et pourquoi. Le reste du backend est codé tel quel ; le site, Vitest, e2e et le registre ne sont pas faits ici.

1. **Contrôles du §4** : l'ordre est parts (5), décodage (1), longueur (2), départ et arrivée (3), saut (4). Une boucle se ferme à 50 m du premier point, un aller simple finit à 2 km de l'arrivée ; le départ doit rester à 2 km de la demande dans les deux cas. `bounds` est calculé dans le même passage.
2. **Couture `exchange`** : `Call` et `Exchange` sont des records package-private ; le bouchon est `FakeRouteGeneratorGateway` (même package, `@Mock`). Il surcharge aussi `availability(boolean)` (api et interrupteur du bouchon) au lieu de passer par `FakeRouteDetailsClient`, dont l'api par défaut reste 1.7 pour ne pas toucher les tests existants. Les capacités réelles (`RouteDetailsCapabilities.generator`) sont couvertes par `RouteDetailsCapabilitiesTest`.
3. **Capacités sans cache** : `RouteDetailsGateway.freshCapabilities()` (nouvelle) ; le travail nocturne et le déclencheur l'utilisent, une génération lit le cache d'une heure.
4. **Équipes non servies** : une requête d'état (`GET`) précède l'effacement ; une équipe non servie dont l'état est `absent` n'est ni effacée ni listée. Une équipe supprimée ou un domaine inactif ou supprimé donne `TEAM_GONE`, un planificateur coupé `PLANNER_OFF`.
5. **Déclencheur** : l'essai (200) tourne de façon synchrone et sans verrou consultatif (il n'écrit rien) ; `started` y vaut « la passe a eu lieu ». La passe en arrière-plan (202) renvoie `items` vide et `graphId` absent. Le service d'administration est `service/admin/RouteGeneratorOverlayAdminService` (`@Admin`, exigé par `ArchitectureTest`).
6. **Clé** : `%test` porte le vecteur synthétique, `%dev` une valeur vide (`GENERATOR_UNAVAILABLE` et un `WARN` au démarrage) ; toute clé non vide est vérifiée au démarrage, quel que soit le profil.
7. **`RouteGeneratorGuard.of(maxPerWindow, windowMinutes, clock)`** : plus de permis ni d'échéance, `RouteGeneratorGuardTest` réduit à la fenêtre.
8. **Réponses hors contrat** : `409 deposit_in_progress`, `507` et tout statut hors contrat sur une génération sont `GENERATOR_UNAVAILABLE` (journalisés en `ERROR`).
9. **Contrat** : régénéré en deux temps (`mvn clean package`, puis clients mobile et web, `generate-routes`, `generate-brand-colors`) sans `pnpm check` : le panneau (`WEB-179`) ne compile plus contre le nouveau client tant qu'il n'est pas adapté, comme prévu. `mobile/lib/config/paths.generated.dart`, ne différant que par le formateur, n'a pas été touché.
10. **Non lancé** : aucun test (consigne), ni build d'image. Les tests de requêtes comptent un état au repos de 2 requêtes (liste des équipes, empreinte) : valeur à confirmer au premier lancement. Le dépôt envoie `Expect: 100-continue` (corrigé après revue) : un refus donné avant la lecture du corps revient avant le premier octet ; `RouteGeneratorGatewayHttpTest.anEarlyAnswerStopsTheWriting` le vérifie contre `com.sun.net.httpserver`, et le moteur réel le fait pour un refus d'en-tête (§16).

## 16. Vérification finale (16 novembre 2026)

Lancé dans la branche `feat/route-generator-osm`, sans test backend (consigne) :

| Vérification | Résultat |
|---|---|
| `mvn -q -o -DskipTests test-compile` | code de sortie 0 |
| Contrat régénéré une fois de plus (`mvn -q -o clean package -DskipTests`, client mobile, `generate-api`, `generate-routes`, `generate-brand-colors`, formateurs) | aucun écart : `contracts/`, `mobile/lib/api/generated/`, `frontend/src/api/`, `paths.generated.dart`, `badgeColors.generated.ts`, `enum_colors.generated.dart` identiques à l'état d'avant ; version `15.0.0` ; pas de chemin parasite `/v1/route-details` |
| `dart analyze lib/api/generated/` | aucun problème |
| `pnpm typecheck`, `pnpm e2e:typecheck`, `pnpm format:check` | verts |
| `pnpm lint` | 0 erreur ; un avertissement dans `TeamMemberLimit.tsx`, fichier hors lot |
| Vitest, suite entière (après `pnpm copy-legal`) | 251 fichiers, 2 435 tests, tous verts |
| `./format.sh backend`, `frontend`, `mobile` (karoo et garmin-app non touchés) | aucun fichier changé (empreinte de l'arbre identique avant et après) |
| Restes de la recherche Java (classes, clés, `ROUTE_GENERATOR_CACHE_MB`, `…_MAX_OBSERVATIONS`, `GENERATOR_NETWORK_TOO_LARGE`, `familiarity`, traductions) | aucun dans le code ; les seules mentions sont l'histoire (plans, registre) et deux tests qui vérifient que `familiarity` est ignoré. Un commentaire périmé corrigé dans `RouteGeneratorPage.tsx` |
| Secrets et données réelles dans le diff | une seule chaîne de 43 caractères : le vecteur de test `%test` (octets 0x00 à 0x1f, décodé) ; aucune coordonnée à trois décimales ou plus ajoutée ; identifiant d'équipe des tests synthétique |

**Moteur réel**, binaire `target/release/osm-route-details` du worktree `feat/ord-graph` (api 1.9), lancé hors conteneur sur ce
poste, caches dans un dossier temporaire, clé tirée au hasard et jamais écrite, équipe synthétique :

- **sans graphe** : démarre, `/health/ready` 200, `generator.enabled = false`, `reason = not_configured` ; **chemins vers des
  fichiers absents** (ce que fait `${ORD_GRAPH_NAME:-absent}` du fichier partagé) : démarre aussi, prêt, `reason = graph_unreadable`,
  trois `WARN`. Le risque du §15 (le service démarre-t-il sans graphe ?) est levé pour le binaire ; pas vérifié dans l'image 1.9.0,
  qui n'existe pas encore ;
- **avec le graphe** (`pays-de-la-loire-20261114-z11.ordg`, vues de `lot2/views/`, `pays-de-la-loire.poly`) : prêt en 4 s,
  `graph.id` `4a8ab3fc75a87044`, `distance_m_max` 200 000 ; état `absent`, puis dépôt NDJSON d'une trace → 200 et état `ready` ;
  génération 40 km au départ d'un point de la région : trois parcours, 0,36 s au curseur 1 et 0,13 s à 0,25 ; départ hors région →
  422 `out_of_coverage` ; `DELETE` → 204 ; la clé n'apparaît pas dans le journal ;
- **`Expect: 100-continue`** : un dépôt de 2 Mo avec une clé mal formée reçoit `400` sans `100 Continue`, avant l'envoi du corps.
  Un refus donné *après* l'entrée dans le gestionnaire (409, 503) n'a pas été essayé ;
- **D+** : chiffres au §5 (1,04 s à froid, 0,12 s à chaud pour trois appels en parallèle).

## 17. Pour le propriétaire : lancer, essayer, ce qui ne s'essaie pas encore

### 17.1 Les tests backend (jamais lancés)

```sh
cd ~/code/perso/tribly.worktrees/feat/route-generator-osm/backend
mkdir -p keys && cp ~/code/perso/tribly/backend/keys/*.pem keys/     # absents d'un worktree neuf (SRJWT05009 sinon)
mvn test -Dtest='RouteGenerator*Test,AdminRouteGeneratorResourceTest,GeneratedRoute*Test,NamespaceKeyTest,OverlayDigestTest,NetworkEdges*Test,OverlayNdjsonWriterTest,RouteDetailsCapabilitiesTest,FakeRouteDetailsGatewayTest,RouteExcludedFromGeneratorResourceTest,ElevationRefresh*Test,ArchitectureTest'
```

Ce filtre prend les 22 classes du lot et de ce qu'il garde : `RouteGeneratorResourceTest`, `…QueryCountTest`, `…OverlayJobTest`,
`…OverlayQueryCountTest`, `…GatewayHttpTest`, `…ErrorsTest`, `…GuardTest`, `AdminRouteGeneratorResourceTest`, `GeneratedRouteSanityTest`,
`GeneratedRouteAscentTest`, `NamespaceKeyTest`, `OverlayDigestTest`, `NetworkEdgesHeaderTest`, `OverlayNdjsonWriterTest`,
`RouteDetailsCapabilitiesTest`, `FakeRouteDetailsGatewayTest`, puis les tests gardés `RouteExcludedFromGeneratorResourceTest`,
`NetworkEdgesBackfillTest`, `NetworkEdgesDocumentTest`, `ElevationRefreshEdgesOnlyTest`, `ElevationRefreshTest` et `ArchitectureTest`
(le service d'administration `@Admin`). Puis la suite entière, `mvn test`, avant de fusionner. Points à regarder en premier : les
deux tests de requêtes (état au repos supposé de 2 requêtes, §15.10) et `anEarlyAnswerStopsTheWriting`.

**Après les tests**, `mvn test` réécrit `contracts/openapi.*` avec un chemin `/v1/route-details` de trop : refaire
`mvn -q clean package -DskipTests` avant de commiter (ne pas faire `git checkout contracts/`, qui reviendrait à `14.15.0`).

### 17.2 Essai de bout en bout sur ce poste

Le moteur tourne **hors conteneur**, depuis le worktree d'osm-route-details. La pile du poste reste celle de `develop`, lancée
depuis le checkout principal ; son osm-route-details 1.8 (port 18003) ne sert pas à cet essai.

1. **Le moteur**, dans un terminal (binaire déjà construit ; sinon `cargo build --release -p ord-server` dans ce worktree) :

   ```sh
   G=$HOME/.cache/osm-route-details/graph; L=$HOME/.cache/osm-route-details/local
   mkdir -p $L/cache $L/overlays
   ORD_GENERATOR__GRAPH=$G/pays-de-la-loire-20261114-z11.ordg \
   ORD_GENERATOR__VIEW_ROAD=$G/lot2/views/pays-de-la-loire-20261114-z11.road.ordv \
   ORD_GENERATOR__VIEW_GRAVEL=$G/lot2/views/pays-de-la-loire-20261114-z11.gravel.ordv \
   ORD_GENERATOR__COVERAGE_POLY=$G/pays-de-la-loire.poly \
   ORD_SERVER__LISTEN_ADDR=127.0.0.1:28080 ORD_SERVER__METRICS_ADDR=127.0.0.1:29090 \
   ORD_CACHE__DIR=$L/cache ORD_GENERATOR__OVERLAY_DIR=$L/overlays ORD_LOG__FORMAT=text \
     ~/code/perso/osm-route-details.worktrees/feat/ord-graph/target/release/osm-route-details serve
   ```

   Attendu : prêt en quelques secondes ; `curl -s localhost:28080/v1/capabilities | jq '.generator.enabled, .generator.graph.id'`
   → `true`, `"4a8ab3fc75a87044"`.

2. **La clé** : une ligne dans `~/code/perso/tribly/.env`, tirée une fois (elle doit rester la même d'un lancement à l'autre, les
   surcouches sont rangées sous elle) :

   ```sh
   echo "ROUTE_GENERATOR_NAMESPACE_KEY=$(head -c32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')" >> ~/code/perso/tribly/.env
   ```

3. **La pile** (postgres, MinIO, mailpit) : `cd ~/code/perso/tribly && docker compose up -d`, comme d'habitude. Aucune migration
   dans ce lot (dernière : `V93`).

4. **Le backend** de la branche, pointé sur le moteur du terminal 1 :

   ```sh
   cd ~/code/perso/tribly.worktrees/feat/route-generator-osm/backend
   ENV_FILE=~/code/perso/tribly/.env source ../scripts/dev-env.sh    # exporte aussi la clé
   OSM_ROUTE_DETAILS_URL=http://localhost:28080 mvn quarkus:dev
   ```

   Sans clé, le démarrage écrit un `WARN` et chaque génération répond `GENERATOR_UNAVAILABLE`.

5. **Le site** : `cd …/feat/route-generator-osm/frontend`, `echo VITE_API_TARGET=http://localhost:8080 > .env`, `pnpm dev`. Sans les
   certificats mkcert (absents des deux checkouts), le site sert en http : la connexion par code (mailpit, port 8025) marche, les
   passkeys non.

6. **Une équipe à essayer** : planificateur actif, des parcours dans les Pays de la Loire. Ses traces n'ont des arêtes que si le
   rattrapage `network_edges` est passé sur cette base ; sinon la surcouche est vide (part d'équipe 0 partout) : relancer le
   backend avec `NETWORK_EDGES_BACKFILL_ENABLED=true` (30 parcours par heure par défaut, `NETWORK_EDGES_BACKFILL_PER_HOUR` pour
   aller plus vite sur un poste), ou essayer au curseur « Découverte ».

7. **Avant le dépôt**, ouvrir `http://localhost:5173/equipes/<slug>/parcours/generer` et générer au curseur par défaut : attendu
   « Les routes de l'équipe sont en préparation pour le générateur… », sans « Réessayer » ; à « Découverte », des propositions
   (comportement du contrat 1.9 : sans surcouche, seul le curseur 1 est servi ; pas essayé ici sur le vrai moteur).

8. **Le dépôt à la main**, en administration de la plateforme (l'adresse du compte d'amorçage) :

   ```sh
   B=http://localhost:8080; E=<adresse de l'administration>
   curl -s -X POST $B/api/auth/otp -H 'Content-Type: application/json' -d "{\"email\":\"$E\"}"
   # code à six chiffres dans mailpit, http://localhost:8025
   T=$(curl -s -X POST $B/api/auth/otp/verify -H 'Content-Type: application/json' -d "{\"email\":\"$E\",\"code\":\"<code>\"}" | jq -r .accessToken)
   curl -s -X POST $B/api/admin/route-generator/overlays/refresh -H "Authorization: Bearer $T" -H 'Content-Type: application/json' -d '{"dryRun":true}' | jq
   curl -s -w '%{http_code}\n' -X POST $B/api/admin/route-generator/overlays/refresh -H "Authorization: Bearer $T" -H 'Content-Type: application/json' -d '{"force":true}'
   ```

   Attendu : l'essai à blanc rend 200 et une ligne par équipe servie (`DEPOSIT`/`ABSENT` au premier passage) ; une équipe
   supprimée ou au planificateur coupé n'apparaît, en `DELETE`, que si le moteur lui garde une surcouche (§15.4) ; le vrai passage rend 202 `{"started":true,…}`, puis le journal du backend écrit
   une ligne `Route generator overlays: team …` par équipe et une ligne de fin ; un second essai à blanc dit `KEEP`/`CURRENT`.
   Swagger UI (`http://localhost:8080/q/swagger-ui`, avec le même jeton) fait la même chose.

9. **Après le dépôt**, dans le panneau : trois propositions au plus, chacune avec « … sur les routes de l'équipe » et, d'ordinaire,
   une ligne de D+ (absente si les appels `fast` dépassent 2,5 s) ; cinq crans de « Uniquement les routes de l'équipe » à
   « Découverte », défaut « Surtout les routes de l'équipe » ; l'avis « Routes de l'équipe prises en compte jusqu'au … ». Un départ
   hors région (une autre région de France) → le message « hors de la région que couvre le générateur », sans « Réessayer » ; le
   moteur arrêté (Ctrl-C au terminal 1) → « indisponible pour le moment », avec « Réessayer ». Un parcours enregistré ensuite ne
   compte qu'au passage suivant (la nuit, ou le déclencheur). « Ouvrir dans l'éditeur » doit garder la ligne telle quelle, et
   l'ordre des couches de la carte est à regarder (`WEB-179`).

### 17.3 L'e2e du site

`route-generator.e2e.ts` a besoin de la pile e2e, qui tire `ghcr.io/glandais/osm-route-details:1.9.0` du fichier partagé : l'image
n'est **pas publiée**. En attendant, la construire sur le poste (pas essayé ici) puis lancer la spec :

```sh
docker build -t ghcr.io/glandais/osm-route-details:1.9.0 ~/code/perso/osm-route-details.worktrees/feat/ord-graph
cd ~/code/perso/tribly.worktrees/feat/route-generator-osm && scripts/e2e.sh up && scripts/e2e.sh test route-generator
```

Attendu : la pile e2e n'a pas de graphe, l'appel réel rend « indisponible » ; les autres tests bouchonnent l'endpoint. Vert, et
l'ordre des couches vu à l'œil : `WEB-179` passe à `LEDGER_DONE`.

### 17.4 Ce qui ne s'essaie pas encore

- **La pile partagée en 1.9** (`OPS-60`) : image non publiée, fichiers du graphe à poser sous `~/shared/data/osm-route-details-graph/`
  avec `ORD_GRAPH_NAME`, une clé par environnement, puis le déclencheur avec `force`. La mémoire du service avec le graphe *dans le
  conteneur* (2G) n'est pas mesurée. La CI e2e échoue tant que l'image manque.
- **Le passage de 02:10 UTC** lui-même (seul le déclencheur s'essaie sur un poste) et **deux backends en déploiement roulant** sur
  le verrou consultatif (couvert par `RouteGeneratorOverlayJobTest` seulement).
- **Un refus du moteur après le début du dépôt** (409, 503 dans le gestionnaire) : seul le refus d'en-tête a été vu avant le corps.
- Hors lot : les équipes hors des Pays de la Loire (pas de générateur), les formes organiques, l'off-road, le graphe de la France
  (lots 4 à 7, `API-207`), l'écran de l'app (`MOB-154`).

## 18. Suites du 16 novembre 2026 : essai de bout en bout, publication

Ce qui suit corrige les réserves des §14 à §17 écrites avant la publication.

- **Tests backend lancés** (autorisés par le propriétaire) : trois échecs sur 219 dans les classes du générateur, corrigés
  — le résultat du déclencheur est un DTO (`RouteGeneratorOverlayRefreshResult`), `ArchitectureTest` refusant qu'une ressource
  lise un record du service ; `anEarlyAnswerStopsTheWriting` passe par une socket brute, le serveur HTTP du JDK envoyant
  `100 Continue` de lui-même ; tolérance des parts lues en flottant simple. Suite complète verte, 5 042 tests après fusion
  de `develop`.
- **Essai de bout en bout sur un poste**, sur une copie de la base locale : « réseau en préparation » puis dépôt par le
  déclencheur (2 656 traces, 684 Mo en 58 s), génération par l'API (strict, défaut, cap, gravel, aller simple, 180 km :
  0,5 à 2,6 s, D+ compris) et par le panneau, « hors zone », « indisponible », surcouches conservées au redémarrage du
  moteur, clé absente des journaux. Deux écarts : les documents d'arêtes venaient de l'export de production, greffés sur
  les traces locales (la base locale datait d'avant le recalcul du parc), donc la chaîne « enregistrer un parcours →
  document d'arêtes » n'est pas couverte par cet essai ; « Ouvrir dans l'éditeur » n'a pas été cliqué.
- **osm-route-details `v1.9.0` publié** : `develop` fusionné et tagué, image `ghcr.io/glandais/osm-route-details:1.9.0`
  disponible, essayée en conteneur limité à 2G avec le graphe. La CI e2e de ce dépôt peut donc la tirer.
- **e2e du site** : `route-generator.e2e.ts` 10 passés et 2 ignorés, `routes-render -g routeGenerate` 12 passés.
- **Fusion de `develop`** : la recherche Java y avait reçu la veille la levée de la règle du demi-tour étalé aux bouts du
  parcours ; elle est portée dans le moteur et son contrôleur (ledger `API-207`). Le bundle du planificateur embarqué
  (`mobile/assets/planner/`) est reconstruit, il dépend du client d'API du site. L'entrée du générateur passe d'`API-204`,
  pris entre-temps, à `API-207`.
- **Mise en service faite le 16 novembre 2026** (`OPS-60` : pile partagée en 1.9 avec le graphe, une clé par environnement,
  première passe à la main sur staging et prod). Reste hors code : `SEC-52`.
