# Team route generator, lot 1: the street edges of every team route track

Lot 1 of ledger `API-198`. The parent plan is `docs/plans/2026-11-13-generateur-boucles-equipe.md`
(§3.1 storage, §10 owner decisions, §11 lots). It is still uncommitted in the main checkout, like
the `API-198` entry. Lot 1 **fetches and stores** the edges that osm-route-details matched. It
builds no graph, has no endpoint, and does not depend on `fr.pedalons.service.route.generator`
(lot 2, written in parallel). Lot 3 reads what this lot stores.

Status: design, 2026-11-13. Contract of the service: osm-route-details api `1.7`, published
(`ghcr.io/glandais/osm-route-details:develop`, `sha-9f0f16f`, no `v1.7.0` tag), and api `1.8`
approved but not published (`edges[].tracktype`, `edges[].bicycle`, `edges[].foot`).

---

## 0. Decisions in one screen

| Question | Decision |
|---|---|
| Who gets `options.edges` | Only the **`full` call that computes a team route's HD profile**: the HD catch-up of `elevation_refresh`, the synchronous HD save when `pedalons.elevation.async-hd.enabled=false`, and the edges-only call of the backfill. Never a `fast` call, a GPX preview, or the planner. |
| When | Only when the cached `/v1/capabilities` says **api ≥ 1.7 with `data.edges`**, and while `pedalons.network-edges.enabled` (default `true`) is on. The gateway removes the option otherwise, so it can never send an unknown key, which would be a 400. You can deploy the backend before the new image. |
| Storage | A nullable JSONB column `gpx_tracks.network_edges` (`V91`), holding a versioned `NetworkEdgesDocument`: one per track row, compact, nodes deduplicated, polylines kept as the service sent them. |
| Staleness | The document carries `rev`, the `file_id` of the original GPX it was computed from, as `PlannerStateDocument.trackRevision` does. Writes only happen under the route lock, after the existing revision check. A save replaces the track rows, so the new rows start with `null`, and the HD catch-up of that save writes the new document. |
| Backfill | `NetworkEdgesBackfill`, modelled on the removed `RouteDetailsBackfill` (commit `01200e08c^`). It queues `backfill = true` rows in `elevation_refresh`, behind the normal requests, under a per-hour cap carried by the due times. It is off by default. The worker serves such a row with an **edges-only** call, which writes the document and nothing else. |
| Contract | Unchanged. No resource or DTO changes, so `pedalons.api.version` is **not** bumped. |
| Image | `docker-compose.shared.yml` moves from `1.6.0` to an image ≥ 1.7 **after** the backend is deployed. Recommended: a tagged release (`1.7.0` or `1.8.0`) asked of osm-route-details rather than `sha-9f0f16f`. |

---

## 1. When edges are requested

### 1.1 Which calls

`GpxPipeline.processReported(source, name, quality, withSurface)` gains a `withEdges` flag, and
`GpxPipeline.Processed` gains `@Nullable NetworkEdgesAnswer edges`. The flag only takes effect for
`ElevationQuality.HD` (the `full` profile), for the same reason as the surface: a FAST save is
replaced by its HD catch-up a few minutes later, and a user is waiting on it.

| Caller | `withEdges` |
|---|---|
| `GpxProcessingService.recomputeHd` (route HD catch-up, `ElevationRefreshService.compute`) | `true` |
| `GpxProcessingService.processGpxData` with `quality == HD` (synchronous save, switch off) | `true` |
| `GpxProcessingService.networkEdgesOnly` (backfill, §4) | `true`, with nothing else recomputed |
| `GpxPreviewService` (both `computeGpx` calls) and `ElevationRefreshService.processPreview` | `false`. They use the existing `computeGpx` overloads, which pass `false`. |
| Planner (`processWithClimb`), FAST saves | `false` |

`computeGpx(source, quality, plan, name)` gets an overload with `boolean withEdges`, and only the
two route paths call it. `ComputedTrack` gains `@Nullable NetworkEdgesAnswer edges`. A preview
therefore never asks for edges: previews belong to people, not to a team (§10.4 of the parent
plan), and `gpx_previews` gets no column.

**With edges, the `typology` section is always requested**, even when `pedalons.surface.enabled` is
off. The service runs the typology in both profiles whatever the sections are. Asking for it only
adds the `segments[]` bytes, and the unmatched summary (§2.4) needs `segments[].unmatched_reason`.

A degenerate track (shorter than `GpxPipeline.MIN_LENGTH_M`, read through a probe) never asks for
edges. It gets a document with `status: "too_short"` and no edges, so the backfill does not pick it
up again.

### 1.2 Capability gate (deploying the backend before the image is safe)

