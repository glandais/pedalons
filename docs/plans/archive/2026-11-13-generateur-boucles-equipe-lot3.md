# Team route generator, lot 3: team graph cache, endpoint, `excludedFromGenerator`

Lot 3 of ledger `API-198`. Parent plan: [`2026-11-13-generateur-boucles-equipe.md`](2026-11-13-generateur-boucles-equipe.md)
(§2 guarantees, §3.3 sources, §5.5 types, §6 contract, §9 tests, §10 decisions 3, 4, 8, §11 lots).
Inputs: lot 1 ([`…-lot1.md`](2026-11-13-generateur-boucles-equipe-lot1.md), `NetworkEdgesDocument`
in `gpx_tracks.network_edges`, `V91`) and lot 2
([`…-conception-lot2.md`](2026-11-13-generateur-boucles-equipe-conception-lot2.md), the pure engine in
`service/route/generator/`; §12 is the normative part, §12.1 the mapping rules).

Written 14 November 2026. Status: **design, not coded**. Contract `14.13.0` → **`14.14.0`**
(checked in `application.properties` on 14 November 2026). Last migration `V91`; renumbered after the rebase over `API-199` (which took `V92` and `14.13.0`), this lot takes
**`V93`**.

Paths are relative to `backend/src/main/java/fr/pedalons/` unless stated otherwise.

---

## 0. Decisions in one screen

| Question | Decision |
|---|---|
| Sources | Every track row of every **non-deleted** `Route` of the team (any visibility, any status, moderation-hidden included: plan §3.3 says "non supprimés", nothing else). Only `team_entities.entity_type = 2` joined to `gpx_tracks`; GPX previews and anything attached to a ride never appear in that join. |
| Current document | Used only when `v == NetworkEdgesDocument.VERSION`, `status` is `ok` or `too_short`, and `rev` equals the route's current `ROUTE_ORIGINAL_GPX` `file_id` (the lot 1 rule). Anything else makes the track **pending**. |
| Cache | One programmatic Caffeine cache per instance, key `teamId`, value = graph + summary + **fingerprint**. Bounded by weight (estimated bytes, default 192 MB), `expireAfterAccess` 2 h, `expireAfterWrite` 6 h (backstop only). |
| Staleness across instances | **No event-based invalidation.** Every request runs one cheap fingerprint query (aggregates over narrow columns, no JSONB detoasting) and compares it to the cached one. Works the same for writes made by this instance, the other instance of a rolling deploy, or the previous release. Route-level changes rebuild at once; track/document-level changes rebuild once the cached graph is older than 10 min (§2.4). |
| Build | **One** native statement over `gpx_tracks` of the team's live routes, streamed (fetch size 32), each JSONB parsed and mapped row by row, geometries and nodes interned. One build at a time per instance (memory). |
| Endpoint | `POST /api/teams/{teamSlug}/route-generator`, rights `PlannerAccess.check(teamSlug)` (not `checkRouting`: nothing billed, no quota drawn), not transactional, no DB connection held while computing. |
| CPU | A per-user in-memory sliding window (30 per 15 min) → 429 `ROUTE_GENERATOR_RATE_LIMITED`; a per-instance semaphore (default `max(1, cores / 2)` permits, 2 s wait) → 503 `ROUTE_GENERATOR_BUSY`; a 5 s wall-clock stop inside the engine → 503 `ROUTE_GENERATOR_BUSY`. |
| Engine change | One, needed by the adapter: an optional stop signal (`BooleanSupplier`) polled per turning point, per polygon evaluation and per checked candidate. Without it, nothing bounds a single request's CPU time. The default overload never stops, so lot 2's results and tests are unchanged (§3.6). |
| `excludedFromGenerator` | `V93` adds `team_entities.excluded_from_generator boolean not null default false`. `RouteRequest` gets an optional `Boolean` (null means unchanged on update, false on create). `RouteDetailDto` gets the field, always sent, **not marked required** in the schema so that no mobile or web fixture has to change (§4). |
| Error details | Only `GENERATOR_NETWORK_TOO_SMALL` carries details (the network summary, so the site can say "analysis still running"). The other `GENERATOR_*` codes carry none. |

---

## 1. Mapper `NetworkEdgesDocument` → `TrackInput`

`service/route/network/TrackInputMapper` is a pure class with no CDI, unit-tested. One instance per
build, because it holds the intern tables.

```java
final class TrackInputMapper {
  TrackInputMapper(int maxPointsPerEdge);                 // 20 000 (PolylineCodec budget)
  TrackInput map(long trackId, boolean excluded, TrackKind kind, NetworkEdgesDocument doc);
  int droppedEdges();                                     // for the log and the metrics
  long distinctPoints();                                  // for the cache weigher
}
```

`kind`: `Route.surfaceType` maps one to one (`ROAD`, `GRAVEL`, `MTB`, `MIXED`). A null value
(the column is `@NotNullableDbValue`, but old rows may hold null) maps to `MIXED`.
`excluded`: `Route.excludedFromGenerator`. Excluded tracks **are** passed. The builder uses them
to shape node merging and never as support (lot 2 `TrackInput` javadoc, plan §10.8). Deleted routes
are never passed.

Per `NetworkEdgesDocument.Edge`, following lot 2 §12.1:

