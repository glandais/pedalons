# Retouche d'un parcours, lot 7c : backend et site

Écrit le 24 novembre 2026. **État : backend et site codés le 24 novembre 2026 (§13 pour le backend, §14 pour le site), tests backend ciblés verts le même jour (167) ; e2e écrits, non lancés ; rien vu dans un navigateur.** Lots 4 (backend) et 5 (site) du plan
[`2026-11-22-retouche-parcours.md`](2026-11-22-retouche-parcours.md) (§7, §8, décisions D1 à D5 du §9),
avec les briques du §8 de [`2026-11-23-itineraire-velo-osm.md`](2026-11-23-itineraire-velo-osm.md).
Ledger `API-212` (backend), une entrée `WEB` (site) et une entrée `OPS` (mise en service du moteur) à
créer (§11).

Moteur : osm-route-details **1.18.0, API 1.17**, `POST /v1/generator/routes/edit`, publié le 24 novembre 2026,
**non déployé** (production en 1.17.1). Sources lues : `contract/openapi.json` (schémas `EditRequestV1`,
`EditResponseV1`, `EditedRouteV1`, `ChangedV1`, `EditCapabilities`), `CHANGELOG.md` (1.18.0),
`docs/design/technique/ord-retouche-lot1.md` §15 et §16.

Marques : **(lu)** relu dans le code le 24 novembre 2026 ; **(supposé)** à vérifier pendant le codage
(chaque supposé a son test au §9) ; **[tranché]** choix de cette note ; **[propriétaire]** choix pris par
défaut, le plus prudent, que le propriétaire peut changer sans bloquer le lot (§12).

---

## 1. En une page

- Deux endpoints sous le parcours, tag `Route generator` :
  `GET /api/teams/{teamSlug}/routes/{routeSlug}/retouch` dit **si l'action est offerte à l'appelant
  pour ce parcours, et avec quelles bornes** ; `POST` du même chemin rend une à trois propositions.
- **Le moteur décide de l'offre** : sans `capabilities.generator.edit` (moteur 1.17.x en production,
  pile e2e sans graphe), `GET` répond `available: false` et le site n'affiche rien. Aucune autre
  bascule : le déploiement de 1.18.0 allume l'action, un retour à 1.17.x l'éteint.
- Droits : **lire le parcours et `PlannerAccess.check`**, l'interrupteur
  `pedalons.route-generator.enabled`, la fenêtre de 30 demandes par 15 min **partagée avec le
  générateur** (`RouteGeneratorGuard`), aucun quota tiré, aucune migration.
- Le parcours envoyé au moteur est la **trace brute** (`gpx_tracks.raw_geometry`, celle dont
  `network_edges` a été calculé) et son document **tel que stocké**, à la seule condition qu'il soit à
  jour par la règle de la surcouche de nuit (§4). Sinon refus propre, aucun calcul à la volée (D1).
- Site : sur la page d'un parcours, un bouton « Retoucher » ouvre un menu « Ajuster la distance » /
  « Déplacer l'arrivée » ; une fenêtre montre l'original en fond, la proposition par-dessus, le tronçon
  changé surligné, distance et D+ avant → après ; « Ouvrir dans le planificateur » passe par la
  page de création, comme le générateur. Rien n'est enregistré.
- **Raccourcir refusé est un cas normal** (57,2 % de réussite, 38,9 % sur un aller simple) : code
  dédié `ROUTE_RETOUCH_NO_SHORTER`, message en bleu (info) qui propose une distance moins courte,
  « Déplacer l'arrivée » ou le générateur. L'anomalie d'ordre (5 % des traces au banc, borne basse) a
  son code et son message.

---

## 2. Endpoints et DTO