- `RouteDetailsCapabilities.Data` gains `@Nullable EdgesFeature edges` (`node_id_prefix`,
  `node_grid_zoom`, `node_grid_extent`, `geometry`, `polyline_precision`, `way_id`,
  `oneway_bicycle`), and the class gains `supportsEdges()`, which is `apiAtLeast(1, 7) && data !=
  null && data.edges() != null`.
- `RouteDetailsGateway.supportsEdges()` answers from the cached capabilities (one hour TTL, never
  throws): `false` while they are unknown or the service is unreachable.
- `RouteDetailsOptions` gains `@Nullable Boolean edges` (`NON_NULL`, so it is absent from the JSON
  when null) and `withEdges(boolean)`. `forSlicing` keeps it.
- **One enforcement point**: in `RouteDetailsGateway.details(lat, lon, options)`, if
  `options.edges()` is true and `!supportsEdges()`, the option is cleared before sending and the
  answer has `edges == null`. No caller can make a 1.6 service answer a 400.
- **Service rollback within the cache hour** (1.7 cached, a 1.6 image behind): a request sent with
  `edges` gets a 400 (`Kind.BUG`). In that case the gateway **invalidates the capabilities cache**
  (`capabilitiesFetchedAt = null`) before rethrowing, so the next call fetches them again and
  stops asking. The HD catch-up already retries a failed `full` call (backoff 2 min, 10 min, …), so
  at most one attempt is lost.
- `check(fetched)` logs once at `info` level `osm-route-details api X serves no edges: network edges
  not asked` when `pedalons.network-edges.enabled` is on and the capability is missing.

Switch: `pedalons.network-edges.enabled=${NETWORK_EDGES_ENABLED:true}`, read by `GpxPipeline`
(the way back without redeploying, like `pedalons.surface.enabled`).

### 1.3 Parsing the answer

`RouteDetailsResponse` gains `@Nullable List<Edge> edges`. `Segment` gains `@Nullable
@JsonProperty("unmatched_reason") String unmatchedReason`, appended last, and the stitcher and the
fake carry it. As everywhere in this record, enumerated values stay `String`, because the lists are
open:

```java
@JsonIgnoreProperties(ignoreUnknown = true)
public record Edge(
    @JsonProperty("from_m") double fromM, @JsonProperty("to_m") double toM,
    @JsonProperty("from_index") int fromIndex, @JsonProperty("to_index") int toIndex,
    @Nullable @JsonProperty("from_node") EdgeNode fromNode,
    @Nullable @JsonProperty("to_node") EdgeNode toNode,
    boolean partial,
    @Nullable @JsonProperty("length_m") Double lengthM,
    @JsonProperty("traversed_m") double traversedM,
    @Nullable @JsonProperty("from_offset_m") Double fromOffsetM,
    @Nullable @JsonProperty("to_offset_m") Double toOffsetM,
    String oneway,                       // both | forward | against
    String geometry,                     // Google polyline, precision 6, travel direction
    @JsonProperty("from_gain_cum_m") double fromGainCumM, @JsonProperty("to_gain_cum_m") double toGainCumM,
    @JsonProperty("from_loss_cum_m") double fromLossCumM, @JsonProperty("to_loss_cum_m") double toLossCumM,
    @Nullable String structure, @Nullable Surface surface,
    @Nullable @JsonProperty("way_kind") String wayKind,
    @Nullable String tracktype,          // api 1.8: grade1..grade5, homogeneous only
    @Nullable String bicycle,            // api 1.8: yes | limited | no, absent = untagged or mixed
    @Nullable String foot) {}            // api 1.8

@JsonIgnoreProperties(ignoreUnknown = true)
public record EdgeNode(String id, double lat, double lon, int degree) {}   // id "z14:<x>:<y>"
```

### 1.4 Slicing (tracks longer than about 188 km)

`RouteDetailsGateway.details(lat, lon, options)` slices long lines, and `RouteDetailsStitcher`
must stitch `edges[]` too. Long tracks (brevets) are few but they cover distinct roads, so they
are not skipped. Rules, pure, in `RouteDetailsStitcher.stitch`, next to the segments:

1. **Clip to the core.** For slice *k*, with core `[fromM, toM]` on the slice's own axis (the
   anchors already computed), an edge with `b = min(toM, e.toM) <= a = max(fromM, e.fromM)` is
   dropped (it lies in the overlap). Otherwise it is clipped to `[a, b]`. When a clip happens,
   offsets are moved linearly by `(a − e.fromM) · traversed/(e.toM − e.fromM)` (and the same at
   the end). The geometry is cut at that network distance along the decoded polyline and
   re-encoded at precision 6 (`PolylineCodec.decode2` / `encode2`, precision 6, `[lng, lat]`).
   Gain and loss cumulatives are interpolated linearly between the edge's ends, and the
   `offsetGain` / `offsetLoss` of the core are then added. `traversed_m` is recomputed from the
   offsets when both are known, otherwise scaled. The service's 5 m head and tail rule only acts at
   a slice's real ends, which fall in the 500 m overlap and are clipped away.