| `TrackEdge` | From | Rule |
|---|---|---|
| `from` / `to` | `nodes[fn]` / `nodes[tn]` | `NodeRef(id, LatLon(lat, lon), degree)`, **interned by `id`** for the whole build (one object per street node). Absent `fn`/`tn`, or an index outside `nodes`, gives `null` (unknown end). |
| `partial` | `p` | as is |
| `lengthM` | `len` | as is, null stays null. Not reconciled with `from`/`to`: the builder classifies an inconsistent edge (§12.3 step 0). |
| `traversedM` | `trv` | an edge with `trv < 0` or a non-finite value is **dropped** and counted, since the record's compact constructor would throw |
| `fromOffsetM` / `toOffsetM` | `fo` / `to` | as is |
| `oneway` | `ow` | `both` → `BOTH`, `forward` → `FORWARD`, `against` → `AGAINST`; **absent or unknown → `FORWARD`**: allowed only in the direction the team rode it, the conservative reading of plan §4 |
| `geometry` | `g` | `PolylineCodec.decode2Within(g, maxPointsPerEdge)` (precision 6, `[lng, lat]` → `LatLon(lat, lng)`), **as is**: never extended to a node, never replaced by a chord. **Interned by the encoded string**: the decoded list goes through `List.copyOf` once and is shared. `TrackEdge`'s own `List.copyOf` returns that same instance, so complete edges ridden by hundreds of routes are held once. Absent, undecodable, over budget or fewer than 2 points: the edge is dropped and counted. |
| `gainM` / `lossM` | `tg − fg` / `tl − fl` | as is (cumulative values: the difference is ≥ 0 for well-formed input; the builder uses it unclamped) |
| `surface` | `sc`, `sd`, `ss` | null when `sc` is absent. Otherwise `EdgeSurface(class, detail, source)`, with `paved`/`unpaved`/`unknown` → enum and any other value → `UNKNOWN`. `sd` is lowercased and passed as received (open list). `ss` maps `tagged`/`inferred_tracktype`/`inferred_highway`, and absent or unknown → `NONE`. |
| `wayKind` | `wk` | absent → null; `major_road`… → enum by upper-cased name; unknown → `UNKNOWN` |
| `trackType` | `tt` | `grade1`…`grade5` → enum; absent or unknown → null (api 1.8, absent today) |
| `bicycle` / `foot` | `bi` / `ft` | `yes`/`limited`/`no` → enum; absent or unknown → null (**not** forbidden) |

Not mapped: `fm`, `tm`, `st`, `unmatched`, `covered`, `dv`, `api`, `rules`. A `too_short` document
maps to a `TrackInput` with no edges. Edges keep the document order. Tracks are emitted sorted by
`trackId`, which the build query's `order by` gives (the builder sorts anyway).

Unknown enum strings never throw (forward compatibility, §12.1). An edge-level problem drops that
edge, never the track or the team graph. A document that fails to parse (JSON error) makes its track
**pending**, logged once per build at WARN with the track id.

---

## 2. Team graph cache

### 2.1 Classes

```
service/route/network/
  package-info.java            @NullMarked
  TrackInputMapper             §1
  TeamNetwork                  record(Fingerprint fingerprint, NetworkGraph graph,
                                      TeamNetworkSummary summary, Instant builtAt, long weightBytes)
  TeamNetworkSummary           record(int routeCount, int pendingRouteCount, int excludedRouteCount,
                                      double totalLengthM, int droppedEdges)
  TeamNetworkCache             @ApplicationScoped: Caffeine cache, single-flight build, §2.3–2.5
repository/route/TeamNetworkRepository   fingerprint and streamed build query, §2.2
```

`NetworkGraphBuilder.build(tracks, NetworkParameters.defaults())`. The parameters are not
configurable in this lot; the bench tunes them in code.

### 2.2 Queries (both native, both filtered by domain)

**Fingerprint**, run on every request:

```sql
with r as (
  select te.id, te.version
  from team_entities te
  join teams tm on tm.id = te.team_id
  where te.team_id = :teamId and tm.domain_id = :domainId and te.entity_type = 2)
select (select count(*) from r)                       as routes,
       (select coalesce(sum(version), 0) from r)      as route_versions,
       count(t.id)                                    as tracks,
       coalesce(sum(t.id::numeric), 0)                as track_ids,
       coalesce(sum(t.version), 0)                    as track_versions,
       count(t.network_edges)                         as documents,
       coalesce(sum(pg_column_size(t.network_edges)), 0) as document_bytes
from r join gpx_tracks t on t.route_id = r.id
```

Why each column:

- Deleted routes are **included**, so a delete, an undelete or a moderation removal bumps
  `route_versions` (Hibernate `@Version` on `BaseEntity`).
- `route_versions` catches every Hibernate update of a route row. That covers
  `excludedFromGenerator`, `surfaceType` (which changes `TrackKind`), `deleted`, and saves.
- `tracks`, `track_ids`: a GPX change replaces the track rows (new TSIDs), and a removed row lowers
  the count.
- `track_versions`: the HD catch-up rewrites the track's points through the entity (`applyRecompute`),
  in the same transaction as its `updateNetworkEdges`.
- `documents`, `document_bytes`: `updateNetworkEdges` is a native update that bumps neither
  `updated_at` nor `version`. It is caught here: null → document changes `documents`, and a rewrite
  almost always changes the stored size. `pg_column_size` reads the TOAST pointer's size **without
  detoasting**. To confirm on the migrated base: `EXPLAIN (ANALYZE, BUFFERS)` must show no TOAST block
  reads. It is also what makes the previous release's writes visible: lot 1 is live and writes these
  documents too.
- Timestamps are deliberately absent: `updated_at` comes from each JVM's clock, and two instances
  can disagree on it.

Cost: index scans on `team_entities(team_id, deleted)` and `idx_gpx_tracks_route`, narrow
columns, a few ms for 2,656 routes. It is never cached.

`Fingerprint` is a record of the seven numbers, split into `routePart` (the first two) and
`trackPart` (the other five) for §2.4.

**Build**, one statement per build:

```sql
select t.id, te.id, te.surface_type, te.excluded_from_generator,
       (select a.file_id from assets a
         where a.team_entity_id = te.id and a.type = 'ROUTE_ORIGINAL_GPX'
         order by a.id desc limit 1)                  as original,
       t.network_edges::text
from team_entities te
join teams tm on tm.id = te.team_id
join gpx_tracks t on t.route_id = te.id
where te.team_id = :teamId and tm.domain_id = :domainId
  and te.entity_type = 2 and not te.deleted
order by t.id
```