Nouvelle ressource `api/routes/RouteRetouchResource.java`,
`@Path("/api/teams/{teamSlug}/routes/{routeSlug}/retouch")`, `@RolesAllowed("user")`, tag
`Route generator`. **Le slug, pas l'id** [tranché] : toutes les routes d'un parcours de
`RouteResource` prennent `{routeSlug}` **(lu)**. Service `service/route/network/RouteRetouchService.java`,
méthodes `@Logged` (`ArchitectureTest`), **non transactionnel** comme `RouteGeneratorService` : les
lectures passent par une transaction courte (`QuarkusTransaction.requiringNew()` ou une méthode
`@Transactional` d'un bean de lecture), aucune connexion n'est tenue pendant le calcul.

### 2.1 `GET …/retouch` — `operationId: getRouteRetouchOffer`

Réponse 200 `RouteRetouchOfferDto` (`dto/routes/response/`) :

| Champ | Type | Sens |
|---|---|---|
| `available` | boolean, requis | l'action peut être demandée maintenant |
| `unavailableReason` | `RouteRetouchUnavailable`, absent si `available` | `NOT_ALLOWED`, `ENGINE_UNAVAILABLE`, `NOT_READY`, `UNSUPPORTED` |
| `operations` | `RouteRetouchOperation[]`, requis | `RESIZE`, `MOVE_END` ; vide si indisponible (lu dans `edit.operations`, valeurs inconnues ignorées) |
| `originalDistanceM` | number, absent si indisponible | longueur de la trace brute, haversine, la formule du moteur (`original_m`) |
| `minDistanceKm`, `maxDistanceKm` | number | bornes du champ : `L × (1 ∓ change_share_max)`, la seconde plafonnée à `limits.distance_m_max` ; arrondies vers l'intérieur au dixième |
| `minChangeKm` | number | `change_m_min / 1000` (1) : l'écart minimal, de part et d'autre de `L` |
| `maxChangeShare` | number | `change_share_max` (0,30) |
| `endSnapM` | number | `end_snap_m` (500) |
| `proposalsMax` | integer | `proposals_max` (3) |
| `rideType` | `RouteGeneratorType` | type envoyé au moteur (§3.3) |

`unavailableReason`, dans l'ordre où il est jugé :

1. `NOT_ALLOWED` — `PlannerAccess.check` refuse (pas le droit de créer un parcours dans l'équipe, ou
   planificateur éteint pour l'équipe), ou parcours supprimé. **Les deux causes sont confondues** : la
   réponse n'apprend rien de l'équipe à qui n'en est pas. Le site n'affiche rien.
2. `ENGINE_UNAVAILABLE` — `enabled = false`, clé absente, moteur injoignable, ou capacités sans
   `generator.edit`, ou `ride_types` sans le type du parcours. Le site n'affiche rien.
3. `NOT_READY` — document absent, périmé ou d'une version ancienne, ou trace brute absente (§4). Le
   site affiche le bouton **désactivé**, avec une bulle (§7.4).
4. `UNSUPPORTED` — plus d'une trace, document `too_short`, plus de `points_max` points, longueur au-delà
   de `distance_m_max`. Le site n'affiche rien [propriétaire : on pourrait l'expliquer, §12].

Lecture d'un parcours (refusé par la visibilité : 404 comme `GET` du parcours ; anonyme : 401). Coût fixe :
le parcours, une projection des têtes de documents, l'id du fichier d'origine courant, les capacités en
cache (une heure). Aucune lecture de document ni de géométrie entière (§4.2), aucun appel au moteur, aucun
point de la fenêtre de demandes.

### 2.2 `POST …/retouch` — `operationId: retouchRoute`

Requête `RouteRetouchRequest` (`dto/routes/request/`) :

| Champ | Type | Règle |
|---|---|---|
| `targetDistanceKm` | number, facultatif | **distance totale visée** ; `@DecimalMin("1")`, `@DecimalMax("1000")` (bornes de contrat larges, les vraies sont celles de l'offre) |
| `end` | `RouteRetouchEnd`, facultatif | `{ point?: GeoPoint, placeId?: string }` : **exactement un** des deux (D5) |
| `discovery` | number, facultatif | [0 ; 1], défaut 0,25 (`RouteGeneratorService.DEFAULT_DISCOVERY`) ; pas exposé par le site au lot 7c [tranché] |
| `seed` | integer ≥ 0, facultatif | défaut 0 ; « Autres propositions » = graine suivante |

**Exactement un** de `targetDistanceKm` et `end` : sinon 400 `VALIDATION`, champ `targetDistanceKm`
(« exactly one of targetDistanceKm and end »). `end` avec zéro ou deux clés : `VALIDATION`, champ `end`.
`placeId` illisible, d'une autre équipe ou d'un autre domaine : `VALIDATION`, champ `end.placeId`
(jamais 404 : rien n'est appris d'un lieu d'ailleurs). Le lieu est lu par `PlaceRepository` filtré par
équipe **et** domaine.

Réponse 200 `RouteRetouchResponse` — la forme de `RouteGeneratorResponse` (`candidates`,
`networkPreparedAt`), plus l'original :

```
RouteRetouchResponse {
  operation: RouteRetouchOperation          // RESIZE | MOVE_END
  originalDistanceM: number                 // original_m du moteur
  originalAscentM?: number                  // D+ de la trace brute, même calcul que les propositions (§3.4)
  originalDescentM?: number
  targetDistanceM?: number                  // RESIZE seulement
  candidates: RetouchedRouteDto[]           // 1 à 3, la meilleure d'abord
  networkPreparedAt?: Instant               // overlay.deposited_at, absent en découverte
}

RetouchedRouteDto {
  polyline: string                          // parcours COMPLET recollé, précision 6 (lat puis lon)
  distanceM: number
  ascentM?: number, descentM?: number       // absents si le profil n'est pas prêt à temps
  kind: RetouchKind                         // SHORTEN | LENGTHEN | MOVE_END | TRUNCATE
  variant?: RetouchVariant                  // BEST | KEEP_ALL | NEAREST (MOVE_END), absent sinon
  keptShare: number                         // 0..1, part de l'original gardée
  unmatchedM: number                        // gardé sans garantie « pas de route prise deux fois »
  endSnapM?: number                         // MOVE_END/TRUNCATE : du point demandé au dernier point rendu
  changed: RetouchedSpanDto
  bounds: BoundsDto
}

RetouchedSpanDto {
  fromM: number, toM: number                // abscisses sur l'ORIGINAL du tronçon remplacé
  newM: number                              // longueur du tronçon neuf (0 pour TRUNCATE)
  startIndex: integer, endIndex: integer    // indices dans `polyline` du premier et du dernier point neufs
  teamShare: number                         // mesurés sur le tronçon neuf seul (contrat du moteur)
  unpavedShare: number                      // offroad_share
  crossings: integer
}
```

Pas de `partialCoverage` (le moteur ne le rend pas pour une retouche), pas de `sharedM` ni de
`bearingDeviationDeg` (sans objet, §15.2 de la note du moteur). Aucun nom, id ou avatar de membre
(invariant `MemberNamesVisibility` : rien à résoudre ici).

### 2.3 Contrat

`pedalons.api.version` : **16.5.0 → 16.6.0** (ajout pur : deux opérations, des schémas, huit valeurs
d'`ErrorCode`). Skill `contract-first-api` : `mvn -q clean package -DskipTests`, `pnpm generate-api`
dans `frontend/`, client Dart régénéré (rien d'autre côté mobile). Le `@Operation` de `POST` liste tous
les codes du §5, comme celui du générateur **(lu)**.

---

## 3. Backend : la chaîne d'un `POST`

Ordre [tranché] — les refus qui ne coûtent rien passent **avant** la fenêtre de demandes, pour ne pas la
consommer :

1. `plannerAccess.check(teamSlug)` (droits avant l'interrupteur, comme le générateur **(lu)**).
2. Le parcours : `RouteService.findBySlug(team, slug)` (domaine et visibilité) ; supprimé →
   `ROUTE_RETOUCH_UNSUPPORTED`.
3. `enabled` faux → `ROUTE_PLANNER_DISABLED` (le code du générateur **(lu)**).
4. Validation de la requête (§2.2), résolution du lieu.
5. Offre du moteur (§6) absente → 503 `GENERATOR_UNAVAILABLE`, **rien n'est envoyé**.
6. Source (§4) : pas à jour → `ROUTE_RETOUCH_NOT_READY` ; non retouchable → `ROUTE_RETOUCH_UNSUPPORTED`.
7. `RESIZE` : bornes jugées ici avec `L` = haversine de la trace brute (la formule du moteur) :
   `|D′ − L| < change_m_min` → `ROUTE_RETOUCH_CHANGE_TOO_SMALL` ; `> change_share_max × L` →
   `ROUTE_RETOUCH_CHANGE_TOO_LARGE` ; `D′ > distance_m_max` → `ROUTE_RETOUCH_CHANGE_TOO_LARGE`. Au bord
   exact, le moteur rejuge et rend la même raison, mappée sur le même code.
8. `guard.admit(domainId, userId)` — **le même bean, la même clé** que le générateur : 429
   `ROUTE_GENERATOR_RATE_LIMITED` avec `Retry-After`.
9. Corps : taille au-delà de `edit.request_body_bytes` → `ROUTE_RETOUCH_UNSUPPORTED` (rien n'est envoyé).
10. `gateway.edit(teamRef, request)` ; échec → §5.
11. `GeneratedRouteSanity.checkEdit` sur chaque proposition (§3.4) ; toutes écartées → `NO_SHORTER` ou
    `NO_PROPOSAL` (§5).
12. `GeneratedRouteAscent.compute([trace brute, proposition 1, …])` : un seul lot, le D+ de l'original
    est calculé **comme** celui des propositions, pour que « avant → après » compare deux mesures de
    même source [tranché] (le D+ HD de la page du parcours ne s'y compare pas).
13. Métriques et une ligne de journal (§3.5), réponse.

### 3.1 `RouteGeneratorGateway` et `RouteGeneratorV1`

- `RouteGeneratorV1` gagne `EditRequest(polyline, @JsonRawValue networkEdges, rideType, cursor, seed,
  operation)` où `operation` est `EditOperation(@Nullable Resize resize, @Nullable MoveEnd moveEnd)`
  (`@JsonInclude(NON_NULL)` : une seule clé part, la forme du §16 de la note du moteur), et
  `EditResponse`, `EditedRoute`, `Changed`, avec `@JsonIgnoreProperties(ignoreUnknown = true)` comme les
  autres records **(lu)**. `networkEdges` est **le texte JSON du document stocké, recopié tel quel**
  (`@JsonRawValue String`) : ni désérialisé ni réécrit [tranché]. Le moteur tolère les clés en plus
  (`v`, `rev`, `nodes`…) **(lu, §15.1)**.
- `RouteGeneratorGateway.edit(String team, EditRequest)` : `POST /v1/generator/routes/edit`, mêmes
  en-têtes (`Ord-Namespace-Key`, `Ord-Team` = TSID de l'équipe), délai
  `pedalons.route-generator.edit-timeout` = `PT35S` (le budget du moteur est de 30 s, file comprise,
  comme une génération **(lu)**). Le corps est sérialisé en `byte[]` d'abord, pour en connaître la
  taille (étape 9).
- `RouteGeneratorProblems.kind` reste tel quel : `generation_failed` → `GENERATION_FAILED` avec la
  raison, `out_of_coverage`, `overloaded`, `timeout`, `data_unavailable` **(lu)** ; un 400 ou un 413 du
  moteur tombe en `UNEXPECTED` (dérive : le backend juge les mêmes bornes avant).

### 3.2 Capacités

`RouteDetailsCapabilities.GeneratorSection` gagne `@Nullable @JsonProperty("edit") EditInfo edit`
(constructeur à l'ancienne forme gardé, comme pour `offroad` **(lu)**) :
`EditInfo(operations, ride_types, change_share_max, change_m_min, tolerance, end_snap_m, proposals_max,
points_max, request_body_bytes)`. `RouteDetailsCapabilities.editEnabled()` =
`generatorEnabled() && apiAtLeast(1, 17) && generator.edit() != null`.
`RouteGeneratorGateway.Availability` gagne `@Nullable EditInfo edit` (lu dans le cache, `fresh` comme
aujourd'hui). Aucune valeur recopiée à la main : toutes viennent des capacités.

### 3.3 Type de parcours

`surfaceType` du parcours → `ride_type` : `ROAD` → `road`, `GRAVEL` → `gravel`, `MTB` → `mtb`,
`MIXED` → `gravel`, absent → `road` [propriétaire : `MIXED`]. Pas de champ `type` dans la requête au
lot 7c [tranché] : le type est celui du parcours, l'offre le dit (`rideType`). Il sert aussi à
« Ouvrir dans le planificateur » (§7.5).

### 3.4 `GeneratedRouteSanity.checkEdit(EditContext, EditedRoute)`

Le contrôle de `check` ne s'applique pas tel quel (il compare au départ et à l'arrivée demandés d'une
génération). `checkEdit` [tranché], même `Verdict`, mêmes étiquettes de métrique plus `INDICES` :

| Contrôle | Règle |
|---|---|
| `SHARES` | `keptShare`, `changed.team_share`, `changed.offroad_share` dans [0 ; 1], longueurs finies et ≥ 0 |
| `DECODE` | polyligne décodable, au plus `MAX_POINTS` (100 000) |
| `INDICES` | `0 ≤ points[0] ≤ points[1] < n` |
| `LENGTH` | longueur décodée à 1 % de `distance_m` (`ENGINE_LENGTH_TOLERANCE`) ; `RESIZE` : à 10 % de `D′` (`LENGTH_TOLERANCE`) |
| `ENDS` | premier point à 50 m (`LOOP_CLOSING_M`) du premier point de l'original ; `SHORTEN`/`LENGTHEN` : dernier point à 50 m du dernier de l'original ; `MOVE_END`/`TRUNCATE` : dernier point à 2 km (`END_RADIUS_M`) du point demandé |
| `JUMP` | aucun pas de plus de 10 km **dans le tronçon neuf seul** (`points[0]..points[1]`) : la partie gardée est la trace de la personne, un trou de son GPX ne doit pas écarter la proposition |

`bounds` : le cadre de la polyligne entière.

### 3.5 Journal et métriques

`RouteGeneratorMetrics` gagne `retouch(operation, outcome)` (`pedalons_route_retouch_requests_total`,
étiquettes fermées : `operation` ∈ {`resize`, `move_end`}, `outcome` ∈ {`ok`, la raison du moteur en
minuscules, `not_ready`, `unsupported`, `unavailable`, `rate_limited`, `sanity`}) et
`retouchDuration(operation)`. Une ligne par demande : équipe (TSID, comme le générateur), opération,
type, issue, nombre de propositions, écartées, durée. **Jamais** de coordonnée, de polyligne, de
document, de distance visée exacte ni de nom de parcours. `route_mismatch` et `UNEXPECTED` se
journalisent en `WARN` / `ERROR` : le premier dit qu'un document jugé à jour ne décrit pas sa trace
(§4.3), le second une dérive entre les deux dépôts.

---

## 4. Règle « document à jour »

### 4.1 La règle

Un parcours se retouche si, **et seulement si** :

1. il a **exactement une** `GpxTrack` (même règle que la relecture de l'état du planificateur,
   `RouteService.readPlannerState` **(lu)**) — sinon `UNSUPPORTED` ;
2. son document passe **`NetworkEdgesHeader.current(header, original)`** **(lu)** : `v` =
   `NetworkEdgesDocument.VERSION`, statut `ok` ou `too_short`, et `rev` = `file_id` du **fichier
   d'origine courant** du parcours (`AssetRepository.findCurrentFileId(route, ROUTE_ORIGINAL_GPX)`
   **(lu)**). C'est **la règle de la surcouche de nuit** (`OverlayNdjsonWriter`) : un document que la
   surcouche n'enverrait pas, la retouche ne l'envoie pas non plus [tranché]. Échec → `NOT_READY` ;
3. statut `ok` — `too_short` → `UNSUPPORTED` (pas d'arête : le moteur répondrait `route_not_matched`) ;
4. `raw_geometry` non nul — sinon `NOT_READY` (le rattrapage `RawTrackBackfill` le remplit **(lu)**).

« Le document date d'avant la dernière modification » se lit par `rev` : toute modification de la trace
écrit un nouveau fichier d'origine **(lu, javadoc de `NetworkEdgesDocument.rev`)**, donc un nouveau
`file_id`, et le document précédent cesse d'être courant jusqu'au rattrapage HD ou au backfill. **Rien
n'est calculé dans la requête** (D1). La date `updated_at` du parcours n'est pas un critère : un
changement de nom ou d'étiquette ne touche pas la trace [tranché].

### 4.2 Lecture

`GpxTrackRepository` gagne deux projections, sans charger les autres colonnes paresseuses :

- `findRetouchHead(routeId)` → `(trackId, v, rev, status, hasRaw, rawPoints, rawLengthM)` par
  `select id, (network_edges->>'v')::int, (network_edges->>'rev')::bigint, network_edges->>'status',
  raw_geometry is not null, ST_NPoints(raw_geometry), ST_Length(raw_geometry::geography)` — pour
  l'offre et les étapes 6–7 (la longueur exacte, haversine, se recalcule en Java sur les points à
  l'étape 9 ; `ST_Length` ne sert qu'à l'offre) ;
- `findRetouchSource(trackId)` → `(rawGeometry, network_edges::text)` : pour le `POST` seulement.

Les points de `raw_geometry` sont encodés par `PolylineCodec.encode2` (précision 6, latitude puis
longitude **(lu)**).

### 4.3 Pourquoi la trace brute

`network_edges` est calculé sur `rawTracks(original)` densifiée (`GpxPipeline.edgesOf` →
`RouteDetailsTrack.densify`) **(lu)**, et `raw_geometry` est cette même trace, écrite à chaque
remplacement **(lu)**. La densification n'ajoute que des points sur les segments droits : l'axe `fm`/`tm`
du document et la longueur haversine de la trace brute coïncident **(supposé, test §9.1-12)**. Envoyer
`track_points` (rééchantillonnés, filtrés) ferait dériver l'axe et déclencherait `route_mismatch`.

---

## 5. Erreurs : raison du moteur → code Pédalons → texte

Huit valeurs nouvelles d'`ErrorCode`, toutes **400** (`BusinessException`, comme les `GENERATOR_*`
**(lu)**). Fonction pure `RouteRetouchErrors` (paquet `service/route/network`), `switch` exhaustif sur
une énumération `EditReason` de ses propres valeurs (`UNKNOWN` pour une raison ajoutée au moteur), sur
le modèle de `RouteGeneratorErrors` **(lu)**. « Raccourcir » = `RESIZE` avec `D′ < L`.

| Moteur (`kind` / `details.reason`) | Code Pédalons |
|---|---|
| — (étape 6, §4.1 points 2 et 4) | `ROUTE_RETOUCH_NOT_READY` |
| — (plusieurs traces, `too_short`, points, longueur, corps, parcours supprimé) ; `route_not_matched`, `route_mismatch`, `no_seam` | `ROUTE_RETOUCH_UNSUPPORTED` |
| `order_anomaly` | `ROUTE_RETOUCH_ORDER_ANOMALY` |
| `change_too_small` (et étape 7) | `ROUTE_RETOUCH_CHANGE_TOO_SMALL` |
| `change_too_large` (et étape 7) | `ROUTE_RETOUCH_CHANGE_TOO_LARGE` |
| `no_economy` ; et, **en raccourcissant**, `no_window`, `no_candidate`, `checker_rejected`, `off_target`, `budget`, `UNKNOWN`, toutes écartées par `checkEdit` | `ROUTE_RETOUCH_NO_SHORTER` |
| les mêmes en allongeant ou en déplaçant l'arrivée | `ROUTE_RETOUCH_NO_PROPOSAL` |
| `end_unreachable`, `junction_cut` | `ROUTE_RETOUCH_END_UNREACHABLE` |
| `end_too_far` | `GENERATOR_END_TOO_FAR` (repris) |
| `route_off_coverage` ; `out_of_coverage` | `GENERATOR_OUT_OF_COVERAGE` (repris) |
| `overloaded`, `timeout`, délai de lecture | 503 `ROUTE_GENERATOR_BUSY` (repris) |
| `data_unavailable`, injoignable, non configuré, `UNEXPECTED` (400, 413, 500 du moteur, réponse illisible), pas d'offre `edit` | 503 `GENERATOR_UNAVAILABLE` (repris) |
| — (fenêtre) | 429 `ROUTE_GENERATOR_RATE_LIMITED` (repris, compteur partagé) |
| — (droits, planificateur, interrupteur) | 403 / 404 / `ROUTE_PLANNER_DISABLED` (repris) |

Textes. Chaque code a sa clé `errors.api.<CODE>` (fr et en, le test des catalogues l'exige pour tout
`ErrorCode` **(supposé, vérifié par `catalogues.test.ts`)**) ; la fenêtre de retouche emploie ses
propres clés `routeRetouch.errors.*`, choisies par une table typée (jamais une clé bâtie depuis l'enum,
ledger `WEB-84`), qui nomment la distance ou l'arrivée. Épicène, sans point médian.

| Clé `routeRetouch.errors.` | fr | en |
|---|---|---|
| `notReady` | Ce parcours est encore en cours d'analyse. La retouche sera possible une fois l'analyse finie : réessayez plus tard. | This route is still being analysed. You can adjust it once that is done: try again later. |
| `unsupported` | Ce parcours ne peut pas être retouché. Le générateur peut en proposer un nouveau. | This route can't be adjusted. The generator can suggest a new one. |
| `orderAnomaly` | La trace de ce parcours repasse sur elle-même d'une façon que la retouche ne sait pas suivre. Modifiez-le dans le planificateur, ou demandez un nouveau parcours au générateur. | This route's track runs back over itself in a way the adjustment can't follow. Edit it in the planner, or ask the generator for a new route. |
| `changeTooSmall` | L'écart est trop petit : visez au moins {{min}} de plus ou de moins que {{current}}. | The change is too small: aim at least {{min}} above or below {{current}}. |
| `changeTooLarge` | L'écart est trop grand pour une retouche (au plus {{percent}} %). Pour une distance aussi différente, le générateur propose un nouveau parcours. | The change is too large for an adjustment (at most {{percent}}%). For such a different distance, the generator suggests a new route. |
| `noShorter` | Ce parcours ne se raccourcit pas à {{distance}} sans en changer une grande partie, ce qui arrive souvent. Essayez une distance un peu plus longue, déplacez l'arrivée, ou demandez au générateur un parcours de {{distance}}. | This route can't be cut to {{distance}} without changing much of it, which often happens. Try a slightly longer distance, move the finish, or ask the generator for a {{distance}} route. |
| `noProposal` | Aucune proposition pour cette retouche. Essayez une autre distance ou une autre arrivée. | No proposal for this adjustment. Try another distance or another finish. |
| `endUnreachable` | Le parcours ne rejoint pas cette arrivée sans demi-tour. Essayez un point un peu plus loin ou de l'autre côté de la route. | The route can't reach this finish without a U-turn. Try a point a little further on or across the road. |
| `endTooFar` | Aucune voie praticable près de cette arrivée pour ce type de parcours. Posez-la plus près d'une route ou d'un chemin. | No suitable road near this finish for this type of route. Place it closer to a road or track. |
| `outOfCoverage` | Ce parcours ou cette arrivée sort de la carte que couvre le générateur. | This route or this finish is outside the map the generator covers. |

Codes repris sans texte propre : `ROUTE_GENERATOR_BUSY`, `GENERATOR_UNAVAILABLE`,
`ROUTE_GENERATOR_RATE_LIMITED` (avec l'attente en minutes), `ROUTE_PLANNER_DISABLED`, réseau : les clés
`routeGenerator.errors.*` existantes **(lu)**. Les `errors.api.ROUTE_RETOUCH_*` reprennent les textes
ci-dessus sans variable (« Essayez une autre distance… »).

« Réessayer » n'est **pas** offert pour : `NOT_READY`, `UNSUPPORTED`, `ORDER_ANOMALY`,
`CHANGE_TOO_SMALL`, `CHANGE_TOO_LARGE`, `NO_SHORTER`, `NO_PROPOSAL`, `END_UNREACHABLE`, les deux codes
`GENERATOR_*` repris, `RATE_LIMITED`, `PLANNER_DISABLED`, `VALIDATION` (pour `NO_PROPOSAL`, « Autres
propositions » change la graine et reste offert).

---

## 6. Capacités : ce qui dit au site si l'action est offerte

- **Côté backend**, seul juge : `Availability.edit` non nul, `operations` ⊇ {`resize`, `move_end`} pris
  un à un (une opération absente n'est pas offerte), `ride_types` contient le type du parcours.
- **Côté site**, seul `GET …/retouch` : `available`, `operations`, bornes. Aucun champ ajouté à
  `RouteDetailDto` [tranché] : l'offre dépend des capacités du moteur (cache d'une heure) et d'un
  document lourd, ce qui n'a rien à faire sur la lecture d'un parcours ni dans un lookup par page.
- **Production en 1.17.x** : `ENGINE_UNAVAILABLE`, le site n'affiche rien, un `POST` direct répond
  `GENERATOR_UNAVAILABLE` sans appel. Déployer 1.18.0 allume l'action dans l'heure (cache des
  capacités), la retirer l'éteint de même.

---

## 7. Site

### 7.1 Fichiers

| Fichier | Rôle |
|---|---|
| `src/lib/routeRetouch.ts` (+ `.test.ts`) | `retouchBounds(offer)`, `routeRetouchRequest(mode, …)`, `isShortening`, `changedCoords(coords, startIndex, endIndex)`, `retouchHandoff(candidate, rideType, name)`, la table typée `RETOUCH_ERROR_KEYS`, `routeRetouchErrorMessage`, `isRetryableRetouchError`, `generatorLinkFor(route, targetKm)` |
| `src/components/routeRetouch/useRouteRetouchOffer.ts` | `useGetRouteRetouchOffer` généré, `enabled` si connecté et parcours non supprimé, `meta: { [CLIENT_ONLY_QUERY]: true }`, `staleTime` 5 min, sans toast d'erreur |
| `src/components/routeRetouch/useRouteRetouch.ts` | `useQuery` sur le `POST`, comme `useRouteGenerator` **(lu)** : clé `['routeRetouch', team, route, request]`, `staleTime: Infinity`, `gcTime` 30 min, `retry: false`, données précédentes gardées quand seule la graine change, indice « lent » après 4 s, client seulement |
| `src/components/routeRetouch/RouteRetouchButton.tsx` | le bouton « Retoucher » et son `Menu` (une entrée par opération offerte) ; désactivé avec `Tooltip` pour `NOT_READY` ; rien sinon |
| `src/components/routeRetouch/RouteRetouchModal.tsx` (+ `.test.tsx`) | la fenêtre : `SegmentedControl` des deux modes, les champs, « Proposer », l'état, les cartes, la carte, « Ouvrir dans le planificateur » |
| `src/components/routeRetouch/RouteRetouchMap.tsx` | `PedalonsMap` : original en fond, proposition, tronçon changé, marqueurs, clic pour poser l'arrivée ; sur le modèle de `RouteGeneratorMap` **(lu)** |
| `src/components/routeRetouch/RetouchedRouteCard.tsx` (+ `.test.tsx`) | une proposition : distance et D+ avant → après, tronçon changé, part gardée, variante |
| `src/pages/route/RouteDetailPage.tsx` | `RouteRetouchButton` dans le groupe d'actions de l'en-tête ; la fenêtre |
| `src/lib/routeGenerator.ts` | `generatedHandoffSchema` gagne `name` facultatif |
| `src/components/route/RouteEditor.tsx` | le nom de l'import : `initialGenerated.name` s'il est là, sinon `generatedRouteName` comme aujourd'hui |
| `src/locales/{fr,en}/common.json` | `routeRetouch.*`, `errors.api.ROUTE_RETOUCH_*` |

Mantine seul (`Modal`, `Menu`, `SegmentedControl`, `NumberInput`, `Alert`, `Card`, `Tooltip`,
`Skeleton`), icônes Tabler. Pas de nouvelle route d'URL : `contracts/routes.yaml` ne change pas
[tranché] (une fenêtre, comme le générateur dans l'éditeur).

### 7.2 Parcours d'écran

1. **Page d'un parcours**, pour une personne connectée — l'offre est demandée ; `available` : bouton « Retoucher »
   (`IconAdjustmentsHorizontal`) près de « Dupliquer », menu « Ajuster la distance » / « Déplacer
   l'arrivée » ; `NOT_READY` : bouton désactivé, bulle `routeRetouch.notReadyHint` ; autre raison : rien.
2. **Fenêtre** (`size="xl"`, plein écran sous `sm`), titre « Retoucher « {{name}} » », le mode choisi
   dans le menu, commutable. À gauche les champs, à droite la carte (au-dessus sur un téléphone).
3. **Ajuster la distance** : « Actuellement {{distance}} » ; `NumberInput` « Distance visée », unité de
   la personne (`useUnits`), bornes `minDistanceKm`–`maxDistanceKm`, erreur en ligne dans la zone morte
   (`|Δ| < minChangeKm`). Dès que la valeur est sous l'actuelle, une ligne d'aide :
   `routeRetouch.resize.shortenHint`. Le champ ne laisse pas passer une valeur hors bornes : les codes
   `CHANGE_TOO_*` ne s'affichent qu'en cas de dérive.
4. **Déplacer l'arrivée** : la carte est en mode « poser l'arrivée » (curseur en croix), un clic pose
   le point ; ou `PlaceAutocomplete` (`filterEnd`) « Ou un lieu de l'équipe » : la requête porte alors
   `placeId`, la carte centre le lieu. Ligne d'aide : `routeRetouch.moveEnd.help`.
5. **« Proposer »** : squelettes, puis jusqu'à trois cartes, la première sélectionnée. Sur la carte :
   l'original en gris (épaisseur 4, opacité 0,6), la proposition choisie dans la couleur du parcours avec
   chevrons, **le tronçon changé** (`polyline[startIndex..endIndex]`) par-dessus, plus épais, couleur
   d'accent ; pour `TRUNCATE`, le point de coupe. Les autres propositions en fin, survol → mise en avant.
6. **Carte d'une proposition** : « {{before}} → {{after}} » (distance), « D+ {{before}} → {{after}} »
   (tiret quand absent), « {{old}} remplacés par {{new}} » (`toM − fromM`, `newM`), « {{percent}} % du
   parcours gardé » ; `MOVE_END` : la variante (`best` « Le moins de changement », `keep_all` « Tout le
   parcours, puis l'arrivée », `nearest` « Quitter au plus près de l'arrivée ») ; `TRUNCATE` « Le parcours
   s'arrête à la nouvelle arrivée » ; si `unmatchedM > 500`, une note discrète
   `routeRetouch.card.unmatched`.
7. **« Autres propositions »** : graine + 1, les cartes précédentes restent jusqu'aux nouvelles.
8. **« Ouvrir dans le planificateur »** (sur la carte choisie) : §7.5.
9. **Erreur** : `Alert` sous les champs. `NO_SHORTER`, `CHANGE_TOO_LARGE`, `ORDER_ANOMALY` et
   `UNSUPPORTED` en **bleu** (une réponse, pas une panne), avec des boutons : « Déplacer l'arrivée »
   (`NO_SHORTER` seulement, change de mode) et « Ouvrir le générateur » (lien vers
   `paths.routeGenerate(team)` avec `d` = la distance visée arrondie et dans les bornes du générateur, `s`
   = départ du parcours, le type) ; les autres en rouge, « Réessayer » selon §5.

### 7.3 Textes (fr / en)

| Clé `routeRetouch.` | fr | en |
|---|---|---|
| `menu` | Retoucher | Adjust |
| `resize.action` | Ajuster la distance | Adjust the distance |
| `moveEnd.action` | Déplacer l'arrivée | Move the finish |
| `title` | Retoucher « {{name}} » | Adjust “{{name}}” |
| `current` | Actuellement {{distance}} | Currently {{distance}} |
| `resize.label` | Distance visée | Target distance |
| `resize.help` | Entre {{min}} et {{max}}. Le parcours change à un seul endroit, le reste ne bouge pas. | Between {{min}} and {{max}}. The route changes in one place, the rest stays as it is. |
| `resize.deadZone` | Visez au moins {{min}} de plus ou de moins. | Aim at least {{min}} above or below. |
| `resize.shortenHint` | Raccourcir réussit un peu plus d'une fois sur deux. Si rien ne vient, essayez un écart plus petit ou déplacez l'arrivée. | Shortening works a little more than half the time. If nothing comes, try a smaller change or move the finish. |
| `moveEnd.help` | Touchez la carte pour poser la nouvelle arrivée, ou choisissez un lieu de l'équipe. | Tap the map to place the new finish, or pick one of the team's places. |
| `moveEnd.place` | Ou un lieu de l'équipe | Or one of the team's places |
| `submit` | Proposer | Suggest |
| `more` | Autres propositions | Other suggestions |
| `slow` | La retouche prend quelques secondes de plus pour les longs parcours. | Adjusting takes a few more seconds on long routes. |
| `open` | Ouvrir dans le planificateur | Open in the planner |
| `openHelp` | Rien n'est enregistré : le planificateur ouvre un nouveau parcours, que vous enregistrez ensuite. | Nothing is saved: the planner opens a new route, which you then save. |
| `card.distance` | {{before}} → {{after}} | {{before}} → {{after}} |
| `card.ascent` | D+ {{before}} → {{after}} | Gain {{before}} → {{after}} |
| `card.changed` | {{old}} remplacés par {{new}} | {{old}} replaced by {{new}} |
| `card.truncated` | Le parcours s'arrête à la nouvelle arrivée | The route stops at the new finish |
| `card.kept` | {{percent}} % du parcours gardé | {{percent}}% of the route kept |
| `card.unmatched` | Une partie gardée n'a pas pu être vérifiée sur la carte : le tronçon neuf peut la reprendre. | Part of what is kept couldn't be checked on the map: the new section may ride it again. |
| `variant.best` | Le moins de changement | The smallest change |
| `variant.keepAll` | Tout le parcours, puis l'arrivée | The whole route, then the finish |
| `variant.nearest` | Quitter au plus près de l'arrivée | Leave closest to the finish |
| `notReadyHint` | Ce parcours est en cours d'analyse : la retouche sera possible ensuite. | This route is being analysed: you can adjust it afterwards. |
| `openGenerator` | Ouvrir le générateur | Open the generator |
| `retouchedName` | {{name}} (retouché) | {{name}} (adjusted) |

`retouchedName` : « retouché » s'accorde avec « parcours », pas avec une personne : la règle épicène ne
s'applique pas [tranché].

### 7.4 L'aperçu

`RouteRetouchMap` lit la géométrie de l'original dans `route.tracks[0].line` (déjà chargée par la page
**(lu)**), décode les propositions (`decode2`), découpe le tronçon changé par `changedCoords`. Cadrage :
l'union du cadre de l'original et de `bounds`. Le point d'arrivée posé reste affiché, avec un cercle de
`endSnapM` [tranché : il montre où le moteur cherche une voie].

### 7.5 Ouvrir dans le planificateur

Le chemin du générateur **(lu)** : `navigate(paths.routeNew(team.slug), { state: { generated: {
polyline, type: offer.rideType, distanceM, name: t('routeRetouch.retouchedName', { name }) } } })` ;
`CreateRoutePage` lit l'état par `readGeneratedHandoff`, `RouteEditor` l'importe (`gpxFromLine` côté
import du planificateur), la personne enregistre un **nouveau** parcours ; le quota d'enregistrement
du planificateur s'applique alors (`BILL-10`), pas avant. Remplacer le parcours d'origine n'est pas
offert au lot 7c [propriétaire, §12].

---

## 8. Pile e2e

Le moteur de la pile e2e n'a pas de graphe **(lu, `route-generator.e2e.ts`)** : capacités sans
`generator`, donc `GET …/retouch` répond `ENGINE_UNAVAILABLE` et la page n'affiche rien. Les specs
**bouchonnent** les deux endpoints (`page.route`), comme celles du générateur.

---

## 9. Tests

Ce lot écrit les tests ; aucun n'est lancé à la conception.

### 9.1 Backend

`FakeRouteGeneratorGateway` (`@Mock`, couture `exchange` **(lu)**) gagne : `editEnabled` (le bloc
`generator.edit` dans les capacités, et `apiVersion` 1.17), `EDIT_PROBLEMS` (file de problèmes RFC 9457),
`EDITS` (corps reçus, pour vérifier le JSON envoyé), et une réponse synthétique : pour `resize`, la
polyligne reçue avec un aller-retour inséré au milieu, de la longueur voulue ; pour `move_end`, la
polyligne reçue jusqu'à son milieu puis un segment droit jusqu'au point. Les seeders
`NetworkEdgesSeeder`/`NetworkEdgesFixtures` **(lu)** posent un document courant ; un aide pose
`raw_geometry`.

`api/routes/RouteRetouchResourceTest` :

1. Anonyme → 401 ; parcours d'une équipe privée, non-membre → 404 ; membre sans droit de création →
   `POST` 403, `GET` 200 `NOT_ALLOWED` ; planificateur éteint → `GET` `NOT_ALLOWED`, `POST`
   `ROUTE_PLANNER_DISABLED`.
2. `enabled=false` → `GET` `ENGINE_UNAVAILABLE`, `POST` `ROUTE_PLANNER_DISABLED`, aucun appel.
3. Moteur sans `generator.edit` (api 1.16) → `GET` `ENGINE_UNAVAILABLE`, `POST` 503
   `GENERATOR_UNAVAILABLE`, `EDITS` vide.
4. `NOT_READY` : aucun document ; `rev` d'un ancien fichier d'origine ; `v` ancien ; `raw_geometry` nul.
5. `UNSUPPORTED` : deux traces ; `too_short` ; plus de `points_max` points ; parcours supprimé.
6. Validation : ni l'un ni l'autre, les deux ; `end` vide ou à deux clés ; `placeId` d'une autre équipe
   (et d'un autre domaine) → `VALIDATION` `end.placeId`.
7. Bornes avant l'appel : +40 % → `CHANGE_TOO_LARGE`, +500 m → `CHANGE_TOO_SMALL`, `EDITS` vide, la
   fenêtre de demandes **non** consommée.
8. Succès `resize` : 200, cartes, `targetDistanceM`, `originalAscentM` ; le corps envoyé porte la trace
   brute encodée, `network_edges` **octet pour octet** le texte stocké, `ride_type` du parcours, curseur
   0,25, graine ; en-têtes d'équipe.
9. Succès `move_end` par lieu : le point envoyé est celui du lieu.
10. `MIXED` → `gravel` ; sans type → `road`.
11. Fenêtre partagée : 30 générations puis une retouche → 429 avec `Retry-After`, et l'inverse.
12. Axe : un document posé par la vraie chaîne de test (`FakeRouteDetailsGateway`, arêtes synthétiques)
    a un `len` égal, à 0,5 % près, à la longueur haversine de `raw_geometry` (le supposé du §4.3).
13. Aucun quota tiré : le compteur du planificateur de l'équipe est inchangé.
14. Chaque raison du moteur (paramétré) → le code du §5, raccourcir et allonger séparés ; toutes les
    propositions écartées par `checkEdit` → `NO_SHORTER` / `NO_PROPOSAL`.
15. La réponse ne contient ni nom ni id de membre.

Unitaires : `RouteRetouchErrorsTest` (chaque `EditReason` × sens, chaque `Kind`) ;
`GeneratedRouteSanityTest` (`checkEdit` : chaque contrôle, un saut de 15 km dans la partie gardée
accepté, dans le tronçon neuf refusé) ; `RouteDetailsCapabilitiesTest` (bloc `edit` présent, absent, api
1.16) ; `RouteGeneratorGatewayHttpTest` (`edit` : chemin, en-têtes, document recopié brut, problème 422
lu avec sa raison, 413 en `UNEXPECTED`).

Commandes (exception accordée pour ce lot) :
`mvn test -Dtest='RouteRetouch*Test,GeneratedRouteSanityTest,RouteDetailsCapabilitiesTest,RouteGeneratorGatewayHttpTest,RouteGeneratorResourceTest,ArchitectureTest'`,
puis `mvn -q clean package -DskipTests` pour régénérer le contrat (que `mvn test` réécrit), et
`git diff --stat contracts/` : seul `openapi.*` doit y figurer, avec les seuls ajouts de ce lot.

### 9.2 Site (Vitest)

- `lib/routeRetouch.test.ts` : bornes (arrondi vers l'intérieur, plafond), zone morte, requête (une seule
  clé, `placeId` ou `point`), `isShortening`, `changedCoords` (bornes incluses, `TRUNCATE`), passage au
  planificateur (nom, type), **chaque** code → sa clé (et `NO_SHORTER` nomme la distance), ensemble non
  réessayable, lien du générateur (distance bornée 10–200 km, départ).
- `RouteRetouchModal.test.tsx` (sur le modèle de `RouteGeneratorPanel.test.tsx` **(lu)**) : le mode du
  menu ; champ borné et zone morte ; l'aide du raccourcissement ; `NO_SHORTER` en info avec « Déplacer
  l'arrivée » qui change de mode et « Ouvrir le générateur » ; `ORDER_ANOMALY` ; « Autres propositions »
  → graine 1 ; « Ouvrir dans le planificateur » → `navigate` avec l'état attendu.
- `RetouchedRouteCard.test.tsx` : avant → après, D+ absent, variantes, `TRUNCATE`, part gardée.
- `RouteDetailPage` (test existant ou nouveau) : bouton absent sans offre, désactivé pour `NOT_READY`,
  menu limité aux opérations offertes, rien pour un parcours supprimé ni une personne anonyme.
- `catalogues.test.ts` (existant) passe avec les clés fr/en.

### 9.3 e2e bouchonné — `frontend/e2e/route-retouch.e2e.ts`, écrit, **non lancé**

1. Personne qui organise, pile réelle : l'offre répond `ENGINE_UNAVAILABLE`, la page n'a pas de bouton
   « Retoucher » (un appel réel, sans bouchon).
2. Offre et `POST` bouchonnés, `resize` : menu, champ, « Proposer » ; trois cartes, avant → après ; le
   corps envoyé porte `targetDistanceKm` et `seed: 0` ; « Autres propositions » envoie `seed: 1` ; le
   tronçon surligné est peint (`traceMapPixels`).
3. Raccourcir refusé (`ROUTE_RETOUCH_NO_SHORTER`) : message info, « Ouvrir le générateur » mène à
   `/equipes/{slug}/parcours/generer` avec `d` et `s`.
4. `move_end` par un lieu de l'équipe : la requête porte `end.placeId`.
5. « Ouvrir dans le planificateur » : `/parcours/nouveau`, la proposition chargée, aucun appel au
   routeur, nom « … (retouché) ».
6. Membre sans droit de création, pile réelle : `NOT_ALLOWED`, aucun bouton.
7. `NOT_READY` bouchonné : bouton désactivé, bulle.
8. `ROUTE_RETOUCH_ORDER_ANOMALY` : message dédié.

---

## 10. Ce qui ne change pas

Le générateur (`POST …/route-generator`) et ses réponses ; la surcouche de nuit ; `network_edges`,
son calcul et ses rattrapages ; le planificateur (hors du nom de l'import) ; l'app mobile (seul son
client généré suit le contrat) ; aucune migration Flyway ; aucun réglage nouveau hors
`pedalons.route-generator.edit-timeout` (défaut `PT35S`, dans `application.properties`).

---

## 11. Registre

À faire **dans le commit du lot**, par `node scripts/ledger.mjs`, puis `index` et `check` :

- **`API-212`** (mis à jour) : retirer `kind: decision` (décidé le 22 novembre, lots du moteur codés) ;
  à la livraison du lot 4, `status: done`, `done:` la date, « Livré » au passé : les deux endpoints,
  contrat `16.6.0`, la règle du §4, la table du §5, les tests du §9.1 ; à ne pas défaire : l'offre lue
  dans les capacités, la trace brute et le document recopié tel quel, aucun calcul à la volée, la
  fenêtre partagée. Liens vers cette note, l'entrée `WEB` et l'entrée `OPS`.
- **Nouvelle entrée `WEB`** (`node scripts/ledger.mjs new WEB "Retoucher un parcours sur le site :
  ajuster la distance, déplacer l'arrivée" --size M`) : « Reste à faire » le §7 ; à la livraison,
  « Livré » avec les tests du §9.2 et la spec du §9.3 **non lancée** (le dire) ; si la spec n'a pas
  tourné, l'entrée garde une partie ouverte ou une entrée `kind: recette` la suit.
- **Nouvelle entrée `OPS`** (`node scripts/ledger.mjs new OPS "Mettre en service osm-route-details
  1.18.0 (retouche, api 1.17)" --size S`, `kind: externe`) : image publiée, épinglée dans
  `docker-compose.shared.yml`, déployée par le propriétaire ; à la recette, lire
  `ord_generator_edit_requests_total` (part de `order_anomaly` et `route_mismatch` : au-delà de 10 %,
  la piste du §15.3 de la note du moteur), `ord_generator_edit_stage_seconds{stage="match"}` (cache des
  poses au-delà de 200 ms au P90), et la mémoire de l'index (`ORD_GENERATOR__EDIT_INDEX_CACHE_MB`, 64) ;
  vérifier que la page d'un parcours prêt offre l'action dans l'heure. Section « The route generator » de
  `docs/OPERATIONS.md` à compléter (capacité `edit`, métriques).

Les numéros sont pris par `ledger.mjs new` au moment du lot (les plus hauts aujourd'hui : `WEB-200`,
`OPS-68`). La ligne de la retouche dans le tableau du `CLAUDE.md` racine suit (lot 7c, endpoints,
contrat).

---

## 12. Choix pris par défaut, que le propriétaire peut changer

| # | Question | Défaut retenu (le plus prudent) | Autre choix |
|---|---|---|---|
| P1 | « Remplacer l'ancien » (plan §8) | **Non au lot 7c** : la proposition ouvre un **nouveau** parcours ; l'original et ses sorties ne bougent pas | ouvrir la proposition dans la page d'édition du parcours (`EditRoutePage` lirait le passage, comme `CreateRoutePage`) |
| P2 | Type d'un parcours `MIXED` | `gravel` (autorise route et chemin, comme le parcours) | `road`, ou refuser |
| P3 | `UNSUPPORTED` sur la page | rien d'affiché | bouton désactivé avec la raison |
| P4 | `NOT_READY` sur la page | bouton désactivé, bulle | rien d'affiché |
| P5 | Curseur « routes de l'équipe / découverte » | absent de l'écran, 0,25 envoyé | le curseur du générateur dans la fenêtre |
| P6 | Droits | lire le parcours et planifier dans l'équipe (plan §7) | exiger aussi `canEdit` du parcours |

---

## 13. Relevé du backend codé (24 novembre 2026) : écarts à la conception

Backend codé, **aucun test lancé** (voir la réponse de l'agent : le lancement a été refusé, la règle du dépôt interdit de lancer les
tests backend). Contrat `16.6.0` régénéré (`mvn clean package -DskipTests`), clients web et mobile régénérés, `pnpm typecheck`,
`e2e:typecheck`, `lint`, `i18n:check` et `catalogues.test.ts` verts. Écarts :

- **Passerelle** : `RouteGeneratorGateway.edit(String team, byte[] body)` plus `bodyOf(EditRequest)`, et non `edit(team, EditRequest)` :
  le corps est sérialisé une fois, sa taille jugée avant la fenêtre de demandes.
- **Ordre** : la taille du corps (étape 9) est jugée **avant** `guard.admit` (étape 8), pour ne pas consommer la fenêtre pour un refus gratuit.
- **`no_seam`** : en raccourcissant, `ROUTE_RETOUCH_NO_SHORTER` (le moteur le liste parmi les échecs du raccourcissement) ; sinon
  `ROUTE_RETOUCH_UNSUPPORTED` comme au §5. Idem `junction_cut` et `end_unreachable` en raccourcissant. `OVERLAY_REQUIRED` : `GENERATOR_UNAVAILABLE` (dérive).
- **Longueur de l'offre** : `ST_Length(raw_geometry::geography, false)` (sphère, à un millionième de la haversine), pas l'ellipsoïde.
- **Modèle `Availability`** : champ `edit` ajouté, constructeurs précédents gardés.
- **Moteur factice** : `editEnabled` est à `false` par défaut (un moteur 1.17.x) ; pas de lien à `apiVersion`.
- **Tests non écrits** : §9.1-12 (l'axe `fm`/`tm` contre la haversine de `raw_geometry`, toujours **supposé**), le parcours supprimé et les deux traces
  (remplacés par `points_max` et `too_short`), `RouteDetailsCapabilities` testé sans la passerelle HTTP. Aucun test lancé.
- **Registre** : `API-212`, l'entrée `WEB` et l'entrée `OPS` ne sont pas touchées par ce lot backend.

---

## 14. Relevé du site codé (24 novembre 2026) : écarts à la conception

Site codé, **Vitest lancé** (`lib/routeRetouch.test.ts`, `RouteRetouchModal.test.tsx`, `RetouchedRouteCard.test.tsx`,
`RouteRetouchButton.test.tsx`), `e2e/route-retouch.e2e.ts` **écrit, non lancé**. Écarts :

- **Le `POST` est une mutation générée** : `useRouteRetouch` enveloppe `retouchRoute` dans un `useQuery` (clé
  `['routeRetouch', team, route, request]`), comme `useRouteGenerator`.
- **Pas de `generatedRouteName`** pour l'import : `generatedHandoffSchema` gagne `name` facultatif, `RouteEditor` le préfère.
- **La page lit `GET team`** (`useRouteDetailData().team`) pour le quota du planificateur : « Ouvrir dans le planificateur » est
  désactivé, avec « Les enregistrements de tracés du mois sont épuisés. », quand il l'est (la page de création ignorerait sinon le passage en silence).
- **Une fenêtre `Modal` Mantine** (`size="xl"`, plein écran sous 48 em), pas `MapFullscreenShell`.
- **Le tronçon changé** en orange `#e8590c` (`CHANGED_COLOR`) sur un liseré blanc ; le cercle de `endSnapM` autour de l'arrivée posée
  est un `fill` (fonction pure `circleCoords`). Un `TRUNCATE` n'a pas de tronçon à surligner : un marqueur de fin au point de coupe.
- **Un tap sur la carte** pose l'arrivée dans tout le mode « Déplacer l'arrivée », même si un lieu est choisi (le lieu est alors lâché).
- **Textes** : `card.kept` et `errors.changeTooLarge` reçoivent un pourcentage déjà formaté (`percent()` ajoute le « % »). Clés ajoutées au plan :
  `resize.outOfRange`, `moveEnd.clickHint`, `card.title`, `errors.invalidRequest`, `errors.generic`.
- **Non fait** : un test de `RouteDetailPage` (le bouton est testé seul) ; le test du retour au cache d'une graine déjà vue.