2. **Shift** `from_m` / `to_m` by `shift`. Map `from_index` / `to_index` like segments (`clamp`,
   then `reindex` maps the indices back to the caller's).
3. **Merge across the boundary** (`appendEdge`): when the previous edge ends at the new one's start
   (`JOIN_TOLERANCE_M`), both share the same non-null `from_node.id` **and** `to_node.id`, have the
   same `oneway`, and their offsets meet (`|prev.toOffset − next.fromOffset| ≤ 2 m`, or both
   null), they become one edge: ends taken from each side, `traversed` summed, geometries
   concatenated (the duplicated join vertex dropped), `partial = !(fromOffset ≈ 0 && toOffset ≈
   length)` when the length is known, otherwise `prev.partial || next.partial`. The typology
   attributes survive only where both sides agree, otherwise they are dropped (not homogeneous any
   more).
4. A single slice that covers the whole line is returned as it is, with the service's polylines
   byte for byte (the common case).

---

## 2. The stored document

### 2.1 Column and entity

`V91__gpx_track_network_edges.sql`:

```sql
-- docs/LEDGER_*.md API-198 (lot 1, plan docs/plans/2026-11-13-generateur-boucles-equipe-lot1.md):
-- the street edges osm-route-details matched for a team route's track. Purely additive for the
-- start-first rolling deploy: the previous release neither reads nor writes the column, and the
-- track rows it inserts start with null, which the HD catch-up of their save fills.
alter table gpx_tracks add column network_edges jsonb;

-- What the backfill looks for: tracks without a document, or with one older than
-- NetworkEdgesDocument.VERSION. The 1 is that version, inlined (a partial index predicate cannot
-- take a parameter): a bump of it recreates this index in its migration.
create index gpx_tracks_network_edges_behind on gpx_tracks (route_id)
  where network_edges is null or (network_edges->>'v')::int < 1;
```

(`->>` and the text to int cast are immutable, so they are allowed in an index predicate. The
predicate is only evaluated when a row is written. Like the earlier pipeline indexes, the index is
created non-concurrently: `gpx_tracks` is a few tens of thousands of rows.)

`GpxTrack`:

```java
@Basic(fetch = FetchType.LAZY)
@LazyGroup("edges")
@Type(JsonBinaryType.class)
@Column(name = "network_edges", columnDefinition = "jsonb")
private @Nullable NetworkEdgesDocument networkEdges;
```

It is lazy and in its own group, because it is up to a few hundred kB and nothing on the read paths
of a route may load it. `GpxTrackRepository` gains `updateNetworkEdges(trackId, doc)` (native,
like `updateSurfaces`), `findNetworkEdges(routeId)` (`Map<Long, NetworkEdgesDocument>`, used by
the tests and by lot 3), and `findNetworkEdgesHeads(routeId)`, a native projection of `id`,
`(network_edges->>'v')::int` and `(network_edges->>'rev')::bigint` that the edges-only path uses
to check "already done".

### 2.2 `NetworkEdgesDocument` (version 1)

It sits in `fr.pedalons.domain.route`, next to `TrackSurfaceDocument`, and it is **not** part of the
contract. Like `PlannerStateDocument`, it is annotated `@JsonIgnoreProperties(ignoreUnknown =
true)` and `Serializable` (hypersistence's mapper fails on unknown properties, and a release must
read what a later one wrote). Keys are short because the document is per track and the team graph
reads thousands of them. Every nullable field is `NON_NULL`.

```jsonc
{
  "v": 1,                          // NetworkEdgesDocument.VERSION
  "rev": 7351234567890123,         // trackRevision: file_id of the route's original GPX
  "at": "2026-11-13T21:04:00Z",    // computedAt
  "status": "ok",                  // ok | too_short   (String, open)
  "api": "1.7",                    // meta.api_version
  "rules": "2026.11.13",           // meta.rules_version
  "profile": "full",               // meta.profile
  "dv": { "typology": { "source": "versatiles-shortbread", "zoom": 14, … }, "elevation": [ … ] },
                                   // meta.data_versions of the first slice, as received
  "len": 52310.4,                  // length on the service's axis (summary.length_m, or sum of cores)
  "nodes": [["z14:33260341:23548731", 47.201628, -1.577627, 4], …],
                                   // [id, lat, lon, degree], deduplicated by id, order of first use
  "edges": [
    { "fm": 0.0, "tm": 52.78,      // from_m / to_m on the track axis (kept: they join the edge
                                   // to the surface document of the same answer, §2.3)
      "fn": 0, "tn": 1,            // index in nodes, absent = unknown end (null node)
      "p": false,                  // partial
      "len": 52.76,                // length_m of the complete edge, absent if an end is unknown
      "trv": 52.76,                // traversed_m
      "fo": 0.0, "to": 52.76,      // from_offset_m / to_offset_m, absent with an unknown from_node
      "ow": "both",                // both | forward | against
      "g": "wt}_yAthh_BiSz^",      // geometry, polyline6 as received (re-encoded only when stitched)
      "fg": 0.0, "tg": 2.74,       // from/to_gain_cum_m
      "fl": 0.0, "tl": 0.0,        // from/to_loss_cum_m
      "st": "ground",              // structure, homogeneous only
      "sc": "paved", "sd": "asphalt", "ss": "tagged",   // surface class/detail/source, homogeneous only
      "wk": "minor_road",          // way_kind, homogeneous only
      "tt": "grade2", "bi": "yes", "ft": "no"           // api 1.8, homogeneous only, absent today
    }
  ],
  "unmatched": { "closed_to_bicycles": 120.5, "off_network": 30.0, "no_data": 0.0 },
                                   // metres of matched=false segments per unmatched_reason
                                   // (a reason this release does not know is kept under its own key)
  "covered": 51870.2               // metres of the track covered by an edge (Σ tm − fm)
}
```

Java shape: `record NetworkEdgesDocument(int v, long rev, Instant at, String status, @Nullable
String api, @Nullable String rules, @Nullable String profile, @Nullable JsonNode dv, double len,
List<Node> nodes, List<Edge> edges, Map<String, Double> unmatched, double covered)`. `Node` is
written and read as a four-element array, with a reader that ignores extra elements, the
`TrackSurfaceDocument.SurfaceRange` pattern. `Edge` is a record of short-named
`@JsonProperty` fields. Values are stored as received: metres with two decimals, coordinates with
six. The mapping lives in `NetworkEdgesDocuments.from(NetworkEdgesAnswer, long rev, Instant now)`,
in a new package `fr.pedalons.service.route.edges`. That package is **not** the generator's and
depends only on `domain.route` and `infrastructure.routedetails`.

What is **not** stored: `from_index` / `to_index` (indices of the densified line that was sent,
meaningless afterwards), and the warnings.

**Street data version.** The task and the parent plan mention `data_versions.streets`. The real
1.7 answer (`edges-example.json`) carries the street tiles under **`data_versions.typology`**
(`source: versatiles-shortbread`, `zoom: 14`, no id or date). The whole `dv` tree is kept, and
`NetworkEdgesDocument.streetsVersion()` returns `dv.streets` if present, otherwise
`dv.typology`, as JSON text. **To confirm with osm-route-details** before lot 3 keys anything on it
(today it cannot tell two tile updates apart).

**Size.** Measured on the example (12 urban edges over 669 m): 258 bytes per edge in this form
against 570 as received, and 817 bytes after zlib for the whole document (TOAST compresses it).
At roughly 150 m per edge on average, a 100 km track is about 170 kB of JSON (about 45 kB on disk),
and the 2,656 routes of the largest team about 100 MB on disk. Acceptable. Lot 3 will need a
projection that reads `nodes` and `edges` only, and its Caffeine cache.

### 2.3 Why `fm` / `tm` and `len` are kept

`structure`, `surface` and `way_kind` are present only when they are homogeneous along the edge.
For a mixed edge, lot 3 recovers the mix from the track's `surfaces` document (version 2, same
`full` answer, ranges on the same service axis, rescaled with its `distance`) by `fm` / `tm`.
`len` is that axis's length, for the same rescale. Lot 1 stores nothing more for that.