The correlated subquery is the rule of `AssetRepository.findCurrentFileId`, inside the same
statement (`idx_assets_team_entity`). It runs in its own short read-only transaction
(`QuarkusTransaction.requiringNew()`), with `getResultStream()` and the `org.hibernate.fetchSize`
hint set to 32, so that the PostgreSQL driver uses a cursor. Each row's text is parsed with
hypersistence's `ObjectMapper` (the one that wrote it), checked as current (§0), mapped (§1), then
dropped. The whole team's JSON (≈ 270 MB of text for the largest team) is never held at once.

Per-route status, computed while streaming:

- **counted**: not excluded, ≥ 1 track, every track current;
- **pending**: not excluded, ≥ 1 track without a current document;
- **excluded**: `excluded_from_generator`. Its current tracks are still passed as `excluded = true`.

Current tracks of a pending route are passed anyway, since their edges are valid.

### 2.3 Bounds

| Key | Default | Meaning |
|---|---|---|
| `pedalons.route-generator.cache.max-weight-mb` | 192 | Caffeine `maximumWeight` (bytes) |
| `pedalons.route-generator.cache.expire-after-access` | `PT2H` | an idle team frees its memory |
| `pedalons.route-generator.cache.expire-after-write` | `PT6H` | backstop for a change no fingerprint column sees (§2.5) |
| `pedalons.route-generator.cache.min-rebuild-interval` | `PT10M` | §2.4 |

Weigher: `nodeCount · 120 + edgeCount · 400 + geometryPoints · 48 + Σ support · 8` bytes, where
`geometryPoints = Σ_e graph.geometryX(e).length`, computed once after the build. That costs one
transient copy per edge and needs no engine change. A graph heavier than the maximum weight is
evicted at once by Caffeine, so the next request rebuilds. That is logged at WARN with the
estimate, the signal to raise the bound.

Caffeine is used directly (`com.github.ben-manes.caffeine:caffeine`, version from the Quarkus
BOM, declared explicitly in `pom.xml`). `quarkus-cache` configuration has no weigher, and
`@CacheResult` cannot express "replace when the fingerprint differs".

**Memory warning.** Container 1,536 MB → heap ≈ 920 MB (`JAVA_MAX_MEM_RATIO` 60 %). Estimates for
the largest team (162,000 km of traces, a few thousand km of network): the graph is about 50 MB.
The build peaks at about 300 MB: about 1 million transient `TrackEdge` with their boxed `Double`s,
plus the builder's work arrays, with geometries and nodes interned. During a rebuild the old graph
stays cached until it is replaced. Hence **one build at a time per instance**
(`buildPermits = new Semaphore(1)`, waited on for up to 30 s, else 503 `ROUTE_GENERATOR_BUSY`).
Measure on the real-data bench before the site opens. If the peak is higher, raise
`BACKEND_MEMORY` (2 GB) rather than shrink the bounds.

### 2.4 Lookup, single flight, rebuild policy

```
lookup(team):
  fp = repository.fingerprint(team.id, domainId)            // 1 statement
  cached = cache.getIfPresent(team.id)
  if cached != null and cached.fp == fp: return cached       // hit
  if cached != null and cached.fp.routePart == fp.routePart
       and now − cached.builtAt < minRebuildInterval:
     return cached                                           // track-level change, deferred
  lock(team.id)                                              // 64 striped ReentrantLocks
    cached = cache.getIfPresent(team.id)                     // double-check
    if cached != null and acceptable(cached, fp): return cached
    acquire buildPermits (30 s) else 503 ROUTE_GENERATOR_BUSY
    built = build(team, fp)                                  // 1 statement, streamed
    cache.put(team.id, built); return built
```

`acceptable` is the hit test plus the deferral test above, against the fingerprint read before
taking the lock.

- **Route-level changes rebuild on the next request**: save, delete, undelete, moderation removal,
  `excludedFromGenerator`, surface type. The fingerprint's route part is the route count plus a sum of
  a hash of `deleted`, `excluded_from_generator` and `surface_type`, **not** `sum(version)`.
- **Track/document-level changes alone wait up to `min-rebuild-interval`.** That covers the HD
  catch-up writing a new route's edges a minute after its save, the backfill filling documents at
  30 an hour (lot 1 §4.2), and an elevation recompute. Without the deferral, the backfill of the
  largest team would force a full rebuild (seconds, about 300 MB) every two minutes. A route save
  changes the route count, so it is never deferred. The HD catch-up also updates the route entity
  (distance, elevation, version) but none of the three hashed columns, so it is deferred like any
  track write. The new route is simply **pending** until its catch-up.
- A write committed between the fingerprint and the build gives a graph *newer* than its stored
  fingerprint. The next request rebuilds again: a wasted build, never stale data.
- Caches are per instance and never talk to each other. During a rolling deploy both instances
  compute their own graph from the same rows. The fingerprint is read from the database, so neither
  can serve the other's stale state.

### 2.5 Staleness bound (stated)

For a committed write made through any release on any instance:

| Change | Seen by the next request after commit, at the latest |
|---|---|
| Route created, deleted, undeleted, moderated, `excludedFromGenerator` or surface type changed | **at once** |
| Track rows replaced or updated, document null → written, document rewritten with a different stored size | **≤ `min-rebuild-interval` (10 min)** |
| Document rewritten in place with the same stored size and no version bump on its row | ≤ `expire-after-write` (6 h). **No current writer does this**: the HD catch-up updates the track entity in the same transaction, and the backfill only writes null or older-version documents. |

### 2.6 Network summary in the response

`network` (also the details of `GENERATOR_NETWORK_TOO_SMALL`):

- `lengthM`: road the search can reach around the start and the end (`Success.networkLengthM`,
  plan §6 "km de routes de la composante"); null on a failure, where the engine does not give it;
- `totalLengthM`: the whole team graph (`NetworkStats.totalLengthM`);
- `routeCount`, `pendingRouteCount`, `excludedRouteCount` (§2.2);
- `incomplete = pendingRouteCount > 0`.

Lengths are in metres, for consistency with the candidates (`distanceM`…). The site converts them
to km.

---

## 3. Endpoint

### 3.1 Resource

`api/routes/RouteGeneratorResource`, `@Path("/api/teams/{teamSlug}/route-generator")`,
`@RolesAllowed("user")`, `@Tag(name = "Route generator")`, one `@POST` with `operationId =
"generateRoutes"`. It is documented in the style of `RouterResource`: operation description with
every code, and one `@APIResponse` per status (200, 400, 401, 403, 404, 429, 503). It calls one
service method, `RouteGeneratorService.generate(teamSlug, request)`, annotated **`@Logged`**, like
`RouterService.getRoute`. The rights are checked inside, through `PlannerAccess`, which satisfies
`ArchitectureTest.api_calls_to_service_must_have_check_access`. The method is **not
`@Transactional`**.

### 3.2 Request (`dto/routes/request/RouteGeneratorRequest`, `@ValidateSchema`)

| Field | Type | Rule |
|---|---|---|
| `start` | `@Nullable @Valid GeoPoint` | Default: the team's location (`Team.geometry`). If both are absent → 400 `VALIDATION`, field error on `start`. |
| `end` | `@Nullable @Valid GeoPoint` | Default: `start`. Absent is passed to the engine as `end = null` (loop). |
| `bearing` | `@Nullable CompassPoint` | The existing `enums/CompassPoint` (`N`…`NW`, already in the contract, used by the wind). Mapped to `Bearing8` by name. Only used when the end is closer than D/2 (engine). |
| `distanceKm` | `double`, required, `@DecimalMin("10") @DecimalMax("300")` | → `distanceM = distanceKm · 1000` |
| `familiarity` | `@Nullable Double`, `@DecimalMin("0") @DecimalMax("1")` | default 0.5 |
| `type` | `@Nullable RouteGeneratorType` (`ROAD`, `GRAVEL`, `MTB`) | Default `ROAD`. A new enum in `enums/`, mapped to `RideType` by name; not `SurfaceType`, which has `MIXED`. |
| `seed` | `@Nullable Integer` | Default 0. An `int`, not a `long`: a JavaScript number keeps it exact. "Autres propositions" sends another value. |

### 3.3 Response (`dto/routes/response/…`, all `@ValidateSchema`)

`RouteGeneratorResponse`:

- `candidates`: `List<GeneratedRouteDto>`, 1 to 3, best first;
- `network`: `RouteGeneratorNetworkDto` (§2.6);
- `familiarityFallback`: `boolean`, true when the familiarity of all kinds replaced the requested
  type's (plan §5.5: "la réponse le signale").

`GeneratedRouteDto`, one per `GeneratedRoute`:

| Field | From |
|---|---|
| `polyline` | `PolylineCodec.encode2(points as [lng, lat])`: precision 6, latitude then longitude, the encoding of `GpxImportTrack.line` / `PlannerSource.line` |
| `distanceM`, `ascentM`, `descentM` | as is |
| `bearingDeviationDeg` | `@Nullable Double`, null when the bearing did not apply |
| `familiarity` | mean z, 0..1 |
| `unpavedShare` | 0..1 |
| `sharedM` | tail length (ridden twice, counted once) |
| `crossings` | `int` |
| `bounds` | `BoundsDto` (existing: `minLon`, `minLat`, `maxLon`, `maxLat`) computed from `points` |

`steps` and diagnostics are not exposed. A 300 km route at the snapped geometry's density is
around 30,000 points, well under `GpxLimits.MAX_PLANNER_POINTS` (100,000), so lot 4 can send it to
`POST /api/gpx-previews/from-points` as is.

### 3.4 Flow of `RouteGeneratorService.generate`

1. `plannerAccess.check(teamSlug)`. Rights first, then the planner flag, so a non-member learns
   nothing. Not `checkRouting`: no provider is called, so no daily routing count and no quota. The
   quota is drawn when the chosen route is **saved**, as for any drawn track (decision §10.3,
   `BILL-10`, nothing to do here).
2. `pedalons.route-generator.enabled` (default `true`): off → 400 `ROUTE_PLANNER_DISABLED`. It is
   a kill switch per environment, before the bench has validated memory.
3. Rate limit (§3.5), counted once rights are known. A refused request costs nothing.
4. Resolve start, end, bearing, type, familiarity, seed. Build `GeneratorRequest`.
5. `teamNetworkCache.lookup(team)` (§2.4): 1 statement, plus 1 on a rebuild.
6. If the graph has no edge → `GENERATOR_NETWORK_TOO_SMALL` with the summary. Without this,
   the engine would answer `START_TOO_FAR` on an empty network, which is misleading.
7. Acquire a generator permit (§3.5), then
   `routeGenerator.generate(graph, request, deadline(5 s))`, then release the permit in `finally`.
8. `Success` → response. `Failure` → exception (§3.6). One INFO log line per request: team id,
   D, type, loop or not, outcome or code, `detail`, timings (fingerprint, build if any, generate),
   candidate counts from `GeneratorDiagnostics`. **No coordinates**: a start point is often
   someone's home.

No DB connection is held during step 7. Steps 1–5 run statement by statement or in their own short
transactions, as `RouterService` does.

`RouteGenerator` is a single `@ApplicationScoped` producer (`new RouteGenerator()`, defaults). It is
stateless and thread-safe, and `NetworkGraph` is immutable, so one cached graph serves concurrent
requests.

### 3.5 CPU guards

`service/route/network/RouteGeneratorGuard` (`@ApplicationScoped`):