### 2.4 Unmatched summary

The sum of `to_m − from_m` over `segments[]` with `matched == false`, grouped by
`unmatched_reason` (key `unknown` when the field is absent). `no_data > 0` means street tiles were
missing during the call. Lot 1 does **not** retry such tracks (see §8). Lot 3 can tell a track
that is "off the network by design" (forest track) from one that ran into a data outage.

---

## 3. Staleness: the same worker run rewrites the document

- **Revision.** `rev` is the `file_id` of the original GPX the edges were computed from: the
  claim's `sourceRevision` in the worker, and the new original's `fileId` in `processGpxData`. That
  method uploads it first and passes it on to the track build. A reader (lot 3, and the edges-only
  path) uses a document only while `rev` equals the route's current original, the same rule as the
  planner state.
- **HD catch-up** (`ElevationRefreshService.write` → `GpxProcessingService.applyRecompute`): the
  edges of the same answer go into `ElevationRecompute.edges` (`List<@Nullable
  NetworkEdgesDocument>`, one per track, built by `recomputeHd` with `rev = claim.sourceRevision`)
  and are written by `gpxTrackRepository.updateNetworkEdges` in **the same transaction** as the
  profile, under the route's `PESSIMISTIC_WRITE` lock, after the existing check `currentOriginal ==
  claim.sourceRevision`. If the track was saved during the compute, nothing is written, the request
  is realigned (existing code), and the next run writes the edges of the new revision.
- **`null` edges in a recompute** (capability missing, switch off, answer without `edges[]`, a
  mapping or stitching error, which is logged): the column is **left as is** and the profile is
  still written. Edges must never block the HD profile. A document left from an older revision is
  ignored by its `rev`, and the backfill fills a `null` one.
- **Saves.** `RouteService.updateRoute` clears and refills the tracks (orphan removal), so every
  save that changes the track creates new rows with `network_edges = null`. A FAST save is then
  served by its HD catch-up. A synchronous HD save sets the document on the new rows.
  `RouteCopyService.duplicate` replays `createRoute` (a FAST save and its catch-up), so nothing is
  copied. The biketeam import queues normal requests, so it gets edges from their catch-up.
- **What only changes the elevations** keeps the 2D line and the original, and therefore keeps
  `rev`. The catch-up still rewrites the document, because its gains come from the new profile.
- **Rollback or previous release.** The old code maps no `network_edges`. Any row it inserts
  starts `null`, and it never touches existing documents. A row it updates in place (its HD
  catch-up) keeps the document of the same revision, which is still valid.

Not covered: a stale document whose `rev` differs while the row was kept. No write path produces
one today, and the readers ignore it by `rev`. The backfill does not look for it, because that
would need a join from every document to the assets on each pass (§4.2).

---

## 4. Backfill of existing tracks

### 4.1 Through the existing queue, edges only

The 7 November fleet recompute (`RouteDetailsBackfill`, `API-150` phase D, removed by `API-174`,
source at `01200e08c^`) re-ran the **whole** HD pipeline. Doing the same here would be wrong:
`applyRecompute` writes new file content revisions, so **every route would be pushed again to
Garmin, Wahoo and the other GPS services**, ride end times would be recomputed, and the profile
would be rewritten for nothing. It would also cost the same load on the shared service that
`OPS-58` measured.

So a backfill row in `elevation_refresh` (`backfill = true`, a column the previous release still
reads and that the worker already serves after the normal requests) is processed by a **lighter
path**:

`ElevationRefreshRepository.Claim` gains `boolean backfill`, read from the claimed row.
In `ElevationRefreshService.process(claim)`, after `realignIfStale`:

```
if claim.backfill
   && route.elevationState in (HD, null)
   && route.elevationPipeline == GpxPipeline.VERSION        // behind: the full path, as before