| Key | Default | Effect |
|---|---|---|
| `pedalons.route-generator.rate.max-per-window` | 30 | per user |
| `pedalons.route-generator.rate.window-minutes` | 15 | sliding window |
| `pedalons.route-generator.max-concurrent` | `max(1, availableProcessors / 2)` (0 = that) | generator permits per instance |
| `pedalons.route-generator.permit-wait` | `PT2S` | wait for a permit, else 503 |
| `pedalons.route-generator.time-budget` | `PT5S` | engine stop (§3.6) |
| `pedalons.route-generator.build-wait` | `PT30S` | wait for the build permit |

- **Rate limit**: a Caffeine map `(domainId, userId)` → a small ring of timestamps (≤ 30 `long`),
  `expireAfterAccess = window`. Past the limit →
  `TooManyRequestsException(ROUTE_GENERATOR_RATE_LIMITED, secondsUntilOldestLeaves)`, so 429 with
  `Retry-After` through `GlobalExceptionMapper`, like every other limiter. A platform admin is
  **not** exempt: this protects CPU, not a quota.
  It is **in memory, not a table**, unlike `router_daily_calls` or the feedback and ad counters,
  and on purpose. What it protects is the CPU of the instance that serves the request. There is
  one replica, two only during a deploy, so the bound is at worst doubled for a minute. A database
  counter would cost a write transaction per request plus a migration and a purge, to protect a
  resource that is not shared. Counters reset on restart, which is acceptable for a CPU guard.
- **Concurrency**: `Semaphore(maxConcurrent, fair = true)`, `tryAcquire(permitWait)`, else
  `ServiceUnavailableException(ROUTE_GENERATOR_BUSY)` → 503. The request runs on its own blocking
  worker thread. The rest of Quarkus's worker pool stays free, and at most `maxConcurrent` cores
  are spent on generation.
- **Time budget**: §3.6. Measured lot 2 times are 0.3 to 2.5 s per `generate` on a grid of 51,000
  edges (§12.13). 5 s leaves room on real data and is re-tuned on the bench.

### 3.6 Engine change needed by the adapter: a stop signal

**Why.** The engine bounds its *work* (budgets for turning points and polygon evaluations) but not
its *time*. On a large network, or on a slow host during a deploy, a single request may run for
seconds. A permit held that long starves the others, and the request cannot be interrupted from
outside: the loops never check `Thread.interrupted()`. A wall clock must therefore be checked
*inside* the loops.

**What.** In `service/route/generator/`:

- `public GeneratorResult generate(NetworkGraph graph, GeneratorRequest request, BooleanSupplier
  stop)`. The existing `generate(graph, request)` calls it with `() -> false`.
- `QueryContext` keeps `stop`. `ctx.checkStop()` throws `GeneratorStoppedException` (new, public,
  unchecked) when `stop.getAsBoolean()`.
- Polled at three coarse points: once per turning point (`LoopFamily`, the `for (int t :
  eligible)` loop), once per polygon evaluation (`PolygonFamily`, the `while (evaluations < …)`
  loop), and once per candidate in the checker loop of `RouteGenerator.generate`.

**Behaviour.** A run that is not stopped is the same computation, so results are identical and
deterministic, and all lot 2 tests are unchanged. A stopped run returns **nothing**, never the
candidates found so far: a partial answer would depend on machine speed and break "same seed, same
routes". The adapter maps the exception to 503 `ROUTE_GENERATOR_BUSY` and logs D, type and the
elapsed time at WARN, so the bench can be re-tuned.

### 3.7 Errors

New `ErrorCode` values, each with a javadoc in the style of the existing ones:

| Code | Status | Thrown as | From |
|---|---|---|---|
| `GENERATOR_START_TOO_FAR` | 400 | `BusinessException` | `START_TOO_FAR` (no admitted team road within 2 km) |
| `GENERATOR_END_TOO_FAR` | 400 | `BusinessException` | `END_TOO_FAR` |
| `GENERATOR_DISTANCE_TOO_SHORT` | 400 | `BusinessException` | `DISTANCE_TOO_SHORT` |
| `GENERATOR_NETWORK_TOO_SMALL` | 400 | `BusinessException` + `RouteGeneratorNetworkDetails` | `NETWORK_TOO_SMALL`, and an empty graph (§3.4 step 6) |
| `GENERATOR_NO_ROUTE` | 400 | `BusinessException` | `NO_ROUTE`, whatever the `detail` (`END_UNREACHABLE`, `TAIL_TOO_LONG`, `NO_APPROACH`, `NO_WAY_BACK`, null), which is logged and not exposed |
| `ROUTE_GENERATOR_RATE_LIMITED` | 429 + `Retry-After` | `TooManyRequestsException` | §3.5 |
| `ROUTE_GENERATOR_BUSY` | 503 | `ServiceUnavailableException` | no permit in time, build permit in time, or stopped (§3.5–3.6) |
| `ROUTE_PLANNER_DISABLED` | 400 | existing | `PlannerAccess.check`, kill switch |

The mapping is one exhaustive `switch` over `GeneratorFailure` (`RouteGeneratorErrors.of(Failure,
TeamNetworkSummary)`), so a new enum value fails compilation. 400 is the status for consistency with
`ROUTING_NO_ROUTE`.

`RouteGeneratorNetworkDetails implements ErrorDetails` (`type` fixed to
`GENERATOR_NETWORK_TOO_SMALL`, registered in `ErrorDetails`' `@JsonSubTypes` and its
`discriminatorMapping`). It carries the §2.6 fields except `lengthM`. The site can then tell
"network too small" from "network still being analysed (`pendingRouteCount` routes left)". The
other codes carry no details: the discriminated union allows one class per code, and they need
none.

Rights, as `PlannerAccess.check` already decides them (asserted in `RouterImportResourceTest`):
unknown slug or another domain's team → 404. Non-member, or member without route creation (a
`MEMBER` who is not organizer) → **403**. Plan §9 says "non-membre 404". The existing rule gives
403, and this lot does not change `PlannerAccess`. **The owner should confirm 403.**

### 3.8 Contract

`pedalons.api.version=14.14.0` (minor: a new endpoint, new optional request field, new response
field, new enum values and error codes). Regenerate deliberately with the `contract-first-api`
skill (`mvn package -DskipTests`, then `pnpm generate-api` in `frontend/`, then the mobile
generator as the skill says), and keep `contracts/openapi.json` / `.yaml` and the generated clients.

---

## 4. `Route.excludedFromGenerator`

**Migration** `V93__route_excluded_from_generator.sql`:

```sql
-- docs/LEDGER_*.md API-198 (lot 3, plan docs/plans/2026-11-13-generateur-boucles-equipe-lot3.md §4):
-- "Ne pas utiliser pour générer des parcours" (plan §10.8). Routes live in the single table
-- team_entities, so every entity type gets the column, false for all but the routes that tick it.
-- Purely additive for the start-first rolling deploy: a constant default is metadata only on
-- PostgreSQL 11+, the previous release's inserts get false, and its updates do not list the column,
-- so they leave it as it is.
alter table team_entities
  add column excluded_from_generator boolean not null default false;
```

No index: the column is only read in the build query, already restricted to one team.

**Entity**: `Route` gets `@Column(name = "excluded_from_generator", nullable = false) private
boolean excludedFromGenerator = false;`.

**`RouteRequest`**: a new trailing component `@Nullable Boolean excludedFromGenerator`, with
`@Schema(description = "Ne pas utiliser pour générer des parcours: the route's roads do not feed
the team's route generator unless another route rides them. Omitted: false on a creation, left as
it is on an update")`. A new secondary constructor keeps the previous shape (the record's own
convention: "Without X: the shape this record had before API-198"), so the 71 test call sites,
`BiketeamMigrationService` and `RouteCopyService` compile unchanged.

**Null means unchanged** on update. That is required, not a convenience: the mobile route form and
any client older than `14.14.0` omit the field, and must not untick it on every save.

**`RouteService`**:

- `createRoute`: `route.setExcludedFromGenerator(Boolean.TRUE.equals(request.excludedFromGenerator()))`.
- `updateRoute`: `if (request.excludedFromGenerator() != null) route.setExcludedFromGenerator(…)`,
  next to `setSurfaceType`.

The rights are those of the route: `@CheckAccess(ROUTE, CREATE / UPDATE)` already guard both
methods, so whoever may edit the route may change the box (plan §10.8). No separate endpoint.

**`RouteCopyService.duplicate`**: the copy **keeps** the box. A copy of an event route is still the
event's route. This is a choice: a variant made from it may untick it.

**`RouteDetailDto`**: `boolean excludedFromGenerator`, always sent, `@Schema(description = …)`
**without `required = true`**. Mobile tests build `RouteDetailDto` in about ten fixtures
(`route_fixtures.dart`, `route_form_test.dart`, …), and freezed would make a required field a
`required` constructor argument. Web fixtures (`cardGallery/fixtures.ts`, `RoutesMapView.test.tsx`,
`RouteMapPanel.test.tsx`) would need it too. Clients read it as `?? false`. If the owner prefers
`required = true`, those fixtures get the field in the same change. `RouteDto` (list rows) does not
get it: lot 4 only needs it in the route form.

**Cache**: nothing to call. The change bumps the route's `@Version`, which the fingerprint sees
immediately (§2.5), on every instance.

---

## 5. Tests

Targeted runs only (`mvn -q test -Dtest='…'`). After each run, check that `contracts/` was not
rewritten by accident (memory note: tests rewrite `contracts/openapi.*`).

### 5.1 Unit (no Quarkus)

- `service/route/network/TrackInputMapperTest`: complete edge; partial with one unknown end;
  index outside `nodes` → null end; `ow` absent / unknown → `FORWARD`; every enum unknown →
  `UNKNOWN`/`NONE`/null without throwing; `sd` lowercased; `trv < 0` and undecodable `g` dropped and
  counted; `too_short` → no edges; **interning**: two documents with the same polyline string give
  the *same* `List` instance in their `TrackEdge`s, and the same `NodeRef` for the same node id;
  `MIXED` for a null surface type; gains as differences.
- `RouteGeneratorErrorsTest`: every `GeneratorFailure` maps to its code (parameterised over
  `values()`); `NETWORK_TOO_SMALL` carries the summary.
- `RouteGeneratorGuardTest` (with a fake clock): 30 admitted then 429 with the right
  `Retry-After`; the window slides; users and domains are independent; the permit wait times out
  → 503; permits are released on exception.
- `generator/RouteGeneratorStopTest`: `stop = () -> true` throws `GeneratorStoppedException`; a
  stop after N polls stops; `() -> false` gives results equal to `generate(graph, request)` on the
  scenario networks (determinism unchanged).
- `TeamNetworkSummaryTest`: counted, pending, excluded and routes without tracks, from a list of
  rows.

### 5.2 Quarkus

A fixture helper `src/test/java/fr/pedalons/util/NetworkEdgesFixtures` builds hand-made
`NetworkEdgesDocument`s: a 1 km grid of 5 × 5 nodes (`z14:<x>:<y>` ids, complete two-way minor
roads, polylines from `PolylineCodec`), cut into routes (rows and columns). It writes them with
`gpxTrackRepository.updateNetworkEdges(trackId, doc)`, with `rev =
assetRepository.findCurrentFileId(routeId, ROUTE_ORIGINAL_GPX)`. The routes themselves are created
by the existing test helpers (any GPX: the generator reads only the documents). The total network
is 40 km, so a 10 km loop fits the feasibility rules.