→ processEdgesOnly(claim)
else → the existing three phases (unchanged)
```

`processEdgesOnly` follows the same claim / compute / write pattern:

1. **Already done?** In a short transaction, `findNetworkEdgesHeads`: every track has `v ==
   VERSION && rev == claim.sourceRevision`, so the row is deleted, giving `Outcome.GONE`. This is
   idempotent: an HD catch-up or a second pass may have written them in the meantime.
2. **Capability.** `!routeDetails.supportsEdges()` (service rolled back, cache not refreshed yet):
   the row is **postponed** by one hour without counting an attempt (`refreshRepository.postpone(id,
   dueAt)`, which releases the lease), giving the new `Outcome.POSTPONED`. Without this, five
   failures in about seven hours would abandon rows that are fine.
3. **Compute**, with no transaction: download the original of `claim.sourceRevision` (the existing
   `load`), then `GpxProcessingService.networkEdgesOnly(original, rev)`, which takes the same raw
   tracks (`rawTracks`) as the HD recompute and calls the new `GpxPipeline.edgesOf(raw, name)`
   for each. That method densifies to 50 m like `processDense` (same axis as the profile), uses
   profile **`full`** (the edge gains must match the routes' HD profile and the catch-up's
   documents), requests sections `[typology, summary]` (plus elevation when sliced, through
   `forSlicing`) with `edges: true` and without `accept_partial`, and **throws** on failure,
   unlike the profile path. An answer without `edges[]` is a failure (`IllegalStateException
   "osm-route-details answered no edges"`).
4. **Write**, in a short transaction: lock the route (`PESSIMISTIC_WRITE`), check that the
   current original is still `claim.sourceRevision` (otherwise realign or drop, as `write` does)
   and that the number of track ids equals the number of documents, then `updateNetworkEdges` for
   each track and `deleteIfRevision`, giving the new `Outcome.EDGES`. Nothing else changes:
   profile, files, asset revisions, `elevation_state`, `elevation_pipeline` and ride ends stay as
   they were.
5. **Failure**: the existing `fail(...)` (backoff, five attempts, then the row stays and shows in
   the admin "abandoned" list, which already includes `backfill` rows). `abandonTarget` only
   switches `PENDING` to `FAST`, so an HD route is left alone. The log line says "network edges of
   route N", not "HD elevation".

### 4.2 `NetworkEdgesBackfill` (scheduler)

It lives in `fr.pedalons.service.elevation` and is the removed `RouteDetailsBackfill` brought
back with another candidate query (routes only, no previews):

- `@Scheduled(every = "5m", delayed = "2m", concurrentExecution = SKIP)`.
- **Off by default**: `pedalons.network-edges.backfill.enabled=${NETWORK_EDGES_BACKFILL_ENABLED:false}`,
  because all environments share one osm-route-details and one IGN budget. Also stopped while
  `pedalons.network-edges.enabled` is off or `!routeDetails.supportsEdges()`. This matters: with a
  1.6 service, a queued row would never get its document and the loop would never end. A warning is
  logged once.
- **Cap**: `pedalons.network-edges.backfill.per-hour=${NETWORK_EDGES_BACKFILL_PER_HOUR:30}`
  `full` calls per hour across the backends, carried by the due times (`spacing = 3600 /
  perHour` s, one call weighs `ceil(distance / CALL_M)` with `CALL_M` = 188 km). `WINDOW = 10 min`
  bounds what is queued ahead. The default is half the 60 per hour that `OPS-58` measured as heavy
  on a 1 GB service. At that rate the 2,656 routes of the largest team take about 3.7 days, and
  the cap can be raised once the 2 GB limit has been watched.
- **One pass** runs in one transaction that first takes `pg_advisory_xact_lock(hashtextextended(
  'network-edges-backfill', 0))`, so the two backends of a rolling deploy run one after the other.
- **Candidates**, most recent first. There is neither domain nor query context: it is a system job
  across domains, keyed by id. The version literals are inlined:

  ```sql
  select t.id, t.distance,
         (select a.file_id from assets a where a.team_entity_id = t.id
            and a.type = 'ROUTE_ORIGINAL_GPX' order by a.id desc limit 1)
    from team_entities t
    join teams tm on tm.id = t.team_id
   where t.entity_type = 2 and t.deleted = false and tm.deleted = false
     and (t.elevation_state is null or t.elevation_state = 'HD')
     and t.elevation_pipeline = {pipeline}
     and not exists (select 1 from elevation_refresh e where e.route_id = t.id)
     and exists (select 1 from gpx_tracks g where g.route_id = t.id
                   and (g.network_edges is null or (g.network_edges->>'v')::int < {edgesVersion}))
     and exists (select 1 from assets a where a.team_entity_id = t.id and a.type = 'ROUTE_ORIGINAL_GPX')
   order by t.created_at desc, t.id desc
   limit :room
  ```

  The `gpx_tracks` predicate is the one of `gpx_tracks_network_edges_behind`, so once the backfill
  is done a pass reads an almost empty index. **Any** request row excludes a route: an open one
  (FAST save, admin retry) brings the full catch-up, which writes edges, and a given-up one is not
  queued again. That ends the loop by itself, and the admin retry is the way back.
  Routes behind the pipeline, or `FAST` / `PENDING`, are not candidates: they get their edges at
  their next save or retry (the API-174 rule).
- **Insert**: `insert … (route_id, source_revision, first_requested_at, due_at, backfill) values
  (…, true) on conflict (route_id) where route_id is not null do nothing`. This is idempotent: a
  save made meanwhile wins (its upsert sets `backfill = false`, and the route is `PENDING`, so it
  goes through the full path).
- **Restartable**: all state is in the database (rows, due times, documents). A restart, a deploy
  or switching it off and on again resumes where it stopped. Rows already queued are still served
  while it is off.
- **Progress log** at `info` level on each pass that found work: `Network edges backfill: %d
  queued; left %d route(s) (%.0f km); given up %d`, plus `… done` once, the old pattern (one
  `count` query on the partial index).

### 4.3 Rolling deploy and rollback, case by case

| Situation | What happens |
|---|---|
| New backend, osm-route-details still 1.6 | `supportsEdges()` is false: no option is sent, the backfill does not run. Nothing changes until the image moves. |
| Old and new backends side by side (about 1 min) | The old one ignores the column. A backfill row it claims gets the **full** recompute: one route pushed again to GPS and its row deleted, with no document written, so the next pass queues it again. That is at most the `WINDOW` (5 rows at 30/h), and only while the backfill is switched on during the deploy. Recommended: deploy with the backfill off, or accept this. |
| Image upgraded after the backend | The capabilities are refetched within one hour, and the edges come from the next catch-up. |
| Image rolled back to 1.6 | At most one failed `full` attempt (400), then the cache is invalidated; backfill rows are postponed without an attempt; the HD catch-ups go on without edges. |
| Backend rolled back to before V91 | The column stays (additive) and is unread. On redeploy, the documents are still valid by `rev`. |

---

## 5. Metrics and logs

Micrometer is already on the classpath (`quarkus-micrometer-registry-prometheus`, `/q/metrics`).
These are the first business metrics, so the list is kept short:

| Metric | Type | Tags |
|---|---|---|
| `pedalons.network_edges.documents` | counter | `source` = `catchup` \| `save` \| `backfill`, `status` = `ok` \| `too_short` |
| `pedalons.network_edges.failures` | counter | `reason` = `no_edges` \| `stitch` \| `call` \| `postponed` |
| `pedalons.network_edges.document.bytes` | distribution summary | (none): the size of each document written, for the storage estimate |
| `pedalons.network_edges.backfill.remaining` | gauge | routes still without a document, set by each pass |

Logs: `debug` for each document (`route, track, edges, nodes, partial edges, unmatched by reason,
bytes`); `warn` for an answer without `edges[]` despite the capability, and for a stitching error
(`error` with the stack, a bug); `info` once on a capability below 1.7; the backfill progress lines
above. No node coordinates and no geometry in any log.

---

## 6. Tests (written, not run: backend tests are run by the owner)

Fixture: copy `edges-example.json` to
`backend/src/test/resources/routedetails/nantes-edges-fast.json` (12 edges, `api_version 1.7`,
profile `fast`, only `meta` / `status` / `edges`). Fake client (`FakeRouteDetailsClient`): a static
`apiVersion` (default `"1.7"`, with `data.edges` when ≥ 1.7), and the options of the last call
recorded (`lastOptions`). When `options.edges` is set it returns synthetic edges: one per run of
three input points, nodes `z14:<i>:<i>`, a polyline6 of the points, gains from the terrain. A test
can also replace them (`edgesOf`) or drop them (`noEdges`). It answers 400 to `edges` when
`apiVersion` is below 1.7, as the real service would. `reset()` clears it all.

| Test class | What it pins |
|---|---|
| `RouteDetailsEdgesParsingTest` (plain) | The fixture parses with the backend's mapper: 12 edges, first edge `0.0–52.78`, nodes `z14:33260341:23548731` (degree 4) → `z14:33260246:23548642`, `partial` false ×10 and true ×2, `oneway` both ×8 and forward ×4, homogeneous surface `paved/asphalt/tagged`; `tracktype`, `bicycle`, `foot` are null; a hand-made 1.8 edge with `tracktype: grade2, bicycle: yes, foot: no` and an unknown key parses; a `null` `from_node` gives null offsets and length; `segments[].unmatched_reason` is read. |
| `NetworkEdgesDocumentTest` (plain) | `NetworkEdgesDocuments.from` on the fixture: nodes deduplicated (8 distinct ids for the 12 edges of the fixture, a loop with a U-turn: edges 6 and 7 are the same partial edge `…152 ↔ …207` in both directions), `fn` / `tn` indices, geometry strings **byte-identical** to the answer, gains and loss, surface split into `sc` / `sd` / `ss`; unmatched summary by reason, with an unknown reason kept; `covered`; JSON round trip through hypersistence's `ObjectMapperWrapper`; a document with an extra top-level key, an extra edge key and a five-element node is read; `too_short` document. |
| `RouteDetailsCapabilitiesTest` (plain, extended) | `supportsEdges()` is false for 1.6, for 1.7 without `data.edges` and for an unreadable version; true for 1.7 or 1.8 with it. |
| `RouteDetailsGatewayEdgesTest` (plain, gateway with the fake client) | The request JSON has **no `edges` key** when the options do not ask for it, or when the capabilities are 1.6 / unknown / unreachable even though asked; it has `"edges": true` with 1.7. A 400 on a request with edges invalidates the cache (the next `supportsEdges()` fetches again). |
| `RouteDetailsStitcherTest` (extended) | Two slices: an edge in the overlap only is dropped; an edge straddling the core boundary comes out **once**, offsets and `traversed` continuous, geometry the two clipped halves without a duplicate vertex, gains shifted by the core's offset; differing nodes on each side give no merge; edge indices are reindexed with `sent`; one slice is returned unchanged. |
| `GpxPipelineTest` (extended) | `HD` + `withEdges` sends `edges: true` and the `typology` section even with the surface off; `FAST` + `withEdges` sends no `edges`; a degenerate track gives `too_short`; an answer without edges gives `Processed.edges == null` and the profile is unchanged. |
| `ElevationRefreshTest` (Quarkus, extended) | The worker's HD catch-up writes `network_edges` on every track with `rev` = the original's `file_id` and `v = 1`; a **preview's** catch-up sends no `edges` (`lastOptions`); a track saved during the compute gets no document (existing realign) and the next run writes the new revision's; an update of the track gives new rows with `null`; `NETWORK_EDGES_ENABLED` off gives no `edges` sent; an exception in the edges mapping still writes the HD profile. |
| `NetworkEdgesBackfillTest` (Quarkus, new) | Off by default: nothing queued. On, with the fake at 1.6: nothing queued. On at 1.7, it queues only routes that are HD (or null) at the current pipeline, live, of a live team, with a track that is `null` or `v < VERSION`, no row of any kind (open, or abandoned with 5 attempts), and an original; it skips previews, deleted routes, routes of a deleted team, `FAST` / `PENDING` routes and routes behind the pipeline; due times are spaced by `3600 / perHour` and weighted by length; a second pass queues nothing new (idempotent); a concurrent save of a queued route makes the row a normal request. |
| `ElevationRefreshEdgesOnlyTest` (Quarkus, new) | A backfill row is served after the normal ones, by the edges-only path: document written; `elevation_state`, `elevation_pipeline`, track points, `distance`, filtered GPX / FIT `file_id` and content revision **unchanged**; row deleted (`Outcome.EDGES`). Documents already at `rev` and `VERSION` give the row deleted and no call (`GONE`). Capability dropped to 1.6 gives the row postponed one hour with `attempts` unchanged (`POSTPONED`). An answer without edges gives a recorded failure; after 5 the row stays, the route is still HD, it appears in `findAbandoned`, and a pass does not queue it again. The original replaced between claim and write gives nothing written. |

Reminder (memory `backend-tests-rewrite-contract`): `mvn test` rewrites `contracts/openapi.*`.
Since nothing in the contract changes, revert that file before committing.

---

## 7. Documentation and configuration to update

- **No contract change**: no resource, DTO or route is touched; `network_edges` is never served.
  `pedalons.api.version` stays as it is, and the `contract-first-api` skill is not run.
  **Confirmed.**
- `docker-compose.shared.yml`: `ghcr.io/glandais/osm-route-details:1.6.0`, moved to the 1.7 (or
  1.8) image **after** the backend is deployed. The comment beside it says api ≥ 1.7 for the
  edges. Ask osm-route-details for a tag (`1.7.0` / `1.8.0`) rather than pinning `sha-9f0f16f`.
- `docs/OPERATIONS.md`, section "Elevation and surface along saved tracks": a paragraph on the edges
  (written by the same `full` call into `gpx_tracks.network_edges`, only for routes, only when the
  service announces api ≥ 1.7, `NETWORK_EDGES_ENABLED` as the way back), the order "backend, then
  image", and a new subsection **"The network edges backfill"**: the switch and the cap, how to
  follow it (the log line, the gauge, `select count(*) from gpx_tracks where network_edges is
  null`), the advice to switch it off during a deploy, and the `OPS-58` memory watch on the service
  while it runs. Update the memory table row for osm-route-details if the cap is raised.
- `.env.example`: `NETWORK_EDGES_ENABLED`, `NETWORK_EDGES_BACKFILL_ENABLED`,
  `NETWORK_EDGES_BACKFILL_PER_HOUR`, commented out, next to `OSM_ROUTE_DETAILS_URL`.
- `application.properties`: the three keys, documented next to `pedalons.surface.enabled`.
- `backend/CLAUDE.md`: one line in the route-details gotchas: "edges: route `full` calls only,
  gated by capabilities ≥ 1.7 in the gateway; previews never".
- Javadoc: `ElevationRefresh.backfill` and `ElevationRefreshWorker` ("left by the former catch-up,
  nothing sets it any more") now name `NetworkEdgesBackfill` as the writer.
- **Ledger**: lot 1 is delivered under `API-198` itself (renumbered from `API-196` on 14 November
  2026, the number having been taken meanwhile); `API-198` stays open for lots 3–4. `API-175` (drop
  the `backfill` column) moved to « Délibérément dehors »: the column has a writer again.

---

## 8. Deliberately out of lot 1

- **The team graph, its cache and any reader** of the documents: lot 3.
- **Recomputing on a street tile update** (`dv` change): nodes stay stable while the OSM node does
  not move, and lot 3 merges nodes within 2–3 m. A version bump of the document (`v`) is the
  mechanism if it is ever needed (index predicate and backfill already key on it).
- **Retrying tracks with `unmatched.no_data > 0`**: they are recorded, so lot 3 can see them. A
  retry policy waits until it is measured whether it happens.
- **Edges of GPX previews and of GPX tracks attached to rides**: people's tracks, not the team's
  (§10.4 of the parent plan).
- **Edges in `fast`** (planner, FAST saves): replaced minutes later by the catch-up, and they would
  slow down a call a user is waiting on.
- **Looking for documents with a stale `rev`** in the backfill: no write path makes one, and the
  readers ignore them.