- `api/routes/RouteGeneratorResourceTest`:
  - happy path, loop with defaults (start = team location set on the fixture team, ROAD, 0.5): 200,
    1–3 candidates, decoded polyline within the grid's bounds, `distanceM` within ±10 % of 10 km,
    `bounds` containing every point, `network.routeCount` = seeded routes, `incomplete = false`;
  - one-way trip `end` ≠ `start`; `bearing` with a far end → `bearingDeviationDeg` null;
  - same `seed`, same answer;
  - validation: `distanceKm` 9 and 301 → 400 `VALIDATION`; `familiarity` 1.5 → 400; no start and
    no team location → 400 `VALIDATION` on `start`;
  - error mapping: start 5 km off the grid → `GENERATOR_START_TOO_FAR`; end off → `…_END_TOO_FAR`;
    end at the far corner with D = 10 km on a stretched grid (S→E shortest path > D / 1.05) →
    `…_DISTANCE_TOO_SHORT`; D = 300 → `…_NETWORK_TOO_SMALL` with details; team with routes but no
    document → `…_NETWORK_TOO_SMALL`, `pendingRouteCount` > 0, `incomplete = true`;
  - rights: unauthenticated 401; unknown slug and another domain's team 404; non-member 403; plain
    `MEMBER` 403; team planner off → `ROUTE_PLANNER_DISABLED`; organizer 200; platform admin 200;
  - excluded: tick every route but one → the excluded routes' edges are absent (smaller
    `totalLengthM`), `excludedRouteCount` matches;
  - a document of a stale `rev`, and one with `v = 99`: the track is pending and not used;
  - rate limit: the guard is reset in `@BeforeEach` through a package-visible `clear()`. 30
    requests pass and the 31st is 429 with `Retry-After`. Generations on the 40 km grid take
    milliseconds.
- `api/routes/RouteGeneratorCacheTest` (`TeamNetworkCache` exposes `builds()`, a counter, for
  tests and metrics):
  - two identical requests → 1 build;
  - `PUT` the route (metadata only) → rebuild on the next request;
  - `DELETE`, then undelete → rebuild each time, network shrinks then grows back;
  - `excludedFromGenerator` true through `PUT` → rebuild at once, edges gone;
  - surface type changed → rebuild;
  - `updateNetworkEdges` on a track that had none → no rebuild before `min-rebuild-interval`, a
    rebuild after it (the interval is read through an injectable `Clock`, advanced by the test);
  - **another instance's write**: the same changes made by plain SQL (`update team_entities set
    excluded_from_generator = true, version = version + 1 …`, a native document write) are seen
    the same way. That is the cross-instance property.
- `api/routes/RouteGeneratorQueryCountTest` (extends `AbstractQueryCountTest`, `queryStats`):
  - a cache hit costs `H` statements, and a miss costs exactly `H + 1` (the build);
  - the cost is **flat in network size**: the miss count is the same with 3 and with 30 seeded
    routes, so one build statement whatever their number;
  - the hit count is the same for a request answering 1 candidate and one answering 3, so zero
    statements per candidate;
  - entity hydration stays flat (the build is a native projection, so 0 entities from it).
- `api/routes/RouteExcludedFromGeneratorResourceTest`: create with the flag true → detail shows it;
  update without the field → unchanged; update with false → cleared; a plain `MEMBER` cannot
  change it (403 on `PUT`, the route's rule); duplicate keeps it; the biketeam-style short
  constructor → false.

---

## 6. Files and order

### 6.1 Files

Main (`backend/src/main/…`):

| File | Change |
|---|---|
| `resources/db/migration/V93__route_excluded_from_generator.sql` | new (§4) |
| `domain/route/Route.java` | field |
| `dto/routes/request/RouteRequest.java` | component + compatibility constructor |
| `dto/routes/response/RouteDetailDto.java` | field, filled in `from(...)` |
| `service/route/RouteService.java` | create / update |
| `service/route/RouteCopyService.java` | copy the flag |
| `enums/RouteGeneratorType.java` | new |
| `dto/routes/request/RouteGeneratorRequest.java` | new |
| `dto/routes/response/RouteGeneratorResponse.java`, `GeneratedRouteDto.java`, `RouteGeneratorNetworkDto.java` | new |
| `dto/error/ErrorCode.java` | 7 codes |
| `dto/error/RouteGeneratorNetworkDetails.java`, `dto/error/ErrorDetails.java` | new subtype |
| `repository/route/TeamNetworkRepository.java` | fingerprint and streamed build query |
| `service/route/network/` (`package-info`, `TrackInputMapper`, `TeamNetwork`, `TeamNetworkSummary`, `Fingerprint`, `TeamNetworkCache`, `RouteGeneratorService`, `RouteGeneratorGuard`, `RouteGeneratorErrors`, `RouteGeneratorMetrics`, `RouteGeneratorProducer`) | new |
| `api/routes/RouteGeneratorResource.java` | new |
| `service/route/generator/RouteGenerator.java`, `QueryContext.java`, `LoopFamily.java`, `PolygonFamily.java`, new `GeneratorStoppedException.java` | stop signal only (§3.6) |
| `resources/application.properties` | `pedalons.api.version=14.14.0`; `pedalons.route-generator.*` (§2.3, §3.5) with comments |
| `backend/pom.xml` | explicit `caffeine` dependency (BOM-managed) |

`RouteGeneratorMetrics` (Micrometer, like `NetworkEdgesMetrics`):
`pedalons.route_generator.requests{outcome}`, a timer `…generate`, a timer `…build`,
`…cache{result=hit|deferred|miss}`, and gauges for cached teams and cached weight.

Tests: §5 (`util/NetworkEdgesFixtures`, five unit classes, four Quarkus classes).

Contract and clients, regenerated together: `contracts/openapi.*`, `frontend/src/api/**`
(generated DTOs, hooks, zod), `mobile/lib/api/generated/**`.

Docs: `docs/OPERATIONS.md` (the `pedalons.route-generator.*` keys, the memory note of §2.3, the
kill switch). The plan header and ledger move are the owner's (this lot does not touch
`LEDGER_*.md`).

### 6.2 Order

1. `V93`, `Route` field, `RouteRequest` / `RouteDetailDto` / `RouteService` / `RouteCopyService`,
   then `RouteExcludedFromGeneratorResourceTest`.
2. `TrackInputMapper` and its unit test.
3. Engine stop signal and `RouteGeneratorStopTest`. Re-run the lot 2 generator suite
   (`-Dtest='fr.pedalons.service.route.generator.*Test' -DexcludedGroups=perf`) to prove nothing
   moved.
4. `TeamNetworkRepository` (fingerprint, build), `TeamNetworkSummary`, `TeamNetworkCache`,
   `NetworkEdgesFixtures`, then `RouteGeneratorCacheTest`.
5. DTOs, `ErrorCode`, `RouteGeneratorNetworkDetails`, `RouteGeneratorErrors`, `RouteGeneratorGuard`,
   `RouteGeneratorService`, `RouteGeneratorResource`, then the resource, query-count and unit tests.
6. `pedalons.api.version=14.14.0`, then `contract-first-api` (backend package, `pnpm
   generate-api`, mobile generation). Then `pnpm typecheck && pnpm lint && pnpm test` in
   `frontend/`, and the mobile analyzer the skill runs.
7. `OPERATIONS.md` keys; `EXPLAIN (ANALYZE, BUFFERS)` of both queries on a migrated base (no TOAST
   reads in the fingerprint; cursor streaming in the build), with the numbers recorded for the
   ledger entry.

### 6.3 What the regeneration means for the clients

- **Frontend**: new hooks and DTOs, unused until lot 4. `RouteRequest.excludedFromGenerator` is
  optional, and the edit form omits it, which leaves it unchanged. `RouteDetailDto.excludedFromGenerator`
  is optional in the schema, so no fixture changes. New `ErrorCode` values: the existing maps are
  `Partial<Record<ErrorCode, …>>`, so nothing to add before lot 4 writes the messages (épicène,
  plan §7: « Aucun parcours trouvé sur les routes de l'équipe pour 120 km. Essayez une autre distance
  ou un autre départ. »). `CompassPoint` is reused and unchanged.
- **Mobile**: only the regenerated client has to compile (new freezed models, new enum
  `RouteGeneratorType`, new `ErrorCode` values: no exhaustive switch over `ErrorCode` in `lib/`).
  `RouteDetailDto` gains an optional `bool?`, so the ~10 test fixtures that build it compile as they
  are. The mobile route form omits `excludedFromGenerator`, which leaves it unchanged. No UI
  (`MOB-154`, later).

---

## 7. Deliberately out of lot 3

- **Event-based invalidation** (CDI events on save, or a Postgres `LISTEN/NOTIFY`): it cannot
  reach the other instance of a rolling deploy, nor see the previous release's writes. The
  fingerprint does both.
- **A network revision column** on `teams`: `Team` is a versioned Hibernate entity updated with
  all its columns, so a stale loaded team would overwrite the counter. Every writer, the previous
  release's included, would also have to bump it.
- **Persisting the built graph** (on disk or in the database): a rebuild is one streamed query, and
  the bench decides whether it is too slow.
- **Partial results on timeout**: they would break determinism (§3.6).
- **Exposing which routes an edge comes from**: plan §3.3. The answer never names a source route.
- **Configurable `NetworkParameters` / `GeneratorParameters`**: tuned in code after the bench.

---

## As implemented (14 November 2026)

Contract `14.14.0`, migration `V93`. All of §6.1 is coded except the items listed below.

Deviations from the design:

- **`excluded_from_generator` entity mapping.** The column is `not null default false` as designed, but
  the entity field is `@Column(name = "excluded_from_generator") @NotNullableDbValue` (the `signed_as_team`
  precedent), not `nullable = false`: with `nullable = false` Hibernate inserted `null` for the other
  `team_entities` subtypes (every team about page failed with a not-null violation).
- **No `RouteGeneratorProducer`.** `RouteGeneratorService` holds its own stateless `new RouteGenerator()`.
- **`Fingerprint`** is a public record in `service/route/network` (the repository returns it); the sum of
  track ids is a `BigInteger` (it overflows a `long`). Test hooks: `TeamNetworkCache.setClockForTest`,
  `clearForTest`, `builds()`; `RouteGeneratorGuard.clear()` / `setClockForTest`.
- **`RouteGeneratorNetworkDto.lengthM`** is the reachable length (`Success.networkLengthM`) and is null only
  on failures that carry no such figure; `routeCount` is the *counted* routes (not excluded, all tracks
  current), pending and excluded are separate.
- **Frontend**: the `errors.api.*` i18n keys of the seven new codes had to be added to `fr/common.json` and
  `en/common.json` (typecheck requires one per `ErrorCode`); the design said no client change was needed.
  Wording is provisional (lot 4 may refine it).
- **Tests**: the 4-route "flat in network size" case of the query-count test uses 10 then 30 routes (a
  4-route network is too small for a 10 km loop). `DISTANCE_TOO_SHORT` is tested on a dedicated team with one
  11 km straight road, because on the 5 x 5 grid the longest shortest path is 8 km.
- Not done: `docs/OPERATIONS.md` keys and the `EXPLAIN (ANALYZE, BUFFERS)` measurements (§6.2 step 7), and the
  memory bench. The `pedalons.route-generator.*` keys are documented in `application.properties`.
- Engine: only the stop signal (§3.6), nothing else changed; the lot 2 suite is green.

Review fixes (14 November 2026):

- **Fingerprint route part narrowed** to the count plus a hash sum of `deleted`, `excluded_from_generator`
  and `surface_type` (was `sum(version)`): the HD catch-up bumps the route version a minute after a save
  and forced a second full rebuild, and the previous release's backfill rows did the same. A GPX
  replacement is still seen through track ids and versions. Not measured on the bench.
- **`TeamNetworkCache.lookup`** re-reads the fingerprint after taking the stripe lock (miss path only) and
  uses it for the double check and as the built graph's label, and takes the lock with
  `tryLock(build-wait)` (`ROUTE_GENERATOR_BUSY` on timeout), so the 503 bound holds.
