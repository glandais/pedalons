# Team-network route generator — lot 2 design (pure generator)

Working document next to [the plan](2026-11-13-generateur-boucles-equipe.md) (ledger `API-198`),
written 13 November 2026. **Scope: lot 2 only** — a pure Java package, no database, no CDI, no
Quarkus import, unit-testable on hand-built graphs. The real-data bench (§9 of the plan) needs
lot 1 (`network_edges`) and is not part of this design; the graph cache, endpoint and
`excludedFromGenerator` column are lot 3.

Section numbers like "plan §2.4" refer to the plan. Decisions of plan §10 are final and not
re-discussed here.

**Read §12 first.** The corrections after the independent review (13 November 2026, findings
B1, B2, M1–M6 and minors) and the alignment on the published osm-route-details api `1.7`
contract rewrite the input model, the builder's observation handling, the turn rule, the tails of
a one-way trip, the polygon radius, the request type (route / gravel / VTT, plan §5.5) and the
tests. The earlier sections below have been corrected where they were wrong and point to §12 for
the detail; where a section and §12 still disagree, §12 wins.

- Main code: `backend/src/main/java/fr/pedalons/service/route/generator/`
- Tests: `backend/src/test/java/fr/pedalons/service/route/generator/`
- One package, with a `package-info.java` annotated `@NullMarked` (enforced by `ArchitectureTest`).
  Public surface is small (input records, `NetworkGraphBuilder`, `NetworkGraph`, `QueryGraph`,
  `RouteGenerator`, request/result records, `RouteGuarantees`); everything else is
  package-private.
- Java 25: records, sealed interfaces, pattern matching. JUnit 5 with plain `Assertions` (the repo
  has no AssertJ). No new dependency.
- Determinism: no `HashMap`/`HashSet` iteration order may influence a result (use arrays,
  `LinkedHashMap`, or sort), no parallel streams, one `java.util.Random(seed)` per `generate` call,
  heap ties broken by state id.
- Repo rule: agents do not run backend tests. The implementer may compile
  (`mvn -q test-compile` in `backend/`) and must hand the test command to the owner.

---

## 1. Geometry convention: local equirectangular metres

All geometric maths (node merge, snapping, corridor detection, headings, bearings, polygon
placement, A* lower bound) runs in a **local equirectangular projection** around a reference
point (`refLat`, `refLon`) = mean of the graph's node coordinates:

```
x = R · toRad(lon − refLon) · cos(toRad(refLat))
y = R · toRad(lat − refLat)            R = 6 371 008.8 m
```

Why this and not haversine everywhere:

- The operations that need geometry are either **short-range** (2.5 m merge, 25 m corridor, 30–50 m
  heading windows, ≤ 2 km snap) or **angular** (bearings, turn angles), where the projection's
  error is negligible: the x-scale error is ≈ tan(refLat)·Δlat, i.e. ≈ 2.4 % at 150 km north or
  south of the reference at 46° N — that is 6 cm on a 2.5 m merge and < 1.5° on a bearing.
- A uniform grid spatial index and segment projection need planar coordinates anyway; a
  per-operation haversine would cost trigonometry in the hottest loops.
- **Lengths are never taken from the projection**: edge lengths come from the input `lengthM`
  (osm-route-details, measured on the sphere), and route distance is their sum. Where the
  projection gives a lower bound (A*), it is multiplied by the graph's measured `aStarScale`
  (§12.8; the former fixed `0.97` was not admissible far from the reference latitude).

`LocalProjection` is created once per `NetworkGraph`; projected node coordinates and projected
geometry are stored alongside lat/lon.

---

## 2. Class list

`(pub)` = public, otherwise package-private. Grouped by part.

### PART A — model, builder, graph algorithms, guarantees

| Class | Responsibility |
|---|---|
| `LatLon` (pub record) | `(double lat, double lon)`. Package-local, decoupled from any API/JSON type. |
| `NodeRef` (pub record) | `(String key, LatLon position, int streetDegree)` — one end of the **complete** street edge. `key` = osm-route-details `id` (`z14:<x>:<y>`); `streetDegree` = its `degree` (distinct bike-open neighbours, 1 = dead end). Used by the turn rule's exemption (§12.4). |
| `Oneway` (pub enum) | `BOTH`, `FORWARD` (one-way, ridden in its legal direction), `AGAINST` (one-way, ridden against it: probably a contraflow bike lane). Relative to the travel direction of the track. |
| `TrackEdge` (pub record) | **Superseded by §12.1**: complete-edge ends, `partial`, `lengthM` of the complete edge (nullable), `traversedM`, offsets, traversed geometry only, surface class/detail/source, `wayKind`, optional api 1.8 `tracktype`/`bicycle`/`foot`. |
| `TrackInput` (pub record) | `(long trackId, boolean excluded, TrackKind kind, List<TrackEdge> edges)` — edges in travel order. `excluded` = `Route.excludedFromGenerator` (plan §10.8), `kind` = `Route.surfaceType` (§12.1). |
| `TrackKind`, `RideType`, `WayKind`, `SurfaceClass`, `SurfaceSource`, `EdgeSurface`, `OsmTrackType`, `Access` (pub) | Input and request enums of §12.1 and §12.7. |
| `NetworkParameters` (pub record) | Builder tunables (§3.1), with `defaults()`. |
| `LocalProjection` | §1. `toX/toY(lat, lon)`, `toLatLon(x, y)`, `distance(x1,y1,x2,y2)`. |
| `Geo` | Static helpers on projected polylines: `pointAt(xs, ys, offsetM)`, `bearingDeg(x1,y1,x2,y2)` (0 = north, clockwise), `turnAngleDeg(inBearing, outBearing)` ∈ [0,180], `pointSegmentDistance`, `resample(xs, ys, n)`. |
| `SpatialGrid` | Uniform hash grid on projected coordinates (`long` cell key → `int[]` growable list). Two uses: nodes (merge, via-point snap) and edge segments (snap, corridor). |
| `States` | Static helpers on directed edge states: `state = 2·edge + dir` (dir 0 = u→v, 1 = v→u); `edge(s) = s >>> 1`, `rev(s) = s ^ 1`, `fwd(e) = e << 1`, `bwd(e) = (e << 1) \| 1`. |
| `NetworkGraph` (pub, immutable, thread-safe) | Arrays for nodes, edges, CSR adjacency, geometry, headings, corridor lists, bridges and 2-edge-connected components (§3.2). Shared across threads by the lot 3 cache: **everything is computed eagerly in the builder**, no lazy field. |
| `NetworkGraphBuilder` (pub) | `static NetworkGraph build(List<TrackInput> tracks, NetworkParameters p)`. §3.3. |
| `BridgeFinder` | Iterative bridges + 2-edge-connected component labelling (§4.1). Called by the builder. |
| `QueryGraph` (pub) | A `NetworkGraph` view plus up to two split points (S and E snapped mid-edge). The **only** graph type the search and the checker consume (§3.5). |
| `Snapper` | Nearest point on the network within `snapMaxM` (§3.5). |
| `MinHeap` | Binary heap of `(double key, int value)` on primitive arrays, ties broken by smaller value. |
| `EdgeDijkstra` | Edge-based (directed-state) Dijkstra/A* with the turn rule, one-way rule, edge ban, node penalties; one-to-one, one-to-set, one-to-all; forward or backward (§4.2). |
| `EdgeDisjointPaths` | Suurballe on the split line graph with truncated potentials and a virtual sink joined to S and E (§4.3). |
| `RouteGuarantees` (pub) | Independent checker of plan §2 hard guarantees (§6). |
| `GuaranteeReport` (pub record), `Violation` (pub enum) | Its output. |

### PART B — generator

| Class | Responsibility |
|---|---|
| `Bearing8` (pub enum) | `N, NE, E, SE, S, SW, W, NW` with `degrees()`. |
| ~~`SurfacePreference`~~ | **Deleted** (§12.7): replaced by `RideType` (`ROAD`, `GRAVEL`, `MTB`), plan §5.5. |
| `GeneratorRequest` (pub record) | `(LatLon start, @Nullable LatLon end, @Nullable Bearing8 bearing, double distanceM, double familiarity, RideType type, long seed)`. `end == null` ⇒ loop. No 10–300 km check here (lot 3 validates; tests use 16 km). Compact constructor rejects `distanceM <= 0` and `familiarity ∉ [0,1]`. |
| `GeneratorParameters` (pub record) | All search/scoring tunables (§5.1), `defaults()`. |
| `GeneratorFailure` (pub enum) | `START_TOO_FAR`, `END_TOO_FAR`, `DISTANCE_TOO_SHORT`, `NETWORK_TOO_SMALL`, `NO_ROUTE` — the plan §6 names minus the `GENERATOR_` prefix (lot 3 maps them; `ROUTE_PLANNER_DISABLED` is lot 3's). |
| `GeneratorResult` (pub sealed) | `Success(List<GeneratedRoute> routes, double networkLengthM, GeneratorDiagnostics diagnostics)` \| `Failure(GeneratorFailure reason, @Nullable String detail, GeneratorDiagnostics diagnostics)`. |
| `GeneratedRoute` (pub record) | Output, §5.9. |
| `RouteStep` (pub record) | `(int edgeId, boolean forward)` — `NetworkGraph` edge id (a virtual split piece reports its parent edge). |
| `GeneratorDiagnostics` (pub record) | Counters for the bench: candidates per family, valid per family, `EnumMap<Violation,Integer>` rejections, Suurballe infeasible count. Never influences the result. |
| `RouteGenerator` (pub) | `RouteGenerator(GeneratorParameters p)`; `GeneratorResult generate(NetworkGraph g, GeneratorRequest r)`. Orchestrator, stateless, thread-safe (allocates per call). |
| `QueryContext` | Per-call state: query graph, weights array, banned-edge bitset, anchors, tails, one-to-all trees, `Random`, `D`, `Dc`, whether θ applies. |
| `EdgeWeights` | Builds `double[] w` per state for a request (§5.3). |
| `TailPlanner` | Anchor nodes and tail paths at S and E (§5.4). |
| `LoopFamily` | "Out by one side, back by the other": turning points + `EdgeDisjointPaths` (§5.5). |
| `PolygonFamily` | Polygon via points + blacklisted legs + secant radius (§5.6). |
| `Candidate` | `int[] states` (full route on the query graph) + family tag. |
| `CandidateScorer` | Metrics + score (§5.7); uses the `GuaranteeReport` for `sharedM`/`crossings`. |
| `CandidateSelector` | Top 3 diverse (§5.8). |
| `RouteAssembler` | `int[] states` → `GeneratedRoute` (§5.9). |

Test-side helpers: `TestNetwork` (DSL to build `TrackInput`s from named nodes placed in metres),
`GridNetwork` (synthetic grid generator), `RandomNetworks` (property tests).

---

## 3. Model and graph (PART A)

### 3.1 `NetworkParameters` (defaults)

| Field | Default | Meaning |
|---|---|---|
| `nodeMergeM` | 2.5 | merge two nodes closer than this (plan §3.1: 2–3 m) |
| `dedupMeanDistM` | 10 | two instances between the same nodes are the same edge if mean resampled distance below this … |
| `dedupLengthRatio` | 0.15 | … and lengths differ by less than 15 % |
| `dedupSamples` | 16 | resample count for that comparison |
| `headingNearM`, `headingFarM` | 30, 50 | heading window from the junction (plan §2.2) |
| `corridorDistM` | 25 | corridor: other edge within 25 m … |
| `corridorMinOverlapM` | 200 | … over 200 m (plan §5.2) … |
| `corridorEndIgnoreM` | 30 | … ignoring the first/last 30 m of the edge (junction drawing) |
| `corridorSampleStepM` | 10 | sampling step |
| `minEdgeLengthM` | 1.0 | drop degenerate edges |

§12.3 changes `dedupLengthRatio` to 0.03 (plus `dedupLengthAbsM` 5) and adds `coverageGapM`,
`supportMinCoverM`, `supportMinCoverShare`, `contractionMaxTurnDeg`.

### 3.2 `NetworkGraph` data layout

Integers index everything. `N` nodes, `E` edges, `2E` states.

```
// nodes
double[] nodeLat, nodeLon, nodeX, nodeY
int[]    nodeDegree          // undirected incident edge count in the TEAM graph (self-loop counts 2)
boolean[] nodeDangling       // synthetic end of a stub (unknown end)
int[]    nodeComponent       // 2-edge-connected component id
// edges
int[]    edgeU, edgeV
double[] edgeLength          // metres (input lengthM)
float[]  gainUV, lossUV      // in u→v direction; gain(v→u) = lossUV, loss(v→u) = gainUV
boolean[] allowUV, allowVU   // one-way rule applied (§3.3 step 5)
int[]    support             // distinct non-excluded tracks (all kinds)
int[]    supportByKind       // 4 per edge: ROAD, GRAVEL, MTB, MIXED (§12.3 step 6)
float[]  z                   // all-kinds familiarity, diagnostics only; the search uses the
                             //   per-request z of §12.7
byte[]   wayKind, surfaceClass, surfaceDetail, surfaceSource, trackType, bicycle, foot  // §12.3
boolean[] bridge
// geometry, u→v order, concatenated
int[]    geomOffset (E+1); double[] geomLat, geomLon, geomX, geomY
// headings per state (degrees, 0 = north)
float[]  startHeading (2E), endHeading (2E)
// adjacency, CSR: states leaving each node
int[]    adjOffset (N+1), adjState
// corridor relation, CSR, symmetric
int[]    corridorOffset (E+1), corridorEdge
double[] componentLength     // per component id, sum of edge lengths (bridges excluded)
SpatialGrid nodeGrid, segmentGrid
LocalProjection projection; NetworkParameters parameters; NetworkStats stats
```

Public read accessors only (`nodeCount()`, `edgeU(e)`, `allowed(state)`, `tail(state)`,
`head(state)`, `length(e)`, `gain(state)`, `startHeading(state)`, `outStates(node)` as
`(from, to)` CSR range + `adjState(i)`, `geometryLatLon(state)` (allocating, for output and tests),
`isBridge(e)`, `component(node)`, `componentLength(c)`, `corridorNeighbours(e)`, `support(e)`,
`z(e)`, `surface(e)`, `dangling(node)`). Arrays are never exposed.

`NetworkStats` (pub record): `trackCount`, `excludedTrackCount`, `inputEdgeCount`, `edgeCount`,
`nodeCount`, `totalLengthM`, `danglingStubCount`, `maxSupport`.

### 3.3 `NetworkGraphBuilder.build` — steps

> **Steps 1 to 5 and 7 below are superseded by §12.3** (observations attached to the complete
> edge by node pair and offsets, no padding, stitched coverage, contraction on equal track sets
> and on a measured turn below 120°). Kept for the history of the review.

Input tracks are processed **sorted by `trackId`**, edges in their order: this fixes every
"first seen" choice below.

1. **Nodes by key.** `LinkedHashMap<String,Integer> keyToNode`. For each `TrackEdge` end with a
   non-null `NodeRef`, create or reuse the node (position = first seen). A null end creates a
   fresh **dangling node** at the geometry's corresponding extremity (never key-merged).
2. **Nodes by distance.** Union-find over non-dangling nodes: insert each into `nodeGrid` (cell =
   `nodeMergeM`), query the 3×3 neighbouring cells, union pairs closer than `nodeMergeM`.
   Representative = smallest index, position = representative's. Transitive chains (A–B 2 m,
   B–C 2 m) merge A and C: accepted, documented in the test. Dangling nodes are then merged the
   same way but only with other dangling nodes hanging off the same known node (see step 4).
3. **Observations.** For each `TrackEdge` with resolved ends `(a, b)` (after union-find), build an
   observation: `{trackId, excluded, a, b, geometry (projected), lengthM, gainM, lossM, oneway,
   unpaved, partial}`. If `a == b` and `lengthM < 2·nodeMergeM`, drop it (connector artefact
   collapsed by the merge). Partial edges with both ends known: if the geometry does not reach a
   node position within 5 m, prepend/append the node position (the geometry stays
   "on-road" enough for display; the length is `max(lengthM, polyline length)`).
4. **Undirected dedup.** Key = `(min(a,b), max(a,b))` → list of candidate edges. Orient each
   observation to the candidate's u→v (reverse geometry, swap gain/loss, and remember the
   observed direction). It joins an existing candidate if `|len1 − len2| / max < dedupLengthRatio`
   and the mean distance of `dedupSamples` resampled points is `< dedupMeanDistM`; otherwise it
   creates a new candidate (two distinct parallel roads between the same junctions survive).
   Stubs (one dangling end) dedup on `(knownNode, *)`: same comparison over the shorter's length;
   the merged stub keeps the longer geometry and its dangling node.
5. **Aggregate each candidate edge.**
   - `support` = number of distinct `trackId` among **non-excluded** observations. Support 0 ⇒
     edge dropped (only excluded tracks use it — plan §10.8).
   - Canonical observation = first non-excluded, non-partial one, else first non-excluded one:
     it gives geometry, length, gain/loss.
   - Observed directions `obsUV`, `obsVU` from non-excluded observations only.
   - One-way rule (plan §4): `oneway = any non-excluded observation has FORWARD or AGAINST`.
     If `oneway`: `allowUV = obsUV`, `allowVU = obsVU` (FORWARD and AGAINST alike: the team rode
     it that way, contraflow included). Else both allowed. *Conservative on conflict*: one
     observation saying one-way wins over others saying `BOTH` (tile update).
   - `surface`: majority of non-null `unpaved` values (tie ⇒ UNPAVED), UNKNOWN if all null.
6. **Drop isolated nodes**, renumber.
7. **Contract degree-2 nodes.** Worklist over nodes with team degree 2, not dangling. Let the two
   incident edges be `e1 = (a, n)`, `e2 = (n, b)`. Contract only if: `e1 ≠ e2`; `a ≠ b` (no
   self-loop creation); `a ≠ n`, `b ≠ n`; same `support`; same `surface`; merged
   `allow(a→b) = allow(a→n) ∧ allow(n→b)`, `allow(b→a) = allow(b→n) ∧ allow(n→a)`, and at least
   one is true. Merged edge: concatenated geometry (joint point once), summed length and
   gain/loss (oriented), same support/surface. Repeat until no change (each contraction can make
   the neighbour eligible — push `a` and `b` back on the worklist). Then compact arrays.
   Homogeneous contraction is lossless for weights; along one street the team-graph degree-2
   nodes almost always have equal support, so the gain is kept.
8. **Final arrays**: z, CSR adjacency (states sorted by state id within a node), headings (§3.4),
   `BridgeFinder` (§4.1), `componentLength`, `segmentGrid` (cell 50 m, each segment inserted in
   the cells of its bounding box), corridor relation (§3.7).

Complexity: O(M + M·k) for M input edges (hash maps, grid queries with k ≈ neighbours), plus
corridor detection O(total length / step). Target: < 3 s for 50 k output edges (measured, not
asserted strictly — see §8).

### 3.4 Headings

For a state of length L (projected polyline in travel order):

```
far  = min(headingFarM, L)
near = min(headingNearM, far / 2)
startHeading = bearing(pointAt(near), pointAt(far))
endHeading   = bearing(pointAt(L − far), pointAt(L − near))
if the two points are < 0.5 m apart: use the chord bearing(first, last)
```

Only the forward state is computed from geometry; `startHeading(rev s) = endHeading(s) + 180`,
`endHeading(rev s) = startHeading(s) + 180` (mod 360) — same points, opposite direction.

Turn angle at a node: `δ = turnAngleDeg(endHeading(in), startHeading(out)) =
|((out − in + 540) mod 360) − 180|`; 0 = straight on, 180 = full U-turn.

**Where the turn rule applies** (corrected, §12.4 — review B1): at **every real node** of the
team graph, whatever its team degree, measured on 30–50 m windows walked along the route. Exempt:
virtual S/E nodes, dangling coverage ends (never interior anyway) and a node whose street degree
is 2. Every node osm-route-details reports is a street junction or a dead end (degree ≠ 2), so the
former "mountain hairpin at a degree-2 node" exemption protected nothing real and let a U-turn
through a short connector between two degree-2 nodes pass. A hairpin *inside* an edge geometry is
never checked, and contraction refuses a node whose turn is ≥ 120° (§12.3 step 8).

### 3.5 `QueryGraph` and snapping

`Snapper.snap(NetworkGraph g, LatLon p, double maxM)` → `@Nullable Snap(int edge, double offsetM,
LatLon point, double distanceM)`: search `segmentGrid` in growing rings (50 m cells) until a hit is
found and the ring radius exceeds the best distance, up to `maxM`. Ties: smaller edge id. Offset =
along-edge metres from `u`, using the projected polyline scaled to `edgeLength` (factor
`edgeLength / projectedLength` so offsets are in the same metres as lengths).

`QueryGraph.create(NetworkGraph g, List<Snap> snaps, double snapToNodeM)`:

- A snap within `snapToNodeM` (30 m) of an end node (in offset terms: `offset < 30` or
  `> L − 30`) becomes that node — no split.
- Otherwise the edge is split: group snaps per edge, sort by offset, create virtual nodes
  `N, N+1` and virtual edges `E, E+1, …` forming the chain `u → s1 → (s2) → v`. Virtual edge
  attributes: sliced geometry (interpolated cut point), length = offset difference, gain/loss
  pro rata of length, same allow flags, support, z, surface, recomputed headings, corridor
  neighbours = parent's; `parentEdge(e')` gives the original id. The parent edge is **masked**:
  adjacency of `u` and `v` lists the virtual states instead of the parent's.
- S and E at the same point (loop) ⇒ one virtual node used for both.
- Virtual node degree = 2, component: parent's component, or a new trivial component id if the
  parent is a bridge (splitting a bridge yields two bridges).

`QueryGraph` re-exposes every `NetworkGraph` accessor over `N' = N + v`, `E' = E + w`;
`QueryGraph.of(g)` has no split (tests of algorithms use it). Adjacency of `u`/`v` is
materialised in two small override arrays; all other nodes delegate to the base CSR.

Snapping onto a **dangling stub** is allowed: the route leaves along the stub towards its known
node. Since §12.3 a stub only exists where the team really never rode the rest of the street (two
partial observations from both ends meeting at the team location are stitched into the complete
edge, review M2), so S no longer snaps onto a phantom dead end lying along a complete edge.

### 3.6 Use of `streetDegree`

Corrected (§12.4): the turn rule's only exemption among real nodes is `streetDegree == 2`
(never produced by api 1.7, kept so that a producer change or a hand-built test network does not
turn a plain bend into a "junction"). The team-graph degree still drives dead ends. When several
observations disagree (data versions), the node keeps the maximum.

### 3.7 Corridor relation

```
for each edge a:
  sampledLen = len(a) − 2·corridorEndIgnoreM; if sampledLen ≤ 0: continue
  overlap = LinkedHashMap<Integer, Double>
  for each sample p every corridorSampleStepM on a, from 30 m to len−30 m:
     for each edge b ≠ a in segmentGrid cells within corridorDistM of p (dedup per sample):
        if distance(p, polyline b) ≤ corridorDistM: overlap[b] += step
  threshold = min(corridorMinOverlapM, 0.8 · sampledLen)
  for b with overlap[b] ≥ threshold: add pair (a, b) and (b, a)
sort each list, store CSR
```

Catches both carriageways of a dual carriageway and a cycle path beside the road. Two different
edges that are the same road in sequence never qualify: the 30 m end ignore keeps samples away
from their shared node.

---

## 4. Graph algorithms (PART A)

### 4.1 Bridges and 2-edge-connected components — `BridgeFinder`

Iterative Tarjan low-link on the undirected multigraph; parallel edges handled by skipping the
**parent edge id** (not the parent node), self-loops ignored (never bridges).

```
tin[], low[] = -1; timer = 0
for root in 0..N-1 with tin[root] == -1:
  stack of frames (node, parentEdge, nextAdjIndex)
  push (root, -1, adjOffset[root]); tin[root] = low[root] = timer++
  while stack not empty:
    f = top
    if f.next < adjOffset[f.node+1]:
       s = adjState[f.next++]; e = edge(s); w = head(s)
       if e == f.parentEdge or w == f.node: continue      // skip parent edge and self-loops
       if tin[w] == -1: tin[w] = low[w] = timer++; push (w, e, adjOffset[w])
       else low[f.node] = min(low[f.node], tin[w])
    else:
       pop f
       if f.parentEdge != -1:
          p = other end of f.parentEdge
          low[p] = min(low[p], low[f.node])
          if low[f.node] > tin[p]: bridge[f.parentEdge] = true
```

Components: BFS from each unlabelled node over non-bridge edges; ids in discovery order.
A component with no internal edge is **trivial** (a node on a tree part). `componentLength[c]` =
sum of non-bridge edge lengths inside `c`. O(N + E), no recursion (graphs reach ~50 k edges; a
long chain would overflow a recursive version).

### 4.2 Edge-based Dijkstra / A* — `EdgeDijkstra`

The search runs on **directed edge states**: the label of state `s` is the cost of a path that
ends by traversing `s` completely. Turns and one-ways are enforced during relaxation.

```java
final class EdgeDijkstra {
  EdgeDijkstra(QueryGraph g);                 // arrays sized 2E', reset via a touched list
  Result search(Request r);
  record Request(
      boolean backward,                       // backward = search towards the sources from targets
      int[] sourceStates, double[] sourceCosts, double[] sourceMetres,
      @Nullable IntPredicate targetState,     // null = one-to-all
      double[] stateWeight,                   // §5.3, indexed by state
      BitSet bannedEdges,                     // by query-graph edge id
      @Nullable double[] nodePenalty,         // added when the path passes through a node
      double costLimit,                       // stop when the popped cost exceeds it
      @Nullable LatLon aStarTarget, double aStarFactor);  // A* lower bound, see below
  record Result(int targetState /* -1 */, double[] cost, int[] pred, double[] metres) {
    int[] path(int state);                    // states from a source to `state`, in search order
  }
}
```

Forward relaxation, popping `s` with head `h = head(s)`:

```
for s2 in outStates(h):
   if s2 == rev(s)                          continue   // no U-turn on the same edge
   if !allowed(s2) or banned(edge(s2))      continue   // one-way, blacklist, corridor, surface
   if !SearchTurns.ok(g, pred, s, s2, maxTurnDeg)  continue   // corrected, §12.4: every real
                                                              // node, walked windows
   c = cost[s] + w[s2] + (nodePenalty == null ? 0 : nodePenalty[h])
   if c < cost[s2]: cost[s2] = c; metres[s2] = metres[s] + length(edge(s2)); pred[s2] = s; push
```

Backward mode (labels = cost from the state to a target; sources are the states arriving at the
target, `sourceCosts` = their own weight): popping `s` with tail `t = tail(s)`, iterate states
`s0` **arriving** at `t` (`rev` of `outStates(t)`), with the same rules applied to the transition
`s0 → s` (`s0 ≠ rev(s)`, `allowed(s0)`, turn on `endHeading(s0)` → `startHeading(s)` at `t`). The
path read via `pred` is then already in travel order.

- Sources: the first edge of a path is a source state with its weight included. The caller
  builds them: "all allowed states leaving node x", or "states allowed after arriving by state
  `last`" (continuation of a previous leg — applies the turn rule at the junction between legs).
- A* (one-to-one legs only): key = `cost + aStarFactor · euclid(head(s), target)`, with
  `aStarFactor = g.aStarScale() · minWeightPerMetre` (`minWeightPerMetre` = min over states of
  `w[s] / length`). Corrected (§12.8, review minor): the fixed `0.97` projection margin failed
  beyond ±1.5° of latitude; `aStarScale` is now measured on the graph itself. Node penalties are
  ≥ 0, so they keep it admissible.
- Lazy deletion in `MinHeap`: skip a popped entry whose key is stale.
- Complexity: O((S + T) log S) with S = 2E' states and T = Σ_v deg(v)² transitions (~3–4 × S on
  road graphs).

### 4.3 Two edge-disjoint paths with a virtual sink — `EdgeDisjointPaths`

Goal (plan §5.2): from a turning point T, two **edge-disjoint** paths T → A_S and T → A_E, where
A_S/A_E are the anchors (S/E or their tail anchors, §5.4); route = reverse(path to A_S) + path to
A_E. When A_S = A_E this is the loop case.

**Graph L′** (implicit, never materialised): the line graph of states, with each state split in
two so a state carries capacity 1:

```
vertex ids: in(s) = 2s, out(s) = 2s + 1           s ∈ [0, 2E')
            σT = 4E', σS = 4E' + 1, σE = 4E' + 2, τ = 4E' + 3
arcs (capacity 1):
  in(s)  → out(s)    cost w[s]                     (traverse the edge)
  out(s) → in(s2)    cost 0  for an allowed transition s → s2 (same rules as §4.2 forward)
  σT     → in(s)     cost 0  for allowed s leaving T, not banned
  out(s) → σS        cost 0  if head(s) == A_S and (tailS empty, or the route transition
                             tailS.last → rev(s) is valid at A_S)
  out(s) → σE        cost 0  if head(s) == A_E and (tailE empty, or s → tailE.first valid at A_E)
  σS → τ, σE → τ     cost 0  capacity 1 each; if A_S == A_E: σE is not used and σS → τ has capacity 2
```

**Suurballe with truncated potentials** (two Dijkstras, no negative-weight search):

```
// Pass 1 — plain Dijkstra on L′ from σT, stop when τ is settled.
dist1[], pred1[]; D1 = dist1[τ]; if τ unreachable → INFEASIBLE
π(v) = min(dist1[v], D1)      // unsettled or unreached vertices get D1: keeps reduced costs ≥ 0
P1 = σT ⇝ τ from pred1; record succ1[v] (next vertex on P1) and pred1on[v] (previous) for v ∈ P1
// Pass 2 — Dijkstra on the residual graph with reduced costs c'(x,y) = c(x,y) + π(x) − π(y)
out-arcs of x in the residual:
  every L′ arc (x, y) except the saturated one (y == succ1[x]; for σS → τ only when its capacity is 1)
  plus the reverse arc (x, pred1on[x]) if x ∈ P1 \ {σT}, cost −c(pred1on[x], x)
  (reduced cost of a reverse arc on P1 is 0; assert every c' ≥ −1e−9)
stop when τ is settled; if unreachable → INFEASIBLE
// Combine
arcs = P1 ∪ P2 minus every pair (x→y ∈ P1, y→x ∈ P2)          // cancellation
decompose: from σT follow remaining arcs twice (σT has two out-arcs; every other vertex has
           at most one remaining out-arc, σS may have two when capacity 2) → two vertex paths
extract states: the s with in(s) → out(s) on each path, in order
```

Mapping back: the path that ends through σS is the "S side": route part = `rev(s_k), …, rev(s_1)`
(A_S → T); the other is the "E side" as is (T → A_E). Loop case (both end through σS): try both
assignments; keep the first that passes the post-checks below.

**Post-checks on the assembled core** (the flow does not model them; failures make the turning
point infeasible and are counted in diagnostics):

1. **One-way on the S side**: the flow traversed those states towards T, the route traverses their
   reverse: every `rev(s)` must be `allowed`. (The flow treats one-way edges as usable in the flow
   direction only; that is exact for the E side and checked for the S side. One-ways are rare in
   team networks except roundabouts; this is where the loop case's "try both assignments" helps.)
2. **Opposite directions of one edge**: split vertices give capacity per state, not per undirected
   edge, so the two paths could use `s` and `rev(s)`. Reject if any edge appears in both paths.
3. **Turn at T**: transition from `rev(s_1)` (S side, arriving at T) to the first E-side state must
   be valid (not a reverse, δ < 150° at a real node, §12.4). Plan §5.2: "T écarté s'il y en a un".
4. **Joins with the tails** (added, §12.6 — review M3): `tailS.last → core[0]` and
   `core[last] → tailE.first` must be valid turns; the arc to σS accepts either side in a loop, so
   the flow alone does not guarantee them.

Fallback for a turning point whose flow fails post-check 1 or 2: the sequential heuristic — shortest
T → A_E (forward), ban its edges and their corridor neighbours, shortest A_S → T (forward) arriving
in a state compatible with the first E-side state. One extra pair of A* searches; exact for
directions.

Complexity per T: two Dijkstras on 4E' + 4 vertices with ~(S + T) arcs, each bounded by D1-ish
cost (pass 1 stops at τ). Memory: `dist`/`pred` arrays of 4E' reused across turning points.

---

## 5. The generator (PART B)

### 5.1 `GeneratorParameters` (defaults; β and penalties are re-tuned on the bench)

| Group | Field | Default |
|---|---|---|
| Snap | `snapMaxM`, `snapToNodeM` | 2000, 30 |
| Hard rules (also read by `RouteGuarantees`) | `maxTurnDeg` | 150 |
| | `tailMaxShare` | 0.15 (tail zone and shared length ≤ 15 % of D) |
| | `maxCrossings` | 2 |
| | `distanceTolerance` | 0.10 |
| Feasibility | `distanceTooShortFactor` | 1.05 |
| | `networkTooSmallFactor` | 1.5 (road length within D/2 of S/E must be ≥ 1.5 D) |
| | `hubMinLengthFactor` | 0.6 (a loop hub component must hold ≥ 0.6 D of road) |
| Direction | `bearingSectorDeg` | 35 |
| Weights | `beta` | 1.0 |
| | `junctionPenalty`, `junctionRefM` | 0.1, 500 |
| | ~~`unpavedPenaltyAny`~~ | replaced by the per-type preference multipliers of §12.7 |
| | `crossingPenaltyM` | 2000 (search cost added on a revisited node) |
| | `tailPenaltyPerM` | 1.0 (scored, see §5.7) |
| Loop family | `turningPoints` | 16 |
| | `turningRatioMin`, `turningRatioMax` | 0.65, 0.95 (`(d(A_S,T)+d(T,A_E)) / Dc`) |
| Polygon family | `polygonEvaluations` | 32 |
| | `polygonViaMin`, `polygonViaMax` | 2, 3 |
| | `polygonJitterDeg` | 15 |
| | `initialDetour` | 1.3 |
| | `secantIterations` | 3 |
| | `viaMaxSnapFactor` | 0.5 (via node must lie within 0.5·r of the geometric point) |
| Tail | `extraTailAnchors` | 1 (voluntary tail anchors besides S/E themselves) |
| Corridor | `maxCorridorShare` | 0.2 (moved into `RouteGuarantees`, §12.5) |
| Scoring | `wDistance, wShared, wCrossing, wBearing, wFamiliarity, wJunction, wCorridor` | 4, 3, 0.15, 1, 1, 0.02, 2 |
| Output | `maxResults`, `diversityMaxShared` | 3, 0.5 |

### 5.2 Pipeline of `generate`

```
1  snapS = Snapper.snap(g, start, snapMaxM) ?: return Failure(START_TOO_FAR)
   snapE = end == null ? snapS : Snapper.snap(...) ?: return Failure(END_TOO_FAR)
2  qg = QueryGraph.create(g, [snapS, snapE]); S, E = their nodes; loop = (S == E)
3  D = distanceM; thetaApplies = bearing != null && haversine(S,E) < D/2
4  z = EdgeWeights.familiarity(qg, type) (§12.7, with its fallback); w = EdgeWeights.build(qg,
   f, type, z); banned = EdgeWeights.banned(qg, type) (admission table of §12.7, except the
   virtual pieces carrying S/E)
5  if !loop: dSE = metres of EdgeDijkstra shortest S→E with weights = lengths
             unreachable → Failure(NO_ROUTE, "END_UNREACHABLE")
             D < distanceTooShortFactor · dSE → Failure(DISTANCE_TOO_SHORT)
6  reach = one-to-all forward from S (weights w, banned)
   roadNear = Σ length of reached, non-bridge edges whose midpoint is within D/2 of S or E
   roadNear < networkTooSmallFactor · D → Failure(NETWORK_TOO_SMALL)
7  anchorPairs = TailPlanner.plan(...) (§5.4); empty → Failure(NO_ROUTE, "TAIL_TOO_LONG")
8  rnd = new Random(seed); pool = []
   for each anchor pair (deterministic order):
       pool += LoopFamily.candidates(...)      (§5.5)
       pool += PolygonFamily.candidates(...)   (§5.6)
   (budgets turningPoints / polygonEvaluations are split evenly across anchor pairs)
9  for c in pool: report = RouteGuarantees.check(qg, S, E, D, c.states, params)
       !report.ok() → diagnostics.reject(report.violations()); drop   (corridor cap included, §12.5)
       else score (§5.7)
10 selected = CandidateSelector.top(scored) (§5.8); empty → Failure(NO_ROUTE)
11 return Success(selected.map(RouteAssembler::assemble), roadNear, diagnostics)
```

`Random` is consumed only in steps 8 (fixed order), so a seed fully determines the output.

### 5.3 Edge weights — `EdgeWeights`

Per state (both directions of an edge get the same weight; direction is handled by `allowed`):

```
w = length × exp(β · (1 − 2f) · z) × (1 + pJ) × pS
pJ = junctionPenalty × min(1, junctionRefM / length)     // ≈ junctionPenalty·junctionRefM per short edge,
                                                         //   ≈ ×(1+junctionPenalty) on long ones
pS = typePreference(type, edge)                          // corrected: §12.7 (route / gravel / VTT)
z  = per-request familiarity of the requested type       // corrected: §12.7, with its fallback
```

f = 1 makes popular edges (z → 1) cheaper by up to e^β; f = 0 the reverse; f = 0.5 neutral
(plan §5.2). The junction term makes a route made of many short edges cost more — a readable route
turns little. Virtual split pieces use their parent's z/surface and their own length.

### 5.4 Tails — `TailPlanner`

The **tail** is the shared out-and-back section near S or E (plan §2.4): allowed only there,
`≤ tailMaxShare · D`.

Anchors for S (same for E, on the reverse search):

- **Forced**: if `S` is in a trivial component, or (loop only) its component holds less than
  `hubMinLengthFactor · D` of road, the route must leave S's branch and come back the same way.
  Run `EdgeDijkstra` from S with **metres** as weights, edges allowed in both directions only
  (a tail is ridden both ways), stopping at the first node `X` whose component is a hub (not
  trivial and, for a loop, long enough), within `costLimit = tailMaxShare · D`. Found ⇒ anchor
  `X`, tail = that path. Not found ⇒ no anchor for S.
- **Direct**: otherwise anchor = S itself, empty tail.
- **Voluntary** (`extraTailAnchors`, default 1): also the hub node of degree ≥ 3 reached by the
  same metres search at a distance in `[0.03 D, tailMaxShare · D]` that maximises the bearing
  agreement with θ (or the first by node id when θ does not apply). Gives a route that leaves a
  dense village by its best road and comes back by it.

Pairs:

- Loop: pairs `(X, X)` with `tailE = reverse(tailS)` (each state reversed, order reversed; valid
  because tail states are allowed both ways and turn angles are symmetric).
- S ≠ E: the cartesian product of S anchors and E anchors (≤ 4 pairs). The E tail is computed by
  a backward search from E with the same rules. If S and E share a branch (café on the way out),
  the tails overlap: that overlap is the reuse, and the checker's zone rule (§6) accepts it.

For every pair, the core search bans the tail edges (`banned ∪ tailEdges`): the core never reuses
a tail. `Dc = D − length(tailS) − length(tailE)` is the core's target length; a pair with
`Dc < 0.5 D` is dropped.

Loop with no anchor ⇒ the pipeline returns `NO_ROUTE` with detail `TAIL_TOO_LONG` (the network
around S only connects to a hub beyond 15 % of D).

**Corrected for S ≠ E (§12.6 — review M4)**: the forced case above is a loop rule only. With a
distinct end, the way from S (or to E) to its component is an *approach*, ridden once: no 15 %
cap, no two-way requirement (a one-way bridge towards the core is fine), searched forward from S
and backward to E on allowed states. It only becomes a tail if the two approaches share edges,
and the checker bounds that shared part.

### 5.5 Loop family — `LoopFamily`

```
fwd = one-to-all forward from A_S (sources: states after tailS.last, or leaving A_S), w, banned
bwd = one-to-all backward to A_E (sources: states arriving at A_E compatible with tailE.first)
eligible = nodes T with
     degree(T) ≥ 3, not dangling, reached by both,
     ratio = (fwd.metres(T) + bwd.metres(T)) / Dc ∈ [turningRatioMin, turningRatioMax],
     fwd.metres(T) ≥ 0.2 · Dc,
     thetaApplies ⇒ |bearing(S, T) − θ| ≤ bearingSectorDeg
   collected in node-id order, then Collections.shuffle(eligible, rnd)
for T in eligible, until turningPoints evaluated:
     core = EdgeDisjointPaths.solve(qg, T, A_S, A_E, tailS, tailE, w, banned)  // §4.3 + fallback
     if core != null: emit Candidate(tailS + core + tailE, LOOP)
```

`fwd.metres(T)` = min metres over states with head T (stored in `Result.metres`). The ratio band
sits below 1 because the second disjoint path is longer than the shortest one; the bench moves it.
When θ does not apply (no bearing, or E far), T is anywhere in the band: the band itself places
T on the S–E ellipse.

### 5.6 Polygon family — `PolygonFamily`

One **round** = one shape; up to `secantIterations` evaluations of the radius per round; every
evaluation is a candidate in the pool and counts against `polygonEvaluations`.

```
while evaluations < polygonEvaluations:
  k   = polygonViaMin + rnd.nextInt(polygonViaMax − polygonViaMin + 1)
  dir = thetaApplies ? θ : (far E ? bearing(S,E) : rnd.nextDouble()·360)
  jit = k random angles in ±polygonJitterDeg
  shape(r):                                    // geometric via points in projected metres
     loop or E near:  centre C = mid(S,E) + r·u(dir); vertex j (1..k) at
                      C + r·u(dir + 180 + j·360/(k+1) + jit_j)
     E far:           ellipse with foci S,E, sum of focal distances = Dc / ρ; k points on one side
                      (side = rnd.nextBoolean(), fixed for the round), at fractions j/(k+1) of
                      the major axis, plus jitter of the fraction (±0.05)
  geomLen(r) = perimeter of A_S, P1..Pk, A_E;  r0 = root of geomLen(r) = Dc / ρ by bisection
               (ρ starts at initialDetour; corrected, §12.6 — review M1: the former
               Dc / (ρ · geomLen(1)) only holds when A_S = A_E)
  for i in 0..secantIterations-1:
     L_i = evaluate(shape(r_i))                // length of the core, or fail
     if fail: break
     if |L_i − Dc| ≤ 0.05·Dc: break
     r_{i+1} = i == 0 ? r_i · Dc / L_i
                      : r_i + (Dc − L_i)(r_i − r_{i−1}) / (L_i − L_{i−1})   (guard L_i == L_{i−1})
     clamp r_{i+1} to [0.5 r_i, 1.5 r_i]
  ρ = 0.7·ρ + 0.3·(L_last / geomLen(r_last))   // detour estimate carried to the next round
```

`evaluate(points)`:

```
via = for each Pi: nearest node of degree ≥ 3 in nodeGrid that `fwd` reached and is not on a tail;
      reject if farther than viaMaxSnapFactor · r; drop consecutive duplicates
used = BitSet (core edges so far); visited = node penalty array (touched list)
last = tailS.last (or none); legs targets: via…, then A_E
for each target X:
   sources = last == none ? allowed states leaving A_S : allowed continuations of `last`
   ban     = banned ∪ tailEdges ∪ used ∪ corridorNeighbours(used)
   target  = X == A_E && tailE non-empty ? (s → head(s) == A_E && s → tailE.first valid)
                                         : head(s) == X
   leg = EdgeDijkstra A* (w, ban, nodePenalty = crossingPenaltyM on visited nodes except the
         leg's start node, costLimit = 3·Dc)
   if no leg: fail
   used += edges(leg); visited += nodes(leg); last = leg.last
core = concatenated legs; emit Candidate(tailS + core + tailE, POLYGON); return length(core)
```

Banning used edges makes reuse in the core impossible by construction; the corridor ban removes
the dual-carriageway and parallel-path doubling; node penalties discourage crossings (the checker
bounds them).

### 5.7 Scoring — `CandidateScorer`

For a candidate that passed `RouteGuarantees` (report gives `lengthM`, `sharedM`, `crossings`):

```
distErr     = |L − D| / D
shared      = sharedM / D
crossings   = report.crossings
bearingDev  = thetaApplies ? |angleDiff(bearing(S, barycentre), θ)| : null   // degrees
              barycentre = length-weighted mean of segment midpoints (projected)
famDev      = |f − zMean|,  zMean = Σ len·z / Σ len
junctions   = interior route nodes with degree ≥ 3, per 10 km
corridor    = length of core edges having a corridor neighbour also in the core / core length

score = wDistance·distErr + wShared·shared + wCrossing·crossings
      + wBearing·(bearingDev == null ? 0 : bearingDev / 180)
      + wFamiliarity·famDev + wJunction·junctions + wCorridor·corridor
```

Lower is better. Ties: generation order (stable sort), which is deterministic.

### 5.8 Selection — `CandidateSelector`

Drop exact duplicates (same `int[] states`, via `Arrays.hashCode` + `equals`). Sort by score; take
greedily while `selected.size() < maxResults`: accept `c` if for every selected `x`,
`overlapM(c, x) / min(len(c), len(x)) < diversityMaxShared`, where `overlapM` is the length of
the parent edges (undirected) present in both. Fewer than three is fine; zero ⇒ `NO_ROUTE`.

### 5.9 Output — `RouteAssembler` and `GeneratedRoute`

```java
public record GeneratedRoute(
    List<LatLon> points,              // concatenated geometry in travel order, joints once
    double distanceM,                 // Σ edge lengths
    double ascentM, double descentM,  // Σ gain/loss of each state in its direction
    @Nullable Double bearingDeviationDeg,   // null when θ does not apply
    double familiarity,               // zMean, 0..1
    double unpavedShare,              // UNPAVED length / distance (UNKNOWN counts as not unpaved)
    double sharedM,                   // from GuaranteeReport
    int crossings,                    // from GuaranteeReport
    List<RouteStep> steps) {}         // parent edge ids + direction, in order
```

Geometry of a backward state = parent geometry reversed; of a virtual piece = its slice. The first
point of each state after the first is skipped (it equals the previous last point).

---

## 6. `RouteGuarantees` — the independent checker (PART A)

```java
public final class RouteGuarantees {
  public static GuaranteeReport check(QueryGraph g, int startNode, int endNode,
                                      double targetM, int[] states, GeneratorParameters p);
}
public record GuaranteeReport(EnumSet<Violation> violations, double lengthM,
                              double sharedM, int crossings) { public boolean ok() {...} }
public enum Violation {
  EMPTY, WRONG_START, WRONG_END, DISCONTINUOUS, NOT_ON_NETWORK, ONE_WAY,
  U_TURN, SHARP_TURN, DEAD_END, EDGE_USED_MORE_THAN_TWICE, REUSE_OUTSIDE_TAIL,
  TAIL_TOO_LONG, TOO_MANY_CROSSINGS, DISTANCE_OUT_OF_TOLERANCE,
  CORRIDOR_DOUBLED }                                  // added, §12.5
```

**Independence**: it uses only `QueryGraph` primitive accessors (endpoints, length, allowed,
degree, dangling, geometry). It does **not** use the precomputed heading arrays, `EdgeDijkstra`,
the weights or anything of the generator: it recomputes headings from geometry with its own
private method (same 30/50 m window, read from `g.parameters()`). It is the formal definition of
plan §2; a disagreement with the generator is a generator bug.

Checks on route `e_1 … e_n` (states), nodes `v_0 = tail(e_1), v_i = head(e_i)`:

1. **Only team edges / continuity**: `n ≥ 1`; every state id valid; `v_0 == startNode`,
   `v_n == endNode`; `head(e_i) == tail(e_{i+1})`; every `allowed(e_i)` (else `ONE_WAY`).
2. **No U-turn**: `e_{i+1} ≠ rev(e_i)` (`U_TURN`); at every real `v_i` (corrected, §12.4: any
   team degree; exempt only virtual nodes and `streetDegree == 2`), turn angle on windows walked
   along the route `< maxTurnDeg` (`SHARP_TURN`).
3. **No dead end**: no interior node `v_i` (0 < i < n) with degree < 2 or dangling (`DEAD_END`).
   Together with 2 this is plan §2.3: a dead end can only be left by a U-turn.
4. **Reuse only in the tail**: count occurrences per undirected query edge. Any count ≥ 3 ⇒
   `EDGE_USED_MORE_THAN_TWICE`. Let `R` = edges with count 2. Mark positions `i` with
   `edge(e_i) ∈ R`. The **core** = the longest (in metres) contiguous run of unmarked positions
   (if `R` is empty, the whole route; tie ⇒ earliest). Start zone = positions before the core,
   end zone = after it. Then:
   - every marked position lies in a zone — true by construction; the real constraint is
     `length(startZone) ≤ tailMaxShare·D` and `length(endZone) ≤ tailMaxShare·D`, else
     `REUSE_OUTSIDE_TAIL` (a reuse in the middle leaves a long R-free block on both sides, so one
     of them becomes a zone longer than 15 %);
   - `sharedM = Σ length(R)` (each shared edge counted once) `≤ tailMaxShare·D`, else
     `TAIL_TOO_LONG`.
   This accepts: S on a branch (`S→A`, loop, `A→S`), and the café on the way out
   (`S→E→A`, loop, `A→E`: start zone `S→E→A`, end zone `A→E`).
5. **Crossings** (only the core counts; `k` = index of the core's first node, `m` = its last):

   ```
   tailInner = nodes of the start zone except v_k, nodes of the end zone except v_m
   seen = {v_k}; crossings = 0
   for i in k+1 .. m:
      closure = (i == m) && v_i == v_k            // a loop closing on itself is not a crossing
      if !closure && (seen.contains(v_i) || tailInner.contains(v_i)): crossings++
      seen.add(v_i)
   ```
   `crossings > maxCrossings` ⇒ `TOO_MANY_CROSSINGS`. A pure loop S→…→S has `v_k = v_m = S`:
   closure. A figure-eight through one junction counts 1.
6. **Distance**: `lengthM = Σ length(edge(e_i))`; `|lengthM − D| > distanceTolerance·D` ⇒
   `DISTANCE_OUT_OF_TOLERANCE`.

O(n). The generator calls it on every candidate; `RouteGenerator` never returns a route whose
report is not `ok()`, and the property tests (§7.3) re-run it from the test side.

7. **Corridor doubling** (added, §12.5): measured from the route's own geometry, capped at
   `maxCorridorShare` of the core (`CORRIDOR_DOUBLED`). Plan §2 lists the corridor as a
   preference; the cap is a safety net the generator applied outside the checker before the
   review (B1), now inside it so that no path to the output skips it.

Not a guarantee (scored only): corridor doubling below the cap, bearing, familiarity, the 15 %
*radius* around S/E (the search uses it, the checker bounds zone lengths, which is the stricter,
measurable form).

The checker trusts the `QueryGraph` (split, degrees, allowed flags): a builder bug is invisible to
it. The raw-input oracle of §12.9 is the test-side answer to that (review minor).

---

## 7. Test plan

All tests are plain JUnit 5 (no `@QuarkusTest`). `TestNetwork` builds `TrackInput`s:

```java
TestNetwork net = new TestNetwork(45.0, 5.0);       // reference lat/lon; nodes placed in metres
net.node("A", 0, 0).node("B", 4000, 0);             // x east, y north
net.track(1, "A", "B", "C");                        // one track, straight edges between named nodes
net.track(2).via("A", "B").oneway(FORWARD).support... // builder variants: oneway, unpaved, partial,
net.track(3).excluded().via("B", "C");              //   excluded, curved geometry (bend points)
net.stub(4, "B", 300, 90);                          // edge from B, 300 m at bearing 90°, null end
NetworkGraph g = net.build();                       // NetworkParameters.defaults()
```

Lengths are computed by haversine on the generated geometry; node keys = node names; a node can
be given a second key at an offset (`net.alias("J", "J2", 1.8, 0)`) for merge tests. Support `n`
is obtained by `n` tracks over the same edges.

### 7.1 PART A tests

`GeoTest` — bearings of the four axes; `turnAngleDeg` symmetric, 0 for straight, 180 for reverse;
`pointAt` clamps; projection round trip < 1 mm near the reference.

`NetworkGraphBuilderTest`
- same edge from two tracks in opposite directions → 1 edge, support 2, both directions observed;
- two roads between the same junctions 60 m apart → 2 edges; 5 m apart and equal length → 1;
- **node merge**: two keys 1.8 m apart → 1 node of degree 3; 3.0 m apart → 2 nodes; chain of two
  2 m gaps → merged (documented transitive behaviour);
- `FORWARD` observed A→B only → `allowed(A→B)`, not `B→A`; `AGAINST` observed B→A → only B→A
  allowed; one `BOTH` + one `FORWARD` observation → one-way (conservative);
- **excluded track**: edge used only by an excluded track is absent; edge shared with a
  non-excluded track keeps support counting only the non-excluded one; directions observed only
  by the excluded track are not allowed on a one-way;
- stub with null end → dangling node of degree 1; two stubs from the same node with overlapping
  geometry → 1 stub;
- contraction: chain A–n1–n2–B with equal support → 1 edge A–B, summed length and gain; support
  change at n1 → not contracted there; two parallel edges A–n, n–A → no self-loop created;
- headings: an L-shaped edge whose first 20 m wiggles → start heading from the 30–50 m window;
  a 31 m edge → clamped window, finite heading;
- corridor: dual carriageway 15 m apart over 1 km → corridor pair; road and a crossing road → not;
  two consecutive edges of one road → not.

`BridgeFinderTest` — square + pendant edge: only the pendant is a bridge; two squares joined by one
edge: that edge; parallel edges between two nodes: neither is a bridge; self-loop ignored;
component ids and lengths; **a 200 000-node path** (no stack overflow, all bridges).

`QueryGraphTest` — snap mid-edge splits into two virtual edges with lengths summing to the parent
and gain pro rata; snap 20 m from a node returns the node; S and E on the same edge → chain
u–S–E–v; masked parent absent from adjacency; snap beyond 2 km → null; snap onto a stub.

`EdgeDijkstraTest`
- turn rule: a Y junction where the direct continuation needs δ = 160° → path takes the longer
  legal way; same graph with δ = 140° → direct;
- no U-turn: target behind the source on the same street with the only turnaround at a dead end
  → unreachable (no U-turn at the dead end);
- one-way: shortest path respects allowed directions;
- banned edges and node penalties change the path as expected;
- backward search from T equals forward search to T (costs on random graphs);
- A* returns the same cost as Dijkstra on 200 random graph/query pairs.

`EdgeDisjointPathsTest`
- classic Suurballe **trap**: the shortest T→S path blocks any disjoint second path; the
  algorithm finds the optimal disjoint pair (hand-computed total);
- virtual sink with S ≠ E: one path ends at S, the other at E;
- loop (A_S = A_E): two paths arriving at S by different states;
- infeasible when T is beyond a bridge (both paths must cross it);
- post-check 1: a one-way on the S side is caught, and the fallback produces a legal pair.

`RouteGuaranteesTest` — one valid hand-written route accepted; then one mutation per `Violation`
(wrong start, gap, reversed one-way, U-turn, 155° turn, interior dangling node, edge thrice, reuse
in the middle, 4 km shared tail for D = 20 km, three crossings, 15 % too long) → exactly that
violation; S-on-branch and café-on-the-way-out shapes accepted with the expected `sharedM`;
figure eight → `crossings == 1`.

### 7.2 PART B scenario tests (`RouteGeneratorScenarioTest`)

Each scenario asserts the result type and, for every returned route, `RouteGuarantees` ok
(re-run in the test) plus the scenario's specific property. Coordinates in metres.

| # | Graph | Request | Expected |
|---|---|---|---|
| 1 | **Dead end in a loop**: square A(0,0) B(4000,0) C(4000,4000) D(0,4000); spur B–X(6000,0), X dead end | loop at A, D = 16 km | the square (either orientation), never X. D = 20 km → `NO_ROUTE` (square + spur out-and-back would be 20 km) |
| 2 | **Bridge between two components**: squares L (A..D) and R (A′..D′, shifted 6 km east), bridge B–A′ 2 km | loop at A, D = 16 | L only. D = 36 → `NO_ROUTE` (the bridge would be reused mid-route). S at the bridge midpoint, D = 18 → tail of 1 km (`sharedM ≈ 1000`) + one square |
| 2b | same | S = D (L's far corner), E = C′ (R's far corner) | D = 18 → `DISTANCE_TOO_SHORT` (min 18 km); D = 19.5 → route of 18 km crossing the bridge once, `sharedM == 0` |
| 3 | **Dual carriageway**: A(0,0)–B(0,8000) as two one-way edges 15 m apart (north/south), 20 m connectors at both ends; west road A–W(−3000,4000)–B | loop at A, D = 17 | the dual out-and-back (16 km) satisfies the hard rules but is never returned (corridor); top route = carriageway + west road (18 km); every route's corridor share ≤ 0.2 |
| 4 | **Roundabout**: 4 one-way quarter arcs radius 20 m (counter-clockwise, observed so), arms to N/E/S/W ends 3 km away, outer ring linking the arm ends | loop at the N end, D ≈ 15 | every route rides arcs counter-clockwise only; no route enters and leaves by the same arm; a hand-written route N-arm → S-arm through the roundabout passes the checker (no false U-turn with 31 m arcs) |
| 5 | **Start on a branch**: square 16 km + branch A–S 1.5 km | loop at S, D = 19 | `sharedM ≈ 1500`, `crossings == 0`, route = S→A, square, A→S. D = 30 → `NO_ROUTE`. Branch 4 km, D = 24 → `NO_ROUTE` detail `TAIL_TOO_LONG` |
| 6 | **End ≠ start (café 5 km away)**: S(0,0), E(5000,0); straight S–E, north arc via (2500,3000), far north arc via (2500,8000), linked at both ends | D = 8 | north arc, `sharedM == 0`; D = 5 → `DISTANCE_TOO_SHORT` |
| 6b | **Café on the way out**: square + branch A–S 2 km, E on the branch 1 km from S | S→E, D = 19 | route S→E→A, square, A→E; `sharedM ≈ 1000`; checker zones accept it |
| 7 | **One-way observed one way**: triangle A, B, C, A→B one-way (FORWARD, observed A→B only) | loop at A, perimeter-length D | every route is A→B→C→A, never the reverse orientation. Same with `AGAINST` observed B→A → only A→C→B→A |
| 8 | **f = 0 vs f = 1**: two 16 km squares north and south of S meeting at S; north support 10, south support 1 | loop at S, D = 16 | f = 1 → first route north (`familiarity ≈ 1`); f = 0 → first south (`≈ 0`); f = 0.5 → both returned |
| 9 | **Excluded track**: square where side B–C exists only in an excluded track; detour B–X–C in a normal one | loop at A, D ≈ square-with-detour | no route uses B–C; routes use B–X–C |
| 10 | **Node merge within 2 m**: scenario 1's square with corner C given by two tracks whose C keys are 1.8 m apart | loop at A, D = 16 | the square is found (it would be `NO_ROUTE` without the merge) |
| 11 | Snap errors | start 2.5 km from any edge; end 2.5 km away | `START_TOO_FAR`; `END_TOO_FAR` |
| 12 | Network too small: square 4 km (16 km) | loop, D = 40 | `NETWORK_TOO_SMALL` |
| 13 | ~~Surface `ROAD`~~ — replaced by scenarios 13a–13f of §12.9 (route / gravel / VTT) | | |
| 14 | Bearing: grid 10×10 of 1 km cells, S centre | θ = N, D = 12 | first route's `bearingDeviationDeg ≤ 35`; θ = null → field null |

### 7.3 Property and determinism tests (`RouteGeneratorPropertyTest`)

> **Insufficient (review M6)**: the grid below has one straight track per edge, no partial
> two-ended edge, no excluded track, no connector, roundabout or dual carriageway, and judges
> validity with the checker on the very graph under test. Kept as a cheap smoke property;
> §12.9 adds `RealisticNetworks`, the raw-input oracle and the per-family floors.

`RandomNetworks.generate(Random r)`: grid of 8–14 × 8–14 nodes, 1 km spacing ± 150 m jitter,
25 % of edges removed, 10 % made one-way (one random observed direction), random supports 1–30,
5 % unpaved, a few random stubs, 2–5 tracks per edge drawn as row/column sweeps. For 300 cases
(fixed outer seed, case index logged in the failure message):

- random S (sometimes off-network within 2 km), E = S or random within 8 km, D ∈ [8, 40] km,
  random θ / f / surface / seed;
- **every returned route passes `RouteGuarantees`** (re-run from the test) and has
  `|distance − D| ≤ 10 %`, `sharedM ≤ 15 % D`, `crossings ≤ 2`;
- `steps` are contiguous on the `NetworkGraph`; `points` start within 2 km of S and end within
  2 km of E; `distanceM` = Σ step lengths (± 1 m incl. split pieces);
- pairwise shared length between returned routes < 50 %;
- **determinism**: the same request twice → `equals` results; `generate` on two graphs built
  from the same tracks in shuffled input order → same routes (builder sorts by trackId).

### 7.4 Performance (`RouteGeneratorPerformanceTest`, `@Tag("perf")`)

`GridNetwork`: 160 × 160 nodes, 500 m spacing (80 × 80 km), ≈ 50 900 edges, one track per row
and per column (supports 1, a few hundred hot rows with support 40), 5 % one-ways.

- graph build measured and printed, asserted `< 5 s` (loose: build is cached in lot 3);
- one warm-up `generate`, then `generate(loop at centre, D = 50 km, θ = NE, f = 0.7)` asserted
  **< 1 s** wall clock, and returns ≥ 1 route;
- skipped with `mvn test -DexcludedGroups=perf`. If the 1 s assertion fails, reduce
  `turningPoints`/`polygonEvaluations` defaults or bound pass 1 of Suurballe with `costLimit`
  before touching anything else; record the numbers in the ledger entry.

---

## 8. Complexity summary

| Step | Cost |
|---|---|
| Builder | O(M) hashing + O(M log M) sort + corridor O(L/step · k); < 3 s at 50 k edges expected |
| Bridges / components | O(N + E) |
| Snap | O(cells in 2 km) |
| One Dijkstra | O((S + T) log S), S = 2E', T ≈ 3–4 S |
| Loop family | 2 one-to-all + `turningPoints` × 2 bounded Dijkstras on 4E' vertices |
| Polygon family | `polygonEvaluations` × (k + 1) A* legs |
| Checker + scoring | O(n) per candidate |
| Memory per call | a few arrays of 4E' doubles/ints (≈ 5 MB at 50 k edges) |

---

## 9. Implementation order

Two sequential parts; each ends with its tests compiling (`mvn -q test-compile`) and handed to
the owner to run.

### PART A — model, builder, graph algorithms, `RouteGuarantees`

1. `package-info.java`, `LatLon`, `NodeRef`, `Oneway`, `TrackEdge`, `TrackInput`,
   `NetworkParameters`.
2. `LocalProjection`, `Geo`, `SpatialGrid`, `States` + `GeoTest`.
3. `TestNetwork` helper (test side) — needed by everything below.
4. `NetworkGraph` + `NetworkGraphBuilder` steps 1–8 (corridor last) + `NetworkGraphBuilderTest`.
5. `BridgeFinder` (wired into the builder) + `BridgeFinderTest`.
6. `Snapper`, `QueryGraph` + `QueryGraphTest`.
7. `MinHeap`, `EdgeDijkstra` (forward, backward, A*) + `EdgeDijkstraTest`.
8. `EdgeDisjointPaths` (Suurballe + post-checks + sequential fallback) + `EdgeDisjointPathsTest`.
9. `GeneratorParameters` (the hard-rule fields are needed by the checker; the record is created
   here with all defaults of §5.1), `Violation`, `GuaranteeReport`, `RouteGuarantees` +
   `RouteGuaranteesTest`.
10. `GridNetwork` helper + the build-time half of the performance test.

### PART B — generator search, scoring, output

1. `Bearing8`, `SurfacePreference`, `GeneratorRequest`, `GeneratorFailure`, `GeneratorResult`,
   `GeneratedRoute`, `RouteStep`, `GeneratorDiagnostics`.
2. `EdgeWeights`, `QueryContext`, feasibility steps 1–6 of §5.2 + scenarios 11, 12, 2b (too short),
   6 (too short).
3. `TailPlanner` + scenario 5 (needs a family: write `LoopFamily` next, then run 5).
4. `LoopFamily` + scenarios 1, 2, 6, 7, 8.
5. `PolygonFamily` + scenarios 3, 4, 13, 14.
6. `CandidateScorer`, `CandidateSelector`, `RouteAssembler`, `RouteGenerator` wiring + scenarios
   6b, 9, 10.
7. `RandomNetworks` + `RouteGeneratorPropertyTest`, then the generate half of
   `RouteGeneratorPerformanceTest`.

---

## 10. Points left for the bench and lot 3 (not blocking)

- β, junction/crossing/tail penalties, ratio band, budgets and scoring weights are first guesses;
  the real-data bench (plan §9, after lot 1) tunes them. All live in `GeneratorParameters`.
- The input model now mirrors the **published** api `1.7` `edges[]` (§12.1), with the api `1.8`
  fields (`tracktype`, `bicycle`, `foot`) modelled as optional and absent today. Lot 1's mapper
  is the only place that changes if fields move; §12.1 states the mapping it must follow.
- Lot 3 maps `GeneratorFailure` to the `GENERATOR_*` error codes, `GeneratedRoute.points` to an
  encoded polyline (`PolylineCodec`), and fills the response's `network` block from
  `NetworkStats` and `Success.networkLengthM`.

---

## 11. PART B as implemented (13 November 2026)

Differences from §5 and §7, with the reason; none changes a plan §2 guarantee.

1. **Defaults changed in `GeneratorParameters`.** `networkTooSmallFactor` 1.5 → 0.9 (a 16 km square
   holds a 16 km loop; the road within D/2 only has to hold D·(1 − tolerance), otherwise scenarios 1
   and 5 would be refused), `turningRatioMax` 0.95 → 1.05 (with a distinct end the two paths need
   not overlap, so the shortest ways to T can already add up to the core length).
2. **Turning points and via points may have degree 2.** The design asked for degree 3 or more, but a
   square whose only junction is the anchor (start on a branch, scenarios 2 and 5) would have no
   turning point. Passing through a degree-2 node is not a U-turn; since §12.4 the turn rule is
   checked there too (it is a real junction of the street graph).
3. **Out-of-band turning points fill the budget.** When fewer than the budget lie in the ratio
   band (a cycle with two very unequal sides), the nodes nearest to the band are tried; the
   budget grows up to 4× (loop) or 3× (polygon) while no candidate fits the distance tolerance.
4. **`EdgeDisjointPaths` rides a state if either direction is allowed** (it used to need the flow
   direction), and the post-check also checks the E side. Without it a one-way edge could never be on
   the S side (scenario 7 `AGAINST` found nothing). In the loop case both paths may end at σS.
5. **Stub edges are not banned** (design §5.2 step 4): a stub is a dead end, so the junction rule
   already keeps it out of the middle of a route, and a start or end on a stub works as for a branch.
6. **Reach (step 6)** sums all reached edges, bridges included, with the midpoint within D/2.
7. **Corridor share** is measured on the distinct edges of the whole route, not on the core.
8. **Tests**: `RouteGeneratorScenarioTest` (scenarios 1 to 14, with their sub-cases),
   `RouteGeneratorPropertyTest` (300 cases, `RandomNetworks`), the generate half of
   `RouteGeneratorPerformanceTest` (`@Tag("perf")`), `EdgeWeightsTest`, one more
   `EdgeDisjointPathsTest` case. `RouteChecks` re-checks every returned route from the test side.

## Revue du lot 2 : écarts par rapport à ce document

- **Copie parallèle après contraction** : le constructeur replie dans l'arête existante toute arête
  issue d'une contraction qui relie les mêmes nœuds avec la même géométrie (supports fusionnés en
  nombre de tracés distincts). Sans cela, le vérificateur (réutilisation par identifiant d'arête)
  laissait aller sur une copie et revenir sur l'autre.
- **Virage mesuré sur le parcours** : la règle des 150 degrés se mesure sur les fenêtres de 30 à
  50 m le long du parcours (sur autant d'états qu'il faut), non plus à l'intérieur d'une seule
  arête : un carrefour dessiné en deux nœuds reliés par un court raccord ne scinde plus un demi-tour.
- **Nœud jumeau** : la règle du virage s'applique aussi à un nœud de degré 2 dont les deux arêtes
  mènent au même voisin (deux chaussées d'une route qui s'arrête là), dans la recherche comme dans
  le vérificateur. **Remplacé par §12.4** : la règle s'applique à tout nœud réel, le cas jumeau
  n'est plus un cas à part (`twinNode` et la branche « jumeau » de `turnChecked` disparaissent).
- Les nœuds créés par les seuls tracés exclus ne fusionnent plus par distance ; en mode route, les
  pièces d'une arête non revêtue coupée en S ou en E restent autorisées ; une boucle ne teste que
  les points de retournement de la composante 2-arête-connexe de l'ancre.

---

## 12. Corrections after review (13 November 2026)

Input: the independent review of lot 2 (findings B1, B2, M1–M6 and minors, reproduced by the
reviewer on throwaway mains), the **published** osm-route-details api `1.7` contract
(`contract/openapi.json`, `docs/design/02-contrat-interface.md` §4.3 bis of that repository) and
plan §5.5, §10.8, §10.9. This section is normative: where an earlier section disagrees, this one
wins. No Java is written by this design; the implementer follows §12.10.

| Finding | Fix | Where | Covered by |
|---|---|---|---|
| **B1** U-turn through a short connector between two degree-2 nodes, and inside a contracted edge | Turn rule at every real node on walked windows; search-side walked check; contraction refused at a measured turn ≥ 120°; corridor cap moved into the checker | §12.4, §12.5, §12.3 step 8 | scenarios 15, 15b; oracle check 4 |
| **B2** phantom edge from padding a partial two-ended edge | Partial observations attached to the complete edge by node pair + offsets; never invented geometry; complete observations first; match against all members; excluded never a reference | §12.1, §12.3 | scenario 16; builder tests; oracle checks 2, 7 |
| **M1** polygon family empty for S ≠ E close | Radius by bisection on `perimeter(r) = Dc/ρ` | §12.6 | scenario 18; `PolygonFamilyTest`; floors |
| **M2** team street cut at the start point; phantom stubs | Coverage union per complete edge, stitched when it covers the edge; a stub only where the team never rode the rest | §12.3 steps 4–6 | scenario 17; builder tests |
| **M3** Suurballe mostly discarded | **Deferred** to the real-data bench (flow kept); now: tail→core and core→tail joins rechecked | §12.6 | scenario 20 |
| **M4** one-way trip refused from a long branch | For S ≠ E the way to the component is an *approach*: no cap, one-way allowed | §12.6 | scenario 19 |
| **M5** times | **Deferred** to the bench; nothing may get slower (§12.8) | §12.8 | perf test, before/after numbers |
| **M6** tests blind to builder bugs | Raw-input oracle, realistic random networks, per-family floors | §12.9 | itself |
| Minors | A* scale measured on the graph; contraction on equal track sets; excluded reference; allocations; `RouteChecks` gaps and length; search vs checker windows | §12.3, §12.4, §12.8 | §12.9 |

### 12.1 Input model, aligned on api 1.7 (plus optional 1.8 fields)

The records stay JSON-free: lot 1 (then lot 3) maps the response; lot 2 only defines the meaning.

```java
public record NodeRef(String key, LatLon position, int streetDegree) {}
// key = edges[].from_node.id / to_node.id ("z14:<x>:<y>"), position = lat/lon,
// streetDegree = degree (distinct bike-open neighbours, 1 = dead end; never 2 in api 1.7)

public enum TrackKind { ROAD, GRAVEL, MTB, MIXED }        // Route.surfaceType, mapped 1:1
public record TrackInput(long trackId, boolean excluded, TrackKind kind, List<TrackEdge> edges) {}

public enum WayKind { MAJOR_ROAD, MINOR_ROAD, TRACK, PATH, CYCLEWAY, FOOTWAY, STEPS, UNKNOWN }
public enum SurfaceClass { PAVED, UNPAVED, UNKNOWN }
public enum SurfaceSource { TAGGED, INFERRED_TRACKTYPE, INFERRED_HIGHWAY, NONE }
public record EdgeSurface(SurfaceClass surfaceClass, @Nullable String detail, SurfaceSource source) {}
public enum OsmTrackType { GRADE1, GRADE2, GRADE3, GRADE4, GRADE5 }      // api 1.8
public enum Access { YES, LIMITED, NO }                                  // api 1.8

public record TrackEdge(
    @Nullable NodeRef from,        // from_node: start of the COMPLETE edge in travel direction,
    @Nullable NodeRef to,          //   even when the track does not reach it; null = unknown end
    boolean partial,               // partial
    @Nullable Double lengthM,      // length_m of the complete edge; null iff from or to is null
    double traversedM,             // traversed_m
    @Nullable Double fromOffsetM,  // from_offset_m / to_offset_m along the complete edge,
    @Nullable Double toOffsetM,    //   counted from `from`; null iff from is null
    Oneway oneway,                 // both | forward | against
    List<LatLon> geometry,         // decoded polyline6: TRAVERSED part only, snapped, travel order
    double gainM, double lossM,    // to_gain_cum_m − from_gain_cum_m, to_loss_cum_m − from_loss_cum_m
    @Nullable EdgeSurface surface, // surface, only when homogeneous along the edge
    @Nullable WayKind wayKind,     // way_kind, only when homogeneous
    @Nullable OsmTrackType trackType, // api 1.8 tracktype, absent today
    @Nullable Access bicycle,      // api 1.8, absent today; absent = untagged or mixed, NOT forbidden
    @Nullable Access foot) {}      // api 1.8, absent today; read for diagnostics only
```

Compact constructor of `TrackEdge`: `geometry = List.copyOf(geometry)`, `traversedM ≥ 0`
(`IllegalArgumentException` otherwise). Nothing else is enforced there: an inconsistent edge is
classified and counted by the builder (§12.3 step 0), never thrown, so one bad track does not
break a team's graph.

Mapping rules lot 1 must follow (written here because the builder relies on them):

- `geometry` is the decoded polyline (precision 6) **as is**: never extended to a node, never
  replaced by the chord. A U-turn arrives as two observations of the same edge in opposite
  directions, the second with `from`/`to` swapped (travel direction).
- `surface.detail` is passed lowercase as received (open list; the builder knows 13 values and
  treats any other as "no detail"). Unknown enum strings map to `UNKNOWN` / `NONE` / null
  (forward compatibility), never to an exception.
- `wayKind` / `surface` absent (edge not homogeneous) stay null. Rebuilding them from
  `segments[]` is a lot 1 option to evaluate on the bench (share of null `way_kind`), not
  required by lot 2.
- `structure` is not mapped (unused). `segments[].unmatched_reason` produces no edge: nothing to
  map. `kind` = `Route.surfaceType`; `excluded` = `Route.excludedFromGenerator`.
- `TrackEdge`'s former `unpaved` boolean and the builder's `pad` logic disappear with this model.

Deleted: `SurfacePreference` (§12.7).

### 12.2 New `NetworkParameters` fields and defaults

| Field | Default | Meaning |
|---|---|---|
| `dedupLengthRatio` | **0.03** (was 0.15) | two complete observations with the same node pair are the same edge if their `lengthM` differ by ≤ max(`dedupLengthAbsM`, ratio · max) … |
| `dedupLengthAbsM` | 5 | … (network lengths of one street agree to the metre on one data version) |
| `dedupMaxMembers` | 8 | an observation is compared with at most the first 8 complete members of a slot |
| `coverageGapM` | 5 | coverage pieces closer than this are joined; an observation end within this of a node touches it (the producer's own 5 m rule) |
| `supportMinCoverM`, `supportMinCoverShare` | 100, 0.5 | an observation counts as support of a graph edge when it covers ≥ min(100 m, 50 % of it) |
| `contractionMaxTurnDeg` | 120 | contraction refused at a node whose measured turn reaches this |

`RouteGenerator.generate` throws `IllegalArgumentException` when
`GeneratorParameters.maxTurnDeg < NetworkParameters.contractionMaxTurnDeg` of the graph it is
given: a contracted turn must always be legal.

### 12.3 `NetworkGraphBuilder` — observations on complete edges (fixes B2, M2)

Replaces §3.3 steps 1–5 and 7; steps 6 and 8 of §3.3 (drop isolated nodes, final arrays) stay.
Tracks are still processed sorted by `trackId`, edges in their order. Every step processes **live
observations before excluded ones** (two passes over the sorted tracks), so an excluded track
never founds a slot or a node merge a live one could have founded.

**Step 0 — classify** each `TrackEdge`:

| Class | Condition | Interval (metres along the complete edge) |
|---|---|---|
| `COMPLETE` | `!partial`, both ends, `lengthM` set | `[0, L]` from `from` |
| `PARTIAL_BOTH` | `partial`, both ends | `[fromOffsetM, toOffsetM]` from `from` |
| `PARTIAL_FROM` | `from` set, `to` null | `[fromOffsetM, toOffsetM]` from `from`; L unknown |
| `PARTIAL_TO` | `from` null, `to` set, geometry's last point within `coverageGapM` of `to` | `[0, traversedM]` **from `to`** (orientation reversed) |
| `FLOATING` | `from` null, `to` set, geometry does not reach `to` | none: attached by projection only (step 4) |
| `DROPPED` | both ends null, geometry < 2 points, `traversedM < minEdgeLengthM`, offsets outside `[−coverageGapM, L + coverageGapM]` or `toOffsetM < fromOffsetM − 1` | — |

Offsets are clamped into `[0, L]`. A `!partial` edge with a null end is read as partial. Counts go
to `NetworkStats` (`droppedInputEdges`, `floatingObservations`).

**Step 1 — nodes by key** and **step 2 — merge by distance**: as §3.3 steps 1–2, with the max
of `streetDegree` kept per node. There are no dangling nodes yet (they are coverage ends, created
at step 5), so the "dangling nodes merge only with dangling nodes" rule disappears.

**Step 3 — slots from complete observations.** For each `COMPLETE` observation: `(a, b)` = the
merged ends. `a == b` ⇒ dropped (connector collapsed by the merge, or a self-loop:
`selfLoopsDropped`). Slot key `(min, max)`; the observation is oriented to `u = min → v = max`
(geometry reversed, gain/loss swapped, observed direction recorded). It joins the **first slot of
the key for which any of its first `dedupMaxMembers` complete members matches**:
`|L − L_m| ≤ max(dedupLengthAbsM, dedupLengthRatio · max(L, L_m))` and mean distance of
`dedupSamples` arc-fraction resampled points `< dedupMeanDistM` (both geometries are complete, so
arc-fraction resampling is now sound). Otherwise it founds a slot `(u, v, L, reference geometry =
its own)`. Two distinct streets between the same junctions remain two slots.

**Step 4 — attach partial observations, never invent geometry.**

- `PARTIAL_BOTH`: same key; interval oriented (`a == u` ⇒ `[o1, o2]`, else `[L − o2, L − o1]`).
  Candidate slots: length within the tolerance of step 3. Fit = mean distance from the
  observation's resampled points to the slot's known geometry **on the overlapping offsets**
  (reference geometry for a complete slot; the attached live pieces for a partial-only slot);
  a slot with no geometry overlapping the interval gets the neutral fit `dedupMeanDistM / 2`
  (same node pair, same network length: the same street). Best fit `< dedupMeanDistM` wins, tie
  ⇒ lower slot index. None ⇒ a new **partial-only slot** `(u, v, L)` without reference geometry.
- `PARTIAL_FROM` / `PARTIAL_TO` (one known end k, interval measured from k): candidate slots are
  every slot touching k (complete, partial-only, or **open** slots `(k, ∅)`), offsets mapped to
  the slot's orientation. Accepted only with a real geometric overlap and fit
  `< dedupMeanDistM`. None ⇒ joins the open slot of k whose geometry matches over the common
  prefix (`sameStub`), or founds one.
- `FLOATING`: projected onto the geometry of the slots touching its known end; accepted when both
  end projections and the mean fit are `< dedupMeanDistM`, the interval being the projected
  offsets. Otherwise dropped (`floatingObservations` counts it).

**Step 5 — coverage, stitching and pieces, live observations only.** A slot with no live
observation is dropped (plan §10.8: excluded tracks never open an edge).

- A slot holding a live `COMPLETE` observation is one graph edge, geometry = the first live
  complete observation's, length = its `lengthM`.
- Otherwise, U = union of the live intervals sorted by `(start, −end, trackId)`, pieces merged
  when the gap is ≤ `coverageGapM`. For a two-ended slot of length L:
  - U is one interval with `start ≤ coverageGapM` and `end ≥ L − coverageGapM` ⇒ **complete
    edge, stitched** (`stitchedEdges`), length L;
  - otherwise each maximal interval `[s, t]` touching u gives a stub `u → dangling(t)`, touching
    v a stub `v → dangling(s)`; an interval touching neither is dropped (`orphanPieces`).
  For an open slot `(k, ∅)`: the interval touching k is a stub, the others are orphans.
- **Stitching**: `cursor = 0`; for each interval `[s, t]` with geometry G (oriented): skip it if
  `t ≤ cursor + 0.5`; else append the slice of G from offset `max(s, cursor)` to t (offset →
  arc length on G by the linear map `(x − s) / (t − s) · length(G)`), dropping its first point
  when within 0.5 m of the last appended one; `cursor = t`. Then, if the first point is 0.5 m to
  `coverageGapM` from u's position, prepend u's position; same for v at the end. **Invariant
  (anti-B2, asserted in tests): no segment of a built geometry longer than `coverageGapM` that is
  not a slice of a live input geometry.**
- Gain/loss: the complete observation's; for stitched edges and stubs, the sum over the slices of
  `gain · slicedLength / traversedM` of the sliced observation (same for loss).
- Dangling node position = the geometry point at the coverage end.

**Step 6 — aggregate each graph edge** (complete, stitched or stub). With
`overlap(o) = |o.interval ∩ edge interval|` over the live observations of its slot:

- `tracks` = sorted `long[]` of live track ids with `overlap ≥ min(supportMinCoverM,
  supportMinCoverShare · len)`; if empty, the single track of largest overlap (an edge exists
  only because something covers it). `support = tracks.length`;
  `supportByKind[k]` = how many of them are of kind k (the builder keeps a
  `LinkedHashMap<Long, TrackKind>`).
- Observed directions from live observations with `overlap ≥ 1 m`; the one-way rule of §3.3
  step 5 is unchanged (any live non-`BOTH` ⇒ one-way, allowed only in observed directions).
- Categorical attributes: majority by overlap metres among live observations with a non-null
  value; tie ⇒ the most restrictive: `wayKind` STEPS > FOOTWAY > PATH > TRACK > UNKNOWN >
  CYCLEWAY > MINOR_ROAD > MAJOR_ROAD; `surfaceClass` UNPAVED > UNKNOWN > PAVED (`detail` and
  `source` taken from the observations of the winning class, majority then lexicographic);
  `trackType` the highest grade; `bicycle` NO > LIMITED > YES. All null ⇒ `UNKNOWN` / `UNKNOWN`
  + `NONE` / absent. Stored as `byte` codes; `surfaceDetail` code 0 = none, then the 13 known
  values of the contract (unknown strings ⇒ 0, counted in `unknownSurfaceDetails`).

**Step 7 — drop isolated nodes** (former step 6).

**Step 8 — contraction** (replaces §3.3 step 7). Node n (alive, not dangling, team degree 2,
edges `ea = (a, n) ≠ eb = (n, b)`, `a ≠ b`, `a ≠ n ≠ b`) is contracted only if:

1. `ea.tracks` **equals** `eb.tracks` (fixes the minor "`merged.tracks = ea.tracks` ignores
   eb": with equal sets the merged set is exact, and equal counts over different tracks no
   longer merge two differently ridden halves);
2. equal categorical attributes (all seven codes);
3. the merged allow flags of §3.3 step 7, at least one direction true;
4. **the measured turn at n is below `contractionMaxTurnDeg`**: `Geo.turnAngleDeg(end heading of
   ea oriented a→n, start heading of eb oriented n→b)` on the 30–50 m windows of their *current*
   geometries (possibly already merged). Either contraction order catches the dual-carriageway
   end of B1: contracting Y1 first leaves `X → Y2` whose last 30–50 m are the northbound
   carriageway, so the 180° at Y2 is measured; contracting Y2 first is symmetric.

The twin fold (`findTwin` / `absorb`) stays; `absorb` unions the track sets and recomputes
`support` and `supportByKind` from the union.

**Step 9 — final arrays**: §3.3 step 8 plus `supportByKind`, the seven attribute arrays, the
eager per-type familiarity arrays of §12.7 and `aStarScale` (§12.8).

`NetworkStats` gains `droppedInputEdges`, `floatingObservations`, `orphanPieces`,
`stitchedEdges`, `selfLoopsDropped`, `unknownSurfaceDetails`, and
`Map<TrackKind, Integer> liveTracksByKind` (an `EnumMap` copied into an unmodifiable map).

### 12.4 The turn rule at every real node (fixes B1)

**Definition** (normative, in `RouteGuarantees`): at every interior route node `v_i` with
`turnApplies(v_i)`, the turn between the route's heading on `[x_i − 50, x_i − 30]` and on
`[x_i + 30, x_i + 50]` (x_i = route distance at `v_i`, windows walked over as many states as it
takes, clamped as in `pathHeading`) must be `< maxTurnDeg`.

```
turnApplies(node) = !g.isVirtual(node) && !g.dangling(node) && g.streetDegree(node) != 2
```

`QueryGraph` gains `isVirtual(node)` and `streetDegree(node)` (virtual nodes report 2). The
predicate replaces `degree ≥ 3 || twinNode` in the checker and `turnChecked` in the search;
`twinNode` and the twin branch of `turnChecked` are deleted. Rationale: every node of api 1.7 is
a street junction or a dead end, so a team-degree 2 node is a junction where the team only uses
two arms; the "mountain hairpin at a degree-2 node" exemption protected nothing real. A hairpin
inside one edge geometry is never checked (the street does it, not the route), and contraction
cannot hide a turn ≥ 120° (§12.3 step 8).

**Search side — `SearchTurns`** (new, package-private; deliberately *not* sharing code with the
checker's private window helpers):

```java
final class SearchTurns {
  static boolean applies(QueryGraph g, int node);                 // the predicate above
  /** Forward transition s → s2, pred = the label tree of the running search. */
  static boolean ok(QueryGraph g, int[] pred, int s, int s2, double maxTurnDeg);
  /** Backward transition s0 → s, succ = the label tree of a backward search. */
  static boolean okBackward(QueryGraph g, int[] succ, int s0, int s, double maxTurnDeg);
  /** Every turn of states[from..to) on walked windows (joins of legs, tails, flow output). */
  static boolean pathOk(QueryGraph g, int[] states, int from, int to, double maxTurnDeg);
}
```

`ok(s → s2)` at `h = head(s)`, `far = headingFarM`:

1. `s2 ≠ rev(s)` (structural, as today);
2. if `applies(h)`: `inH = length(s) ≥ far ? endHeading(s) : walkedEnd(s, pred)`,
   `outH = startHeading(s2)`; refuse if `turnAngle(inH, outH) ≥ maxTurnDeg`;
3. **look-back** for the connector case: if `length(s) < far`, `pred[s] ≥ 0` and
   `applies(t = tail(s))`: `inH' = walkedEnd(pred[s], pred)`, `outH'` = heading on `[30, 50]` of
   the concatenation `s, s2` from t; refuse if `≥ maxTurnDeg`. On the B1 graph this refuses
   `Y1→Y2 → Y2→X` because the turn at Y1 (northbound in, connector + southbound out) is ≈ 180°.

`walkedEnd(s, pred)` walks the geometry of `s, pred[s], pred[pred[s]], …` backwards until `far`
metres are collected (or a source is reached) without allocating (an offset accumulator over the
segments). Cost: only states shorter than 50 m (roundabouts, connectors), a few per cent.

Label-setting caveat, documented in the class: the history is the label's best path, so a
transition refused under that history might have been legal under another one; in towns with
chains of short edges the search may miss a route, never return an illegal one (the checker has
the last word). Diagnostics count `walkedTurnRefusals`.

Users: `EdgeDijkstra.relaxForward` / `relaxBackward` (replace `canTurn`), `QueryContext.continuations`
(now `continuations(int[] routeSoFar, BitSet ban)`: the first states of the next polygon leg are
filtered with the route so far as history), `TailPlanner`. `EdgeDisjointPaths` arcs keep a
per-edge check with `SearchTurns.applies` (a flow has no history); its output is validated with
`pathOk` (§12.6).

### 12.5 Checker: corridor cap inside `RouteGuarantees`

`Violation.CORRIDOR_DOUBLED`, measured from the route's own geometry (independent of the builder's
corridor relation, which stays for the polygon ban and the score):

```
samples every 10 m along the core (start zone and end zone of check 4 excluded),
       skipping the first and last corridorEndIgnoreM of the core
grid of corridorDistM cells over the samples
doubled(i) = ∃ j: |x_i − x_j| ≥ 2 · corridorMinOverlapM (400 m)
                 and distance(sample_i, sample_j) ≤ corridorDistM
share = 10 · count(doubled) / (2 · coreLength)        // a doubled stretch is counted on both passes
share > maxCorridorShare (0.2) ⇒ CORRIDOR_DOUBLED
```

A perpendicular crossing marks about 2 × 50 m, far below the cap. `RouteGenerator` drops its own
corridor test (`corridorRejected` disappears from the diagnostics; the violation count replaces
it). The score keeps `wCorridor · corridorShare` (§5.7).

### 12.6 Search fixes

**M1 — polygon radius for S ≠ E close.** `PolygonFamily.Shape.radiusFor(double target)` for the
near shape:

```
if perimeter(0) ≥ target: return 50                  // anchors alone already that far apart
lo = 0; hi = max(100, target / (2π))
while perimeter(hi) < target and doublings < 40: hi *= 2
repeat 50 times or until hi − lo < 1 m:
    mid = (lo + hi) / 2; if perimeter(mid) < target: lo = mid else hi = mid
return hi
```

`perimeter(r)` is a sum of norms of affine functions of r, hence convex, with `perimeter(0) =`
chord `< target`: the set `{perimeter < target}` is an interval containing 0 and the root is
unique. `r0 = radiusFor(Dc / ρ)` replaces `dc / (rho · max(1, perimeter(1)))`. The ellipse case
(E far) is unchanged; the secant correction and the ρ update are unchanged.

**M4 — approaches for a one-way trip.** In `TailPlanner`, when `S ≠ E` and the node lies in a
trivial component (`componentLength == 0`):

```
approach from S: forward EdgeDijkstra from S, metres, allowed states and ctx.banned only
                 (not bothWays), target = first node of a non-trivial component,
                 costLimit = 0.5 · D; one approach per distinct hub reached first (as byAnchor)
approach to E:   the same, backward to E
pair:            Dc = D − len(approachS) − len(approachE)   (shared edges are ridden twice)
                 Dc < 0.5 · D ⇒ pair dropped; core ban = banned ∪ approach edges
none found:      Failure(NO_ROUTE, "NO_APPROACH")
```

No 15 % cap and no two-way requirement: an approach is ridden once. When the two approaches share
edges (café on the way out) that overlap is the reuse, and the checker's zone rule bounds it as
before. Loops keep the forced, two-way, ≤ 15 % tail (`TAIL_TOO_LONG`); the voluntary anchors stay
real tails in both cases.

**M3 (part done now) — joins with the tails.** `LoopFamily` runs `SearchTurns.pathOk` over
`tailS + core + tailE` (both joins and every turn of the core) before emitting a candidate, after
`EdgeDisjointPaths.solve` and after its sequential fallback alike; a rejection increments
`disjointJoinRejected`. Deleting the flow is left to the real-data bench (review M3): the code
stays.

### 12.7 Route, gravel, VTT (plan §5.5, §10.9)

```java
public enum RideType { ROAD, GRAVEL, MTB }
public record GeneratorRequest(LatLon start, @Nullable LatLon end, @Nullable Bearing8 bearing,
    double distanceM, double familiarity, RideType type, long seed) {}
```

**Kinds per type** ("prise par" = `supportByKind > 0` of one of the listed kinds; secondary
kinds weigh `secondaryFamiliarityWeight` = 0.25 in the familiarity):

| `RideType` | "Prise par" (admission) | Familiarity, primary | Familiarity, secondary |
|---|---|---|---|
| `ROAD` | `ROAD` | `ROAD` + `MIXED` | — |
| `GRAVEL` | `GRAVEL` or `MIXED` | `GRAVEL` + `MIXED` | `ROAD` |
| `MTB` | `MTB` | `MTB` | `GRAVEL` + `MIXED` (choice: plan says "MTB, puis GRAVEL"; mixed rides sit with gravel) |

**Edge predicates** (base attributes; a virtual piece reads its parent's):

```
kindEff        = (wayKind ∈ {PATH, FOOTWAY} && bicycle == YES) ? CYCLEWAY : wayKind     // api 1.8
rollingUnpaved = surfaceClass != PAVED && (detail ∈ {compacted, fine_gravel, gravel}
                                           || trackType ∈ {GRADE1, GRADE2, GRADE3})
roughUnpaved   = detail ∈ {dirt, sand, grass, rock, wood} || trackType ∈ {GRADE4, GRADE5}
bikeForbidden  = bicycle == NO                                                           // api 1.8
```

**Admission** (`EdgeWeights.banned(qg, type)`, hard; the virtual pieces carrying S or E stay
allowed as today):

```
ROAD:   kindEff ∈ {PATH, FOOTWAY, STEPS} or surfaceClass == UNPAVED or bikeForbidden → banned
        kindEff ∈ {MAJOR_ROAD, MINOR_ROAD, CYCLEWAY} and surfaceClass == PAVED       → admitted
        otherwise (unknown surface, paved track, unknown kind)                       → admitted iff by(ROAD)
GRAVEL: kindEff == STEPS                                                              → banned
        kindEff ∈ {PATH, FOOTWAY} or roughUnpaved or bikeForbidden                   → admitted iff by(GRAVEL|MIXED)
        otherwise (road network, track, cycleway, rolling unpaved, unknown)           → admitted
MTB:    kindEff == STEPS or bikeForbidden                                             → admitted iff by(MTB)
        otherwise                                                                     → admitted
```

**Preferences** — `pS` of §5.3, first guesses in `GeneratorParameters` (bench):

| Type | Multiplier |
|---|---|
| `ROAD` | 1 for paved major/minor/cycleway; `roadUncertainFactor` 1.3 for an edge admitted only through `by(ROAD)` |
| `GRAVEL` | `gravelUnpavedFactor` 0.75 for rolling unpaved or a non-paved `TRACK`; `gravelMajorRoadFactor` 1.25 for a paved major road; 1 otherwise |
| `MTB` | `mtbOffroadFactor` 0.6 for `UNPAVED` or `kindEff ∈ {PATH, TRACK}`; `mtbMajorRoadFactor` 1.4 for a major road; 1 otherwise |

A multiplier below 1 is fine for A*: `minWeightPerMetre` is measured on the weights.
`unpavedPenaltyAny` is removed.

**Familiarity per type.** `s_e = primary(e) + 0.25 · secondary(e)` (track counts by kind);
`z_e = log1p(s_e) / log1p(max_e s_e)`, 0 when the max is 0. The builder computes eagerly
`zByType[ROAD|GRAVEL|MTB]` and `zAll` (`log1p(support) / log1p(maxSupport)`), immutable (4 × E
floats). `QueryGraph.z(e, ZSource)` delegates to the parent for a virtual piece.

**Fallback** (decided per request in `QueryContext`): `zAll` replaces the type's z when
`liveTracksByKind` of the primary kinds `< familiarityMinTracks` (10), or when the reachable,
admitted length within D/2 of S/E carrying primary support (same sum as `roadNear`) is
`< familiarityMinNearShare · D` (0.5). Admission never changes. Signalled by
`GeneratorResult.Success.familiarityFallback` (new boolean component) and
`GeneratorDiagnostics.familiarityFallback`; lot 3 maps it into the response. `GeneratedRoute
.familiarity` and the scorer's `famDev` use the z actually used. `unpavedShare` = length of
`surfaceClass == UNPAVED` / distance (unknown counts as not unpaved).

New `GeneratorParameters` fields: `secondaryFamiliarityWeight` 0.25, `familiarityMinTracks` 10,
`familiarityMinNearShare` 0.5, `roadUncertainFactor` 1.3, `gravelUnpavedFactor` 0.75,
`gravelMajorRoadFactor` 1.25, `mtbOffroadFactor` 0.6, `mtbMajorRoadFactor` 1.4. Removed:
`unpavedPenaltyAny`.

### 12.8 Minors and performance

- **A* scale** (was a fixed 0.97, wrong beyond ±1.5° of latitude): `NetworkGraph.aStarScale() =
  0.999 · min(1, min_e edgeLength_e / projectedPolylineLength_e)` (1 for an empty graph). Any
  path costs ≥ `minWeightPerMetre · Σ L_e ≥ minWeightPerMetre · aStarScale · Σ projLen_e ≥
  minWeightPerMetre · aStarScale · euclid`; a virtual piece keeps its parent's ratio (lengths and
  projected lengths are cut in the same proportion). `aStarFactor = aStarScale ·
  minWeightPerMetre`; the literal `0.97` in `RouteGenerator` and `QueryContext` goes.
- **Allocations**: `EdgeDisjointPaths` allocates its arrays (4 × states) once per `QueryContext`,
  lazily on the first `solve`, and resets them through touched lists between turning points;
  `PolygonFamily` reuses one `double[] penalty` per context, reset through a touched list after
  each evaluation (was `new double[nodeCount]` per evaluation).
- **`RouteChecks`**: adds (a) the last point of step i and the first of step i + 1 are < 1 m
  apart, (b) the haversine length of `points` is within `0.01 · distanceM + 5 m` of `distanceM`.
- **Not done now**: re-passing a roundabout counts as `REUSE_OUTSIDE_TAIL` (no figure-eight
  through a roundabout); counting a reused arc < 50 m as a crossing is measured on the bench
  first. Deleting the Suurballe flow (M3) and the time levers (M5) likewise.
- **Nothing slower** (M5): the perf test prints build time, node/edge counts and the generate
  times; the implementer records the numbers before and after these corrections in the ledger
  entry. Expected effects: contraction on equal track sets keeps more nodes on real data (bench),
  `SearchTurns` costs only on short states, the eager z arrays add 16 bytes per edge.

### 12.9 Tests (fixes M6)

**Test helpers.**

- `TestNetwork` rewritten for the 1.7 shape: named edges with bend points
  (`net.edge("A", "B", bends…)`) hold the truth geometry; `net.track(id, kind).via(...)` emits
  complete observations; `.startAt("A", "B", offsetM)`, `.endAt(…)`, `.uTurnAt(offsetM)` and
  `.unknownEnd()` emit partial observations exactly as osm-route-details would (complete-edge
  ends in travel direction, offsets from `from`, `lengthM` null when an end is null, geometry =
  **slice** of the truth geometry); `.excluded()`, `.oneway(...)`, `.wayKind(...)`,
  `.surface(class, detail, source)`, `.trackType(...)`, `.bicycle(...)`; `alias` for merge tests.
- `RandomNetworks` and `GridNetwork` adapted to the new records (complete observations, kinds).
- **`RawInputOracle`** (new): `static List<String> violations(List<TrackInput> tracks,
  GeneratorRequest r, GeneratedRoute route, GeneratorParameters p)`. Uses **only** the raw
  inputs and `route.points()`: no `NetworkGraph`, builder, `QueryGraph`, `Geo` or
  `LocalProjection` (its own haversine and its own local metres). Checks:
  1. live index of every live input segment (25 m grid), excluded segments in a second index;
  2. **on input**: every 5 m sample of the route lies within 4 m of a live input segment
     (message gives the nearest live and nearest excluded distances) — catches phantom chords
     (B2) and excluded-only roads;
  3. **direction**: at each sample with route bearing β (±10 m), among the live segments within
     4 m whose axis is within 30° of β's, if any belongs to a non-`BOTH` observation then one of
     them has a travel bearing within 30° of β;
  4. **turns at junctions**: at every live `NodeRef` position (by key, `streetDegree ≠ 2`) the
     route passes within 3 m of at distance `x ∈ (60, L − 60)`, the turn between `[x−50, x−30]`
     and `[x+30, x+50]` is `< maxTurnDeg` — catches B1 whatever the graph says;
  5. **folds**: no sample x where the points at `x ± 40` are within 8 m of each other with a turn
     `≥ maxTurnDeg` (precondition, asserted by the generators: no input hairpin narrower than
     8 m at 40 m from its apex);
  6. **reuse**: a sample is reused when a sample ≥ 100 m away along the route lies within 4 m on
     a compatible axis (30°; crossings excluded); every reused sample lies within the first or
     the last `0.15·D + 30 m` of the route, and half the reused length is `≤ 0.15·D + 30 m`;
  7. **distance**: polyline length within `(distanceTolerance + 0.01) · D` of D, and within
     `0.01 · distanceM + 10 m` of `route.distanceM` (B2's 932 m for 412 m of geometry);
  8. **ends**: the first point within 5 m of the nearest live input point to `r.start`, the last
     likewise for the end (the start for a loop);
  9. **type**: at each sample, among the live observations within 4 m on a compatible axis, at
     least one admits `r.type` under the §12.7 table evaluated on its **raw** fields, with
     `by(X)` = some nearby live observation's track is of kind X.
- **`RealisticNetworks`** (new): a truth street graph, then tracks emitted as api 1.7 would.
  - jittered grid 6–10 × 6–10 at 600–1200 m, 20 % of edges removed (kept connected), edges as
    polylines with 2–6 bend points (lateral jitter ≤ 60 m, hairpin-free per oracle check 5);
  - **roundabouts**: 15 % of degree-4 nodes become a ring of one-way counter-clockwise arcs,
    radius 12–25 m, one degree-3 node per arm;
  - **dual carriageways**: 1–2 per network, a chain of 2–4 edges replaced by two one-way
    carriageways 8–40 m apart (some beyond the 25 m corridor) with a node per junction, and at
    each end a 10–25 m **connector** whose cross street exists in the truth but is ridden by no
    track in half the cases (the B1 trap: team degree 2, street degree 3);
  - one side cycleway 8–15 m beside a road (corridor), 2–4 dead-end spurs, one pendant branch
    of 1–3 km ending in a small loop (bridge);
  - **team location** at 20–80 % along a random edge;
  - attributes: `wayKind` major 15 %, minor 55 %, track 15 %, path 7 %, cycleway 5 %, footway
    2 %, steps 1 %; surface consistent with the kind (tracks: 60 % unpaved with a detail,
    40 % inferred class without detail); 20 % of edges non-homogeneous (`wayKind` null);
  - **unknown ends**: 5 % of the boundary edges longer than 400 m emitted with the unreached far
    end null;
  - 40–120 tracks, kinds ROAD 70 %, GRAVEL 20 %, MIXED 7 %, MTB 3 %; 5 % excluded, each also
    riding one "private" edge no live track rides; random walks of 5–40 km starting at the team
    location (70 %) or mid-edge elsewhere, obeying one-ways except 3 % contraflow (`AGAINST`),
    ROAD tracks avoiding path/footway/steps/unpaved with probability 0.9, a U-turn at every dead
    end and 3 % mid-edge (closing the partial edge and reopening it reversed), ending at the team
    location (60 %) or mid-edge; no walk starts or stops within 5 m of a node (the producer's
    5 m rule), no back-and-forth under 5 m; geometry = truth slice + ≤ 0.4 m noise; gain and loss
    from a smooth elevation field;
  - **data-version drift**: 10 % of tracks see every node 1–2 m away under another key.
- **`RealisticRouteGeneratorPropertyTest`** (new, 200 cases, fixed outer seed, case index in every
  message). Request classes: loop; **café** (E 2–6 km from S, D ∈ [15, 50] km); **one-way** (E
  at 0.6–0.85 D, D ∈ [15, 40] km); type, θ, f, seed random; start at the team location 80 %.
  Every returned route passes `RouteChecks.assertValid` **and** `RawInputOracle.violations` is
  empty. **Floors**, over the requests whose truth network holds ≥ 1.2 D of admitted road within
  D/2 (computed by the test from the truth, not from the builder), printed as a table then
  asserted:

  | Class | Success rate | Cases with `loopCandidates ≥ 1` | Cases with `polygonCandidates ≥ 1` |
  |---|---|---|---|
  | loop | ≥ 0.70 | ≥ 0.60 | ≥ 0.60 |
  | café | ≥ 0.60 | ≥ 0.50 | ≥ 0.60 (M1) |
  | one-way | ≥ 0.60 | — | ≥ 0.60 |

  plus a median of ≥ 3 candidates per family for loops. These are first floors: after the
  owner's first run, they are raised to 80 % of the measured values and the numbers go into the
  ledger entry.
- The `RandomNetworks` property test stays as a cheap smoke test.

**New scenarios** (`RouteGeneratorScenarioTest`; every returned route also through the oracle):

| # | Graph | Request | Expected |
|---|---|---|---|
| 15 | **B1**: W(−3000,0)–X(0,0)–E(3000,0) closed by the south; spur X→Y1(0,2000) one-way, Y1–Y2(15,2000) connector, Y2→X one-way; supports 2/1/3 from different track sets | loop at W, D = 24 km, seeds 1–8 | no route touches the spur. Same with equal track sets (contraction path), and with carriageways 40 m apart. A hand-written route through the spur ⇒ `SHARP_TURN` |
| 15b | **Contracted U-turn**: carriageways from X north to Y1, connector, south to Z ≠ X, equal track sets | builder, then loop | Y1 or Y2 is not contracted (node count asserted), no route uses the pair |
| 16 | **B2**: edge U–V with a hairpin (L = 932 m, chord 412 m); track 1 complete U→V; track 2 starts at 300 m → V; track 3 U → 600 m then U-turn | builder | one edge U–V, support 3, geometry = track 1's (< 1 m), length 932. Without track 1: stitched complete edge, length 932, every point within 1 m of the truth. Track 2 alone: stub V → dangling at 300 m, length 632, no piece on the U side |
| 17 | **M2**: team street A–B 1.2 km, team location T at 40 %, tracks start or end at T in both directions, squares beyond A and B | loop at T, D = 14 km | best route leaves by one end and returns by the other, `sharedM == 0`; S snaps on the A–B edge; no dangling node in the graph |
| 18 | **M1**: grid 10 × 10 at 1 km | S centre, E 3 km east, D = 20 | `polygonCandidates > 0`, `validPolygon > 0`. `PolygonFamilyTest`: `perimeter(radiusFor(T))` within 1 m of T for A = B, `|AB|` = 3 km and `|AB|` = 0.45 D |
| 19 | **M4**: branch 4 km west of the grid, S at its end, E in the grid 12 km away | S → E, D = 20 | `Success`, the branch ridden once, `sharedM == 0`; same with the branch's first edge one-way towards the grid. Loop from S, D = 24 ⇒ still `NO_ROUTE` / `TAIL_TOO_LONG` |
| 20 | **M3 join**: loop with a voluntary tail whose last state meets one flow assignment at 160° | loop | no returned route has that join; `disjointJoinRejected > 0` |
| 21 | **Excluded private road**: the shortest loop needs an edge only an excluded track rides | loop | no route uses it; the oracle's on-input check agrees |
| 13a–f | **Type** (replace scenario 13): (a) ROAD with a parallel unpaved track; (b) ROAD with a paved cycleway; (c) ROAD with an unknown-surface minor road ridden by GRAVEL tracks only, then by one ROAD track; (d) GRAVEL with a `path` ridden by ROAD tracks only, then by a MIXED track; (e) `steps` for GRAVEL, and for MTB without then with an MTB track; (f) MTB on a network with 3 MTB tracks, GRAVEL with 30 gravel tracks | per case | (a) never used; (b) used; (c) banned, then admitted; (d) banned, then admitted; (e) never, never, admitted; (f) `familiarityFallback` true with the same admitted edges, false for GRAVEL. f = 1 picks the gravel-popular loop for GRAVEL and the road-popular one for ROAD |

**Unit tests added.** `NetworkGraphBuilderTest`: classification counts; complete observations
first; an excluded complete observation with an odd geometry, earlier by track id, does not
split two live ones; `PARTIAL_BOTH` attached in both orientations; two partials meeting ⇒
stitched; gap > 5 m ⇒ two stubs; `FLOATING` attached by projection, then dropped without a
slot; the anti-B2 invariant over every built geometry; contraction refused with equal counts on
different track sets, and at a measured 180°; `supportByKind`; attribute majority and
tie-breaks; `aStarScale ≤ 1`. `EdgeDijkstraTest`: the look-back case (connector between two
degree-2 nodes); A* equals Dijkstra on 200 queries over a graph spanning 44°–50° N;
`SearchTurns` never accepts a path `RouteGuarantees` calls `SHARP_TURN` when every edge is
≥ 50 m (on 500 random chains). `RouteGuaranteesTest`: `CORRIDOR_DOUBLED` on a dual carriageway
out-and-back, not on a figure-eight; `SHARP_TURN` at a team-degree 2 real node, none at a
virtual node or at `streetDegree == 2`. `EdgeWeightsTest`: the admission table row by row and
the per-type z.

### 12.10 Files touched and implementation order

Main (`backend/src/main/java/fr/pedalons/service/route/generator/`):

- new: `TrackKind`, `RideType`, `WayKind`, `SurfaceClass`, `SurfaceSource`, `EdgeSurface`,
  `OsmTrackType`, `Access`, `SearchTurns`;
- changed: `TrackEdge`, `TrackInput`, `NetworkParameters`, `NetworkGraphBuilder` (steps 0–9),
  `NetworkGraph` (attributes, `supportByKind`, `zByType`/`zAll`, `aStarScale`, `streetDegree`),
  `NetworkStats`, `QueryGraph` (`isVirtual`, `streetDegree`, attribute and z delegation),
  `RouteGuarantees`, `Violation`, `EdgeDijkstra`, `EdgeDisjointPaths`, `PolygonFamily`,
  `TailPlanner`, `LoopFamily`, `QueryContext`, `EdgeWeights`, `GeneratorRequest`,
  `GeneratorParameters`, `GeneratorResult`, `GeneratorDiagnostics` (`walkedTurnRefusals`,
  `disjointJoinRejected`, `familiarityFallback`; `corridorRejected` removed), `CandidateScorer`,
  `RouteGenerator`, `RouteAssembler`;
- deleted: `SurfacePreference`.

Tests: `TestNetwork` (rewrite), `RandomNetworks`, `GridNetwork`, `RouteChecks`, new
`RawInputOracle`, `RealisticNetworks`, `RealisticRouteGeneratorPropertyTest`, `PolygonFamilyTest`,
additions to the builder, Dijkstra, guarantees, weights and scenario tests.

Order (each step ends with `mvn -q test-compile` in `backend/`; the owner runs the tests):

1. records and enums of §12.1, `NetworkParameters`, `TestNetwork`;
2. builder steps 0–9 + builder tests (B2, M2 shapes, invariant);
3. `NetworkGraph` / `QueryGraph` accessors, `aStarScale`, per-type z arrays;
4. turn rule: checker predicate, `SearchTurns`, contraction refusal + scenarios 15, 15b;
5. corridor in the checker;
6. M1, M4, M3 joins + scenarios 18, 19, 20 and `PolygonFamilyTest`;
7. ride type (§12.7) + scenarios 13a–f, 21;
8. `RawInputOracle`, `RealisticNetworks`, the realistic property test and its floors;
9. perf test re-measured, numbers recorded (before / after).

### 12.11 As implemented (13 November 2026)

Steps 1 to 9 of §12.10 are coded; the owner runs the tests, nothing here was run through Maven.
Deviations from §12.1–12.10, none changing a rule:

- **Cluster rule (added after the realistic property test).** The per-node windows of §12.4 miss a
  U-turn drawn over a connector of 30 to 60 m: each node sees about 140° and the sum is 180°.
  `RouteGuarantees` (and `SearchTurns.pathOk`, `RawInputOracle` check 4) now also measure the turn
  between the window before a node and the window after any later node closer than 100 m along the
  route (`RouteGuarantees.CLUSTER_M`). The search side keeps its one-state look-back only; the
  checker refuses what it lets through.
- **Twin fold.** Two carriageways closer than 10 m on average still fold into one two-way edge when
  the contraction makes them twins (same node pair, same geometry within `dedupMeanDistM`). From
  15 m on they stay two edges (scenario 15b uses 40 m).
- `secondaryFamiliarityWeight` is the constant `NetworkGraphBuilder.SECONDARY_WEIGHT` (0.25), not a
  `GeneratorParameters` field: the builder computes the per-type arrays and does not see the
  generator's parameters.
- `RouteGenerator.generate` also throws when `maxTurnDeg < contractionMaxTurnDeg`, as §12.2 says;
  `GeneratorFailure` details gain `NO_APPROACH`.
- Builder: an edge end within `nodeMergeM + 0.5` of its node is moved onto the node (`snapEnds`), so
  that steps join to less than 1 m (nodes merged by distance keep the first key's position).
- Tests: the new scenarios are in `RouteGeneratorReviewScenarioTest` (15, 15b, 17, 18, 19, 21,
  13a–f, and a stand-in for 20: the dual carriageway whose flow solution is rejected at the join),
  scenario 16 in `NetworkGraphObservationsTest`. `RawInputOracle` matches the ends to the nearest
  live input *segment* within `snapToNodeM + 12`, judges direction and type on the headings just
  before and just after each sample (a corner is not a wrong way), takes `by(X)` over the street
  (pair of ends) and counts a reused stretch only from 40 m on.
- `RealisticNetworks` ends its walks mid-edge or at a node, not at the team location, and the
  one-way class takes `D = max(15 km, chord / ρ)` so that the end exists in a 10 km network.
- **Floors.** At 1.2 D of admitted road within D/2 the measured success rates were 25 % (loop),
  31 % (cafe) and 76 % (one-way); 1.2 D is necessary, not sufficient, for a loop without reuse in
  a network of about 10 km. The property test therefore counts the requests with 3 D (loop 13/20,
  cafe 18/25, one-way 47/61 succeeded) and its floors are 80 % of those figures. The cafe polygon
  family gives candidates in 56 % of the cases, below the 0.60 first guess.
- Times on the 160 x 160 grid (50 900 edges): build 2.3 s (before 2.3 s), 50 km loop 0.41–0.44 s
  (before 0.33–0.63 s).

### 12.12 Second review (13 November 2026)

Nine findings, all applied; this section amends §12.3, §12.4 and §12.7 where they disagree.

- **Start or end on a forbidden edge (§5.5 types).** `Snapper.snap` takes an admission predicate
  and picks the nearest *admitted* edge within `snapMaxM`; a forbidden edge is chosen only when none
  is in reach. In that fallback `EdgeWeights.banned` unbans only the piece toward the nearer end
  node of the split edge, so the forbidden stretch is bounded by half the edge. Oracle check 9
  exempts a sample of an end edge only within half that edge (plus 4 m) of the route end.
  `RouteChecks.queryGraph` snaps the same way.
- **Direction of a one-way (step 6).** A direction counts as observed only when one live track
  covers it for at least `min(supportMinCoverM, supportMinCoverShare · len)`, the support rule; when
  neither direction qualifies the direction of the largest piece is kept. A few metres of wrong-way
  entry no longer open the street.
- **`trackType`, `bicycle`, `foot` (step 6).** Majority by overlap metres, absent (code 0) counted
  like any value, ties to the most restrictive (higher code).
- **B2, invented segment.** `placePartialBoth` uses the neutral fit only for a slot that holds no
  geometry; otherwise a piece that overlaps nothing needs its end at the gap to lie within
  `dedupMeanDistM` of the nearest piece's end (`abutFit`). `stitch` returns null (orphan) when two
  slices do not meet within `dedupMeanDistM`.
- **B1, contraction and the cluster rule.** `tryContract` also refuses (`hidesClusterTurn`) when,
  on the chain walked through degree-2 nodes, the heading before any point within `CLUSTER_M`
  upstream and after any point within `CLUSTER_M` downstream (10 m steps, upstream + downstream
  offset ≤ `CLUSTER_M`) differ by `contractionMaxTurnDeg`. Scenario 15b now closes the spur on a
  node Z other than X, with connectors of 15, 40 and 80 m.
- **Hairpins the team rides.** `NetworkGraph.riddenThrough(node)`: team degree 2 and one live track
  on both edges. `turnApplies` (single node) exempts it; `clusterApplies` (the 100 m cluster rule,
  checker and search) does not, so one apex node is a hairpin and two such nodes turning the route
  back on itself are still a U-turn. Known limit: an apex node followed within 100 m by another
  junction that completes the turn is refused.
- **Performance.** `SearchTurns.windowHeading` reads the shared coordinate arrays in place
  (`QueryGraph.pointOnState`, cached `polylineLength`): no copy, no reversal, no list. A 45 m edge
  case is added to `RouteGeneratorPerformanceTest` (to be measured, the figures are not recorded
  here).

### 12.13 Third round (13 November 2026)

Amends §12.12 where they disagree. Test run of the owner: 149 tests, 2 failures and 1 error; now 152
generator tests, all green.

- **Test failures, root causes.**
  - *Oracle check 8* (route ends against the nearest live input point) compared the route start and
    end with the nearest live point of any type, while the generator, since §12.12, snaps to the nearest
    *admitted* edge within `snapMaxM` (plan §5.5: a start beside a footway begins on the road). The
    oracle was wrong, not the generator: plan §2 only asks that the route itself use team roads, the
    S and E points may be off the network by up to `snapMaxM`. The oracle now applies its own
    admission table to the segments (kinds of the segment's track and of its street) and compares with
    the nearest admitted point within `snapMaxM`, the nearest of any type only when none is. No guarantee
    was weakened: the route is still checked to start where the request snaps.
  - *Scenario 15b* ran the hand route through `E -> S1`, two nodes that are degree 2 on the closing
    loop and so contracted into the one edge `E -> W`. The test route is now `W X Y1 Y2 Z E W`.
- **B1, Y2 a team junction.** The contraction check walked the chain only through degree-2 nodes, so a
  second connector node that was a junction hid the turn (`hidesClusterTurn` stopped there).
  `walkAll` now follows, up and down, every continuation past a junction within `CLUSTER_M +
  headingFarM` (at most 16 polylines per side, the polyline that stops at the junction included), and
  contraction is refused when any pair of up and down continuations turns by `contractionMaxTurnDeg`
  or more. Scenario 15b runs with and without a side track at Y2 (connectors 15, 40, 80 m); the
  junction variant fails on the previous code (Y1 was contracted) and passes now.
- **Hairpins the team rides (owner decision, option A).** The cluster rule of §12.12 refused an apex
  followed or preceded by a junction less than 100 m away. A cluster of nodes within `CLUSTER_M` is now
  exempt from the cluster U-turn rule **only when** (1) one single live track rides every state from
  the one entering the first node to the one leaving the last (`NetworkGraph.trackIds`, the same id
  on all of them, in the route's direction or the reverse), **and** (2) the polyline between the first
  and the last node holds no straight piece of 15 m or more (14.5 m for projection slack) that
  meets the carriageways, the heading before the cluster or the one after it, at 90 degrees give or take
  25: that piece is the connector of a dual carriageway. The same predicate is
  `RouteGuarantees.hairpinTheTeamRides` (checker and `SearchTurns.pathOk`) and, with its own maths on
  the raw segments (a track under every route sample from 10 m before to 10 m after the span, the
  connector looked for among its segments inside the span), `RawInputOracle`. Scenarios 15/15b (dual
  carriageway, one track or several) stay refused; the new scenario 15c rides an apex alone, an apex
  with a second junction 30 m after and one 40 m before. A single node is still exempt through
  `riddenThrough` (team degree 2 and a common track).
- **Performance.** `NetworkGraph` precomputes the cumulative length of every geometry point (and
  `QueryGraph` of every split piece); `Geo.pointAlongCum` binary-searches it in `pointOnState`
  instead of summing `hypot` per call (`GeoTest` checks it against the walked version over ranges,
  both directions, with zero-length steps). `RvE` (grid network, best of 8 `generate` calls):
  500 m spacing 326 to 312 ms, 45 m spacing 1197 to 998 ms, 25 m spacing 2476 to 1847 ms. The perf
  bound of `RouteGeneratorPerformanceTest` is not made stricter.
- **Snap fallback.** In `EdgeWeights.banned`, the piece kept allowed at a start on a forbidden edge
  is the one whose far node is no dead end and has another admitted edge; the shorter one only when
  both qualify (or neither does). A start 2100 m up a 3000 m footway spur now leaves toward the road
  instead of into the 900 m dead end (new scenario 22). The forbidden stretch is therefore one piece,
  at most the whole edge (oracle check 9 allows the whole edge plus 4 m, was half).
- **Realistic property test.** Owner decision: the eligibility rule stays at 3 D of admitted road
  within D/2 and the floors at 80 % of the values measured on 13 November 2026, to be recalibrated
  on the real-data bench. Stated in the test and not to be tightened or loosened before that.

#### 12.13.1 Verified findings of the round 3 review (13 November 2026)

Amends the hairpin and B1 bullets above where they disagree; 156 generator tests, all green.

- **Connector seen from the turn, not from one segment (blocker).** The 15 m / 90 degree test on one
  straight piece let a connector drawn with a vertex every 10 m, slanted or curved pass as a
  hairpin. `hairpinTheTeamRides` now refuses a span that (a) moves the route 30 m or more sideways
  (`CROSSING_MIN_M`) between its first and last node, measured across the heading before or after
  the cluster, whatever the shape, or (b) holds a straight *run* of 15 m or more across the
  carriageways, a run being consecutive pieces that bend by 20 degrees or less from where it began
  (`hasConnectorRun`), so the dotted connector is one run. `RawInputOracle` has the same two tests
  with its own maths (node positions of the passes for the chord, the route's own vertices for the
  runs). 30 m is the largest width at which the owner's own hairpin (scenario 15c, apex then a
  junction 30 m further, 20 m wide) stays legal; **known limit**: a slanted or curved connector
  between 15 and 30 m wide is indistinguishable from that hairpin and is allowed. Scenario 15b now
  also runs dotted (15, 40, 80 m) and slanted (40, 60 m) connectors, with and without a junction at Y2.
- **Continuity of the ride (major).** `NetworkGraphBuilder` keeps, per live track, which edge it
  rode into which at which node (observation order, forwarded through contraction and twin folding
  by `EdgeRec.fwd`): `NetworkGraph.transitionTracks(node, from, to)`. The exemption now needs one
  track that went from `states[k]` into `states[k+1]` at every node of the cluster, all in the
  route's direction or all reversed. A track that rode both carriageways at other times and crossed
  the connector later does not qualify (`narrowDual(1)`, and the predicate tested alone).
- **B1 cap (major).** `hidesClusterTurn` refuses the contraction when either side's enumeration
  reached `MAX_WALKS`: a truncated walk may have missed the turning continuation. Scenario 15e
  (comb of 8 and 12 dead-end spurs east of Y2, connectors 40, 60, 80 m) fails without it.
- **Narrow median (minor, not changed).** A gap under 15 m ridden by one track in one pass stays
  legal: owner decision (option A) and the signature threshold. Pinned by
  `aNarrowGapOneTrackRodeInOnePassIsAHairpinTheTeamMade`; to be revisited only with the real-data bench.
- **Start on the dead end of a forbidden edge (minor).** `EdgeWeights.banned` also frees the edge
  that leads on when the start snapped onto a base node all of whose edges are banned (scenario 22
  at 2985 m and 3040 m, which returned `NETWORK_TOO_SMALL`).


### 12.13.2 Pass identity of a hairpin, short pieces of a connector run

- **D1 (major), a hairpin is one pass.** The per-(node, from, to) set of track ids carried no pass
  identity: a track that made in-to-ring at one node on a first pass and ring-to-out at another on a
  second one granted the exemption to a U-turn nobody rode (`HairpinPassIdentityTest`, roundabout
  with one track out and back; `RawInputOracle`, geometric, already refused it). Each transition
  now records `(track, rank)` (`NetworkGraph.Passes`): the rank numbers the track's steps between two
  different final edges in the order of its own ride, computed after contraction and twin folding
  (`EdgeRec.fwd`), so steps that fold onto one edge do not count; a drop, an orphan or an excluded
  observation in the chain adds a gap of 3. `RouteGuarantees.ridesInOnePass` needs one track whose
  ranks at the successive non-skipped cluster nodes rise by 1 (route direction) or fall by 1 (all
  reversed). `SearchTurns.pathOk` shares the predicate, so checker, search and oracle agree.
- **D2 (minor), short pieces.** In `hasConnectorRun` (checker and oracle) points within
  `RUN_MIN_PIECE_M` (1 m) of the last kept point are dropped before runs are detected: a duplicate
  vertex, 0.1 m jitter or a 0.4 m back-zig no longer splits a straight 20-25 m connector into two
  runs under the 15 m threshold. Pinned for 20 m and 25 m by `aShortPieceDoesNotBreakAStraightConnectorRun`.
- **Nit.** The javadoc of `hairpinTheTeamRides` cites `CROSSING_MIN_M` (30 m), as the code does.
- Owner-accepted limits unchanged: one pass on carriageways under 15 m apart, slanted or curved
  connectors of 15-30 m, eligibility 3·D.
- **D1 residual, jumps.** A step between two live observations whose edges share no node (the
  track jumped, e.g. a cut trace) recorded no transition and no break, so two passes on either side
  kept consecutive ranks. `transitionsOf` now marks the track's next transition as a break (same
  gap as a dropped observation). Pinned by `aJumpInTheTracksRideSeparatesTwoPasses` (checker,
  `pathOk` and oracle refuse; the one real pass stays accepted).

## 13. Banc sur données réelles (14 novembre 2026)

Banc `RealDataGeneratorBench` (hors dépôt pour l'instant) sur un export anonymisé de la production :
neuf équipes, documents `network_edges` à jour. Les équipes sont nommées A à I par taille de réseau
(arêtes du graphe). Aucun chiffre ci-dessous ne vient de `summary.md` sans avoir été recompté sur
les fichiers par requête ; les points marqués « harnais » viennent de mesures complémentaires faites
le même jour avec des programmes jetables (construction lue en flux comme en production, rejeu de
requêtes, sondes sous les arêtes), hors dépôt.

### 13.1 Les réseaux

| Équipe | Traces | Arêtes du graphe | Réseau total | Plus grande composante 2-arête-connexe | Construction (banc, médiane de 3) | Graphe retenu en mémoire | Estimation du pondérateur |
|---|---|---|---|---|---|---|---|
| A | 2 726 | 69 458 | 14 979 km | 12 514 km | 20,3 s | 110 Mo | 67 Mo |
| B | 446 | 15 720 | 2 865 km | 2 086 km | 2,1 s | 18 Mo | 13 Mo |
| C | 108 | 14 094 | 10 149 km | 1 204 km | 4,9 s | 48 Mo | 21 Mo |
| D | 71 | 13 174 | 11 879 km | 550 km | 6,3 s | 54 Mo | 21 Mo |
| E | 10 | 3 151 | 1 625 km | 409 km | 0,8 s | 7 Mo | 3 Mo |
| F, G | 7 chacune | 692 | 241 km | 17 km | 0,1 s | 1 Mo | 0 |
| H, I | 1 chacune | 214 / 113 | 127 / 132 km | 0 | 0,1 s | 0 | 0 |

F et G ont exactement le même réseau (mêmes parcours). C et D sont des réseaux de grands tours
(100 à 170 km par trace en moyenne) qui se recoupent peu : beaucoup de kilomètres, presque pas de
cycles. « Composante 2-arête-connexe » est une approximation stricte de ce qu'une boucle peut
utiliser (elle explique les 0 km des équipes à une seule trace).

### 13.2 Mémoire : la construction de l'équipe A ne tient pas dans le tas de production

**Ce que disaient les chiffres du banc.** Le banc a été lancé avec `-DargLine=-Xmx1228m`, mais le
tas n'a pas été plafonné : le pic échantillonné de l'équipe A atteint 3,2 Go. Dans `backend/pom.xml`
Surefire a `<argLine>@{argLine}</argLine>` ; la propriété arrive bien dans la JVM fille comme
propriété système (`argLine=-Xmx1228m` dans le rapport Surefire) mais pas comme option de la JVM, et
la machine (30 Go) donne par défaut un tas d'environ 7,5 Go. Ce qui marche : `JAVA_TOOL_OPTIONS=-Xmx…`
(la JVM fille l'affiche au démarrage). De plus le banc garde en mémoire tous les documents de
l'équipe (703 millions de caractères pour A) pendant la mesure, ce que la production ne fait pas
(`streamTracks` lit par paquets de 32). Donc : « graphe retenu » est la seule mesure propre (le
graphe seul, après trois GC) ; le pic échantillonné du banc compte les documents et les déchets et
ne dit rien du pic de production.

**Mesure refaite (harnais).** Lecture en flux, une ligne à la fois, comme `TeamNetworkCache.build`
(analyse JSON, `TrackInputMapper`, `NetworkGraphBuilder.build`), tas vide au départ :

| Équipe | Tas | Résultat | Entrées (`TrackInput`) vivantes avant la construction | Tas vivant après GC, max pendant la construction |
|---|---|---|---|---|
| A | 920 Mo (`BACKEND_MEMORY` par défaut, 1 536 M × 60 %) | **OutOfMemoryError** dans `NetworkGraphBuilder.collect` | — | — |
| A | 1 228 Mo (2 Gio × 60 %) | **OutOfMemoryError** dans `NetworkGraphBuilder.transitionsOf` | — | — |
| A | 3 000 Mo | construit en 12-13 s | 470-490 Mo | 1,66 Go (1,75 Go quand l'ancien graphe reste en cache pendant la reconstruction) |
| B, C, D | 920 Mo | construits (2 à 7 s) | 50-70 Mo | 200 à 350 Mo |

Un deuxième essai du banc lui-même plafonné à 2 000 Mo (documents en mémoire) finit aussi en
OutOfMemoryError après une suite de GC complets de 200 ms.

Pourquoi : A apporte 1 967 881 observations d'arêtes (7,55 millions de points) pour 69 458 arêtes
finales, chaque rue étant vue en moyenne 28 fois. L'estimation du lot 3 (§2.3 : « environ 1 million
de `TrackEdge`, pic d'environ 300 Mo ») est fausse d'un facteur 5 sur le pic. Trois copies coexistent :
la liste de `TrackInput` (records `TrackEdge`, `Double` encapsulés, `LatLon` par point ; gardée par
`TeamNetworkCache.build` et par `Work.tracks` jusqu'à la fin), un `Obs` par observation avec ses
propres tableaux projetés `xs`/`ys` (`NetworkGraphBuilder.classify`, l. 335-346, qui recopie même
les géométries que `TrackInputMapper` avait mises en commun), et un `RawTransition` par pas.

Conséquence : **la première requête de génération de l'équipe A ferait tomber le tas du backend
entier** (OutOfMemoryError dans un thread de travail, GC complets en rafale avant), pas seulement la
génération.

**Pondérateur.** `TeamNetworkCache.weigh` sous-estime le graphe retenu d'un facteur 1,4 (B) à 2,6 (D),
1,6 pour A : les 192 Mo de `max-weight-mb` peuvent représenter 300 à 500 Mo réels.

### 13.3 Requêtes

Requêtes tirées par équipe (départs = premiers points des traces les plus fréquents, à plus de 2 km
les uns des autres), boucles de 30 à 150 km, cap N/E/S/O ou aucun, f = 0 / 0,5 / 1, plus gravel, VTT
et aller simple. Le banc n'a pu passer que 48 des 324 requêtes de A dans son temps ; le rejeu
(harnais, même graine, mêmes résultats sur B, C et D à l'identique) en a passé 300.

| Équipe | Requêtes | Succès | Arrêtées (5 s) | `NO_ROUTE` | `NETWORK_TOO_SMALL` | Temps des succès p50 / p90 / max |
|---|---|---|---|---|---|---|
| A (banc, 48) | 48 | 20 (42 %) | 8 (17 %) | 11 | 9 | 2,5 / 4,4 / 4,7 s |
| A (rejeu, 300) | 300 | 124 (41 %) | 34 (11 %) | 108 | 34 | 2,4 / 4,4 / 5,1 s |
| B | 154 | 22 (14 %) | 0 | 55 | 77 | 0,5 / 1,2 / 1,4 s |
| C | 300 | 4 (1 %) | 0 | 193 (dont 80 `TAIL_TOO_LONG`) | 103 | < 0,2 s |
| D | 300 | 7 (2 %) | 0 | 89 (dont 51 `TAIL_TOO_LONG`) | 204 | < 0,1 s |
| E | 77 | 0 | 0 | 77 | 0 | — |
| F à I | 22 | 0 | 0 | 13 | 9 | — |

- **Garanties** : les 84 propositions des équipes A à D rendues, revérifiées par `RouteGuarantees`, n'ont aucune
  violation ; toutes sont à ±10 % de D (0,91 à 1,09). Croisements : 0 pour 59 sur 73, au plus 2.
- **Le départ décide.** A : les départs 0, 1, 4 et 6 réussissent 20 fois sur 29 ; les départs 2, 3,
  5 et 7 jamais (0 sur 19), quelle que soit la distance. B : le départ 1 est sur un îlot de 2 km
  (77 `NETWORK_TOO_SMALL`, légitimes) ; le départ 0 réussit 22 fois sur 77, et rien au-delà de 80 km.
- **Distance** (A, banc) : 30 km 6/11, 50 km 1/5, 80 km 5/8, 110 km 3/8, 150 km 2/11 ; VTT 2/3,
  gravel 0/1, aller simple 1/1. B : 30 km 8/15, 50 km 9/15, 80 km 3/15, 110 et 150 km 0/15.
- **Rejets** : presque tous `DISTANCE_OUT_OF_TOLERANCE`. B : 33 des 55 `NO_ROUTE` avaient des
  candidats, tous hors des ±10 %.
- **Familiarité** : le curseur ne sépare que f = 0 du reste. B : f = 0 → 0,33 (médiane atteinte),
  f = 0,5 → 0,54, f = 1 → 0,53. A : 0,36 / 0,43 / 0,27 (6 propositions seulement à f = 1).
- **Cap** : écart médian 12° (A) et 17° (B), au plus 48°.

### 13.4 Questions ouvertes : verdicts

**Demi-tour en un passage entre chaussées à moins de 15 m ; connecteur oblique ou courbe de 15 à
30 m (limites acceptées).** Le comptage du banc (`uTurnEventsByClass`, 185 « LT15 » chez A, un par
proposition au moins) est **faux** : `RealDataGeneratorBench.java:847` fait `turn = 180 - turn` sur un
angle déjà calculé comme un virage, si bien que toute ligne droite compte comme un demi-tour de 180°.
Recompté par le harnais avec l'angle corrigé et l'écart latéral mesuré entre la ligne d'arrivée
(40 m avant) et la ligne de départ (40 m après), sur 120 requêtes de A et toutes celles de B, C, D,
au milieu du parcours (hors zones de queue), parcours route :

| Équipe | Propositions | Demi-tour < 15 m | 15-30 m | ≥ 30 m (tour d'un pâté de maisons, épingle large) |
|---|---|---|---|---|
| A | 106 | 5 propositions (5 %), toutes « sur place » (le virage est complet en un point) | 7 propositions (7 %) | 61 événements |
| B | 30 | 0 | 0 | 17 |
| C | 4 | 2 (une même route rendue deux fois) | 0 | 6 |
| D | 7 | 0 | 0 | 5 |

Le contrôle 5 de l'oracle (« fold ») trouve les mêmes : 4 propositions de A sur 43 au banc.
**Verdict : garder les deux limites et leurs seuils.** Elles coûtent un aller-retour visible sur
environ une proposition sur vingt chez A, aucune ailleurs ; le resserrement coûterait des épingles
réellement roulées (VTT en tête : 35 événements sur les propositions gravel et VTT de A, presque tous
≥ 30 m). À revoir seulement si les retours d'usage les signalent.

**Éligibilité 3·D et planchers à 80 %.** Sur données réelles, la règle (route admise à moins de D/2
du départ ≥ 3 D) ne prédit pas le succès : A, 48 requêtes éligibles à 2 D, 3 D et 4 D, 42 % de
succès ; C, 165 éligibles à 3 D, 4 succès ; E, 77 éligibles, aucun. La variable manquante est la
**cyclicité** : C et D ont beaucoup de route autour du départ mais en lignes (tours), qui ne font pas
de boucle. **Verdict : ne pas recalibrer les planchers du test réaliste sur ce banc** (le test tourne
sur des grilles, où la règle est juste) ; donner au banc une éligibilité « route admise de la
composante 2-arête-connexe du départ, à moins de D/2 » avant toute recalibration.

**Suurballe (famille « aller par un côté, revenir par l'autre »).** Sur 53 succès des équipes A à D,
32 ne viennent que de cette famille (A 6/20, B 16/22, C 3/4, D 7/7) ; 4 seulement ne viennent que du
polygone (tous chez B). **Verdict : on garde.** C'est la famille qui trouve les boucles des petits
réseaux.

**Budget de 5 s.** Chez A, 11 à 17 % des requêtes sont arrêtées, et le client reçoit alors
`ROUTE_GENERATOR_BUSY` (« occupé »), ce qui est faux. Rejouées sans plafond, les 8 requêtes arrêtées au banc et une arrêtée dans un rejeu chargé : 6 sur 9
réussissent entre 4,9 et 8,2 s, 3 finissent en `NO_ROUTE`. Le p90 des succès est à
4,4 s **sur cette machine** ; un serveur 20 % plus lent en arrête nettement plus (une requête à 4,7 s
au banc a été arrêtée dans un rejeu concurrent). B, C, D sont loin du budget (max 1,9 s).
**Verdict : passer à 10 s** maintenant (A passerait de ~42 % à ~50 % de succès, plus aucune réponse
« occupé » trompeuse pour les requêtes qui aboutissent), et mesurer le temps réel sur le serveur avant
d'aller plus loin. Le budget de travail par requête (16 points de retournement, 32 polygones) reste
déterministe ; seule la coupure change.

**Mémoire.** Voir §13.2 : **bloquant pour A**, sans objet pour les autres (pic ≤ 350 Mo, graphe
≤ 54 Mo).

**Intervalle de reconstruction (10 min) et attente de construction (30 s).** La reconstruction de A
coûte 20 s au banc (documents déjà en mémoire), 12-13 s de graphe plus 7-8 s d'analyse au harnais ;
en production s'ajoute la lecture de ~700 Mo de `network_edges::text` en base, et le processeur peut
être plus lent : compter 30 à 50 s. Pendant ce temps, une requête de la même équipe attend le verrou
jusqu'à 30 s puis reçoit 503 ; une requête d'une autre équipe qui doit construire aussi. Et
`min-rebuild-interval` ne protège que les changements de traces : **tout enregistrement de parcours
de A relance une construction complète à la requête suivante.** Le banc ne dit pas à quelle fréquence
A enregistre des parcours (l'export n'a pas de dates). **Verdict : garder 10 min pour les traces ;
une fois la mémoire réglée, étendre le report aux changements de parcours pour les grands réseaux**
(proposition 6 ci-dessous), et porter `build-wait` à 60 s.

### 13.5 Défauts de correction relevés

Aucune violation du contrôleur. L'oracle `RawInputOracle` signale 27 propositions (A 21, B 4, C 2) ;
chacune a été rejouée et les observations brutes sous l'arête fautive sondées (harnais).

1. **Contresens ouvert sur toute l'arête par une observation partielle (vrai défaut).** Une arête à
   sens unique est ouverte dans le sens contraire dès qu'une trace la couvre dans ce sens sur
   `min(supportMinCoverM, supportMinCoverShare × longueur)` = min(100 m, moitié de l'arête)
   (`NetworkGraphBuilder.aggregate`, l. 1074-1075). Sur données réelles, des traces prennent le
   contresens (probable contresens cyclable) sur une partie de la rue seulement, et le générateur
   roule alors à contresens là où personne de l'équipe ne l'a fait :
   - équipe B, requête 66, proposition 0 : arête de 585 m, contresens observé sur 45-370 m depuis une
     extrémité, la proposition entre par l'autre et roule **environ 210 m** à contresens sans
     observation ;
   - équipe A, requête 4 (banc), proposition 1 : arête de 220 m, contresens observé sur 145 m,
     **environ 75 m** sans observation ;
   - équipe A, requête 46 (banc), proposition 0 : arête de 65 m, contresens observé sur 40 m,
     **environ 25 m** sans observation.

   Ce n'est pas une limite acceptée : le plan §4 n'autorise un sens unique « que dans le sens où
   l'équipe l'a déjà parcouru ». Correction : proposition 4.
2. **Départ sur un îlot admis (vrai défaut d'accroche).** Équipe A, départ 3 (le quatrième lieu de
   départ le plus fréquent de l'équipe), requêtes 0, 19, 23, 25, 28, 35, 40, 42, 44 du banc :
   `NETWORK_TOO_SMALL` en 4 ms pour toutes les distances, alors que 185 km de route admise sont à
   moins de 15 km. Le point tombe sur un bout de voie piétonne autorisée aux vélos (41 m, une seule
   trace), donc admis pour la route ; ce bout ne touche que 0,1 km d'arêtes admises, entourées de
   voies non admises. `Snapper.snap` prend l'arête admise la plus proche sans regarder si elle mène
   quelque part. Correction : proposition 5.
3. **Faux positifs de l'oracle (pas de défaut du générateur), les autres signalements :**
   - *contresens* : rouler à l'opposé d'une observation `AGAINST`, c'est rouler dans le sens légal, mais le
     contrôle 3 ne retient comme « parcouru » que le sens d'une observation (A 1, 12, 33) ; voies
     jumelles à 3,7-6 m repliées par le constructeur (`dedupMeanDistM` 10 m) alors que l'oracle
     regarde à 4 m (`NEAR`) (A 9, B 5) ; bouts de 5 m à un carrefour (A 1, 26) ; données
     contradictoires entre documents pour la même rue (A 18) ;
   - *type ROAD* (B 42) : sentier et petite route jumeaux à 4-6 m, repliés en une arête ;
   - *virages* (A 5, 9, 16, 18 ; C 1, 196) : 151 à 156° (178° une fois) pour des nœuds à 50-100 m,
     soit le seuil de 150° et la borne de 100 m mesurés différemment (oracle sur la polyligne et des
     passages quantifiés à 5 m, contrôleur sur les longueurs d'arêtes) : des cas limites, pas une
     règle contournée.

   À aligner dans l'oracle (sens légal d'un `AGAINST`, tolérance des jumeaux), pour qu'il redevienne
   un signal exploitable sur données réelles.
4. **Non expliqué.** A, départs 2, 5 et 7 : aucune proposition (0 sur 10 au banc), route admise
   abondante et connexe, ni pont ni îlot ; aucun candidat produit (`disjointInfeasible` 3 à 64).
   Exemple reproductible : A, requêtes 17, 27, 30 (départ 2, 30 et 50 km). Équipe E : 77 `NO_ROUTE`
   en moins de 65 ms, non diagnostiqué (probablement aucune boucle de la bonne longueur dans ses
   409 km de cycles).

### 13.6 Propositions, par ordre

1. **Garde-fou mémoire avant d'ouvrir le site à A (bloquant).** Dans `TeamNetworkCache.build`
   (`TeamNetworkCache.java:203-231`), compter les observations pendant la lecture en flux et abandonner
   au-delà d'une borne configurable (par exemple `pedalons.route-generator.max-observations` = 600 000 ;
   B en a 189 000, A 1 968 000), avec une erreur dédiée et le verdict mis en cache par empreinte pour
   ne pas relire 700 Mo à chaque requête. Effet : plus d'OutOfMemoryError ; A reçoit un refus
   explicite. Risque : faible ; un code d'erreur au contrat. Taille : S.
2. **Régime du constructeur (pour rouvrir A).** Partager les tableaux projetés par géométrie (une
   `IdentityHashMap` sur la `List<LatLon>` commune dans `classify`), lâcher les `TrackInput` dès
   `collect()` fini (le constructeur en devient propriétaire), et à terme lire les observations en
   flux sans liste intermédiaire. Gain attendu : de l'ordre de 300 à 600 Mo sur le pic de A, à
   remesurer sous 1 228 Mo plafonnés. Risque : déterminisme (l'ordre par identifiant de trace est
   déjà celui de la requête SQL). Taille : M. Si le pic reste au-dessus, relever `BACKEND_MEMORY`
   (le §2.3 du lot 3 le prévoit) : il faudrait au moins 3 Gio de conteneur au rythme actuel.
3. **Budget 10 s** (`application.properties:409`, `pedalons.route-generator.time-budget=PT10S`).
   Effet : A ~42 % → ~50 % de succès, moins de 503 trompeurs. Risque : un permis tenu plus longtemps
   (`max-concurrent` = processeurs/2) ; acceptable avec `permit-wait` 2 s et la limite par personne.
4. **Contresens partiel** (`NetworkGraphBuilder.aggregate`, l. 1074-1080) : pour ouvrir le sens
   contraire d'une arête à sens unique, exiger une couverture de presque toute l'arête (par exemple
   longueur − 2 × `coverageGapM`) au lieu de min(100 m, moitié), ou couper l'arête aux bouts des
   observations partielles. Effet : supprime les trois cas de §13.5. Risque : quelques rues à
   contresens cyclable perdues dans les centres anciens. Taille : S.
5. **Accroche utile** (`Snapper.snap`) : ignorer une arête admise dont la composante admise fait
   moins de quelques kilomètres (ou moins de `networkTooSmallFactor × D`) quand une autre arête
   admise est à portée. Effet : le départ 3 de A redevient utilisable. Risque : un départ très
   légèrement déplacé. Taille : S.
6. **Reconstructions de A** : reporter aussi les changements de parcours de `min-rebuild-interval`
   au-delà d'une taille de réseau (servir l'ancien graphe, retard ≤ 10 min, à écrire dans le tableau
   du §2.5 du lot 3), et `build-wait` à 60 s. Effet : un enregistrement de parcours ne coûte plus
   une reconstruction de 30 à 50 s à la personne suivante. Risque : un parcours tout juste créé
   absent pendant 10 min. Décision du propriétaire.
7. **Pondérateur** (`TeamNetworkCache.weigh`, l. 247-253) : recaler les constantes sur les graphes
   retenus mesurés (× 1,6 à 2,6), sinon le cache de « 192 Mo » occupe jusqu'à 500 Mo. Taille : XS.
8. **Familiarité** : β = 1 ne sépare pas f = 0,5 de f = 1 ; essayer β = 2 et 3 au banc. Taille : XS
   plus un passage du banc.
9. **Banc** : corriger `RealDataGeneratorBench.java:847` (supprimer `turn = 180 - turn` et mesurer
   l'écart entre la ligne d'arrivée et celle de départ) ; éligibilité sur la composante
   2-arête-connexe ; noter `Runtime.maxMemory()` dans le rapport et documenter
   `JAVA_TOOL_OPTIONS=-Xmx…` ; lire les documents en flux pour que le pic mesuré soit celui de la
   production.

### 13.7 Pour le propriétaire, en clair

- **Grande équipe (A) : pas utilisable aujourd'hui, et dangereuse.** Construire son réseau demande
  plus de 1,2 Go de mémoire alors que le serveur en donne 0,9 à 1,2 Go en tout : la première demande
  ferait planter le serveur pour tout le monde. Il faut le garde-fou (proposition 1) avant d'ouvrir le
  site, puis le régime mémoire (proposition 2) pour la rouvrir. Une fois cela fait, ce que verront
  ses membres : environ quatre demandes sur dix aboutissent (en 2 à 5 s, jusqu'à 10 s avec le
  nouveau budget), avec des parcours justes en distance et sans faute de règle ; mais certains lieux
  de départ habituels ne donnent jamais rien (« réseau trop petit » ou « aucun parcours »), environ une
  proposition sur vingt fait un aller-retour visible sur la même route, et la première demande après
  l'enregistrement d'un parcours attend 30 à 50 s.
- **Équipes moyennes (B) : utilisable.** Réponse en moins de 2 s. Depuis le lieu de départ principal,
  une demande sur trois aboutit jusqu'à 50 km ; au-delà de 80 km presque jamais : le réseau de
  l'équipe est trop petit, et le message le dit.
- **Équipes de grands tours (C, D) et petites équipes (E à I) : techniquement sûr, mais presque
  inutile.** 1 à 2 % de succès chez C et D, aucun chez E à I : leurs parcours sont des lignes qui ne
  se recoupent pas, il n'y a pas de boucle à proposer. Les personnes verront surtout « réseau trop
  petit » ou « aucun parcours trouvé ». C'est le comportement attendu, à présenter comme tel sur le
  site (« le générateur s'appuie sur les parcours que votre équipe a déjà roulés ; plus elle en
  partage, plus il propose »).
- Un vrai défaut de règle trouvé : le générateur peut rouler jusqu'à quelques centaines de mètres à
  contresens d'un sens unique que l'équipe n'a pris à contresens qu'en partie (proposition 4).

### 13.8 Suites du 14 novembre : garde-fou et régime mémoire (propositions 1 et 2)

Faites le même jour, mesurées sur le même export (vérifié contre la production : mêmes nombres de
traces par équipe) avec un harnais jetable qui lit en flux comme `TeamNetworkCache.build`.

**Proposition 1, garde-fou.** `TeamNetworkCache.build` compte les observations (arêtes des
documents à jour) pendant la lecture et s'arrête à `pedalons.route-generator.max-observations` ;
l'équipe reçoit `GENERATOR_NETWORK_TOO_LARGE` (400, contrat `14.15.0`). Le refus est gardé par
empreinte sous les règles d'un graphe (immédiat si un parcours change, `min-rebuild-interval` si
seuls les documents bougent) : les documents ne sont pas relus à chaque requête.

**Proposition 2, régime du constructeur.** `NetworkGraphBuilder.Intake` reçoit les traces une à
une et n'en garde que les observations ; `build(List)` passe par lui. Trois changements :

- plus de liste de `TrackInput` (470 à 490 Mo chez A) : positions brutes gardées en degrés, projetées
  en place quand la référence (moyenne des extrémités) est connue, la décision `PARTIAL_TO` /
  `FLOATING` reportée à ce moment-là ;
- tableaux projetés partagés par géométrie d'entrée (identité de la liste que `TrackInputMapper` met
  en commun) : chez A, 1 967 881 observations mais 198 985 géométries distinctes (839 863 points au
  lieu de 7 551 764), et le tableau inversé calculé une fois par géométrie au lieu d'une fois par
  pièce ;
- pièces et observations allégées, emplacements lâchés dès les arêtes construites, observations dès
  les transitions calculées.

Le graphe est le même **au bit près** : empreinte SHA-256 de tous les champs de `NetworkGraph`
identique avant et après, pour les neuf équipes, par la liste comme par le flux.

| Équipe A, lecture en flux | Avant | Après |
|---|---|---|
| Tas de 920 Mo (ParallelGC, options de la production) | OutOfMemoryError | construit, 5 GC complets |
| Tas de 650 Mo | — | construit, 13 GC complets |
| Tas de 500 Mo | — | OutOfMemoryError (G1 : construit) |
| Tas vivant après GC, max pendant la construction | 1,66 Go | 440 Mo |
| Construction après lecture | 12-13 s | 11,5-12 s |

Soit environ 225 Mo par million d'observations. **Borne par défaut : proportionnelle au tas**
(`-1` : tas / 900 octets, un quart du tas pour une construction), soit environ 1 million pour le tas
par défaut de 920 Mo (B en a 188 600, D 103 493, C 82 493 : toutes passent) et 4,7 millions pour un
tas de 4 Go, où A (1,97 million) passe. Une borne fixe aurait refusé A en production au premier
déploiement, alors qu'elle y tient.

**Constat en production le 14 novembre** : le backend de production a un conteneur de 8 Gio et un
tas de 4 Go (`JAVA_MAX_MEM_RATIO=50`), pas les 920 Mo supposés au §13.2 ; la construction de A n'y
aurait pas débordé, même avant. La préproduction, elle, est à 1,5 Gio (920 Mo de tas). Le §13.7
reste vrai pour toute instance au réglage par défaut.

### 13.9 Suites du 14 novembre : contresens partiel et accroche (propositions 4 et 5)

Mesurées sur le même export, graphe construit et 24 boucles route (8 départs du banc × 30, 50 et
80 km) rejouées avec le code d'avant et celui d'après.

**Proposition 4, contresens partiel.** Dans `NetworkGraphBuilder.aggregate`, un sens n'est plus
ouvert par les seules observations `AGAINST` (rue à sens unique prise à contresens) que si, en plus
du seuil de support, ces observations couvrent ensemble l'arête d'un bout à l'autre, à
`coverageGapM` près aux extrémités et entre elles. Deux traces qui se relaient suffisent : chaque
mètre a été roulé dans ce sens. Un sens roulé légalement (`FORWARD` ou `BOTH`) garde le seuil
d'avant, min(100 m, moitié de l'arête) ; sans cela une arête recousue de morceaux, qu'aucune trace
ne couvre en entier, perdrait son sens légal. Quand rien n'atteint le seuil, la plus grande
observation légale passe avant la plus grande tout court.

| Équipe | Arêtes refermées dans un sens | Longueur | Boucles réussies (avant → après) |
|---|---|---|---|
| A (69 458 arêtes) | 54 | 10,6 km | 11/24 → 11/24 |
| B (13 174 arêtes) | 1 | moins de 0,1 km | 1/24 → 1/24 |

Aucune arête ne change autrement. Le risque annoncé (rues à contresens cyclable perdues) reste
donc faible : 54 arêtes sur 9 605 à sens restreint chez A.

**Proposition 5, accroche utile.** `EdgeWeights.leadingOn` donne les arêtes admises dont le
morceau connexe de route admise fait au moins `networkTooSmallFactor × D` ; `Snapper.snap` les
préfère dans tout le rayon `snapMaxM`, puis prend l'arête admise la plus proche, puis n'importe
laquelle, comme avant. Le seuil n'est pas un réglage de plus : en dessous, la requête est refusée
`NETWORK_TOO_SMALL` quoi qu'il arrive, puisque la recherche ne sort pas des arêtes admises. Seules
des requêtes qui échouaient changent donc de résultat.

Le départ 3 de A s'accroche maintenant à 196 m, sur la composante principale (12 514 km de
cycles), au lieu du bout de 41 m. **Il n'obtient pas de parcours pour autant** : il rejoint les
départs non expliqués du §13.5 point 4 (`NO_ROUTE` en 280 ms, aucun candidat, 6 points de demi-tour
essayés et tous sans deux chemins disjoints, comme le départ 2). Chez B, le départ 0 passe de
`NETWORK_TOO_SMALL` à `NO_ROUTE` / `TAIL_TOO_LONG`. L'accroche est corrigée, le défaut suivant est
celui du point 4, à diagnostiquer avant de compter ces départs comme rétablis.

**Écart au plan §5.5, assumé.** Le plan fait partir le parcours du point admis le plus proche ; le
départ peut maintenant en être éloigné, jusqu'à `snapMaxM` (2 km) : 196 m pour le départ 3 de A,
environ 1 km dans deux réseaux aléatoires des tests de propriété. `RawInputOracle` (contrôle 8)
l'accepte seulement quand le point admis le plus proche est sur un morceau de route admise trop
court, qu'il mesure lui-même sur les clés de nœuds brutes, avec un facteur 2 de marge (le
constructeur fusionne des nœuds et replie des rues jumelles). Si un départ déplacé d'un kilomètre
ne convient pas au produit, borner la distance dans `Snapper.snap` plutôt que retirer la règle.

### 13.10 Diagnostic du 15 novembre : les départs sans candidat (§13.5 point 4)

Sondes jetables sur le même export, équipe A, boucles route de 30, 50 et 80 km depuis les 8 départs
du banc. Deux constats, le premier explique les départs 2, 3 et 5, le second pèse sur tous.

**1. La connectivité est calculée sur un graphe que la recherche ne parcourt pas.** Les composantes
2-arête-connexes de `NetworkGraph` (et donc `TailPlanner.forced`, `isHub`, le filtre de composante
de `LoopFamily`, le contrôle `NETWORK_TOO_SMALL`) valent pour le graphe entier, sans sens et tous
types confondus. La recherche, elle, ne roule que les arêtes admises pour le type, dans les sens
ouverts. Les trois départs sont dans la grande composante (12 514 km de cycles), donc aucune queue
forcée n'est planifiée, alors que pour la demande ils n'ont pas de cycle :

| Départ | Ce que voit la recherche | Preuve |
|---|---|---|
| 2 | Poche de dix nœuds de petite route (support 5 à 7) dont on sort par un sens unique ; tous les autres accès sont des chemins, une piste et des marches, non admis en route (support 45 à 175 : c'est un lieu de départ gravel) | 44 334 nœuds atteints à l'aller, 9 au retour ; en gravel et en VTT, 3 propositions aux trois distances |
| 3 | Circuit à sens unique de cinq arêtes (support 1 ou 2) : on en sort, aucune trace n'y rentre | 44 382 nœuds à l'aller, 7 au retour ; échec pour les trois types |
| 5 | Départ sur une longue antenne pour le type route : les cycles ne commencent qu'au-delà de la queue permise (`tailMaxShare` × D = 7,5 km à 50 km) | à 30 et 50 km, aucun point de demi-tour n'a deux chemins disjoints (131 échecs du flot) ; à 80 km (queue de 12 km), 3 propositions |

Ces requêtes brûlent 0,25 à 2,5 s pour répondre `NO_ROUTE` sans détail. Deux corrections possibles,
de la moins chère à la plus juste : (a) tester le retour avant de chercher (une recherche arrière
depuis le départ, déjà faite par `AnchorPair` : si elle n'atteint presque rien, répondre tout de
suite avec un détail dédié, ou accrocher le départ ailleurs comme au §13.9) ; (b) calculer ponts et
composantes par type de sortie sur les arêtes admises, pour que `forced` planifie la bonne queue
(départ 5) — trois jeux de composantes par graphe, à peser dans le cache. Le banc y a sa part : il
tire ses départs du premier point des traces de tous types et les demande en route.

**2. Le flot de Suurballe n'aboutit presque jamais sur données réelles.** Sur 730 appels de
`EdgeDisjointPaths.solve`, 256 n'ont pas de flot et 474 en ont un, dont 15 seulement passent le
contrôle a posteriori ; la cause dominante est le sens unique côté départ (`assemble`, 763 refus,
deux essais par appel pour une boucle), loin devant le côté arrivée (138). Le flot ignore les sens (`flowUsable` accepte un état dès qu'un de ses deux sens est
ouvert) et le chemin côté départ est roulé à l'envers : avec 14 % d'arêtes à sens restreint
(9 659 sur 69 458), une paire de chemins de 25 km en contient presque toujours une. Le repli
séquentiel prend le relais et n'aboutit qu'une fois sur trois (160 sur 459), avec des longueurs
mal tenues : c'est lui qui donne les `DISTANCE_OUT_OF_TOLERANCE` des départs 4 et 7 à 30 et 50 km.

Essai fait sur une copie jetable : renchérir les arêtes à sens restreint dans le flot (× 3, × 10,
× 1 000) ne donne que 12 succès sur 24 au lieu de 11 ; à × 1 000 le flot aboutit 50 fois au lieu
de 15, les sens uniques restants sont inévitables près des ancres. Le levier n'est donc pas un
réglage : il faut un flot qui connaisse le sens de chaque côté (le côté départ sur le graphe
retourné), ou réparer la solution du flot au lieu de la jeter. C'est probablement la première
cause du taux de succès de A (11 sur 24 ici, environ 42 % au banc), avant le budget de temps.

### 13.11 Suites du 15 novembre : retour impossible et flot orienté

Deux corrections codées après le §13.10, mesurées sur le même export (équipe A, 24 boucles route).

**Retour impossible, réponse immédiate.** `RouteGenerator` calcule, pour une boucle, la route que
la recherche peut rouler à l'aller *et* au retour : les arêtes dont un sens est à la fois atteint
depuis le départ et mène au départ (deux recherches bornées à D, mêmes bans, mêmes sens, mêmes
virages que la recherche). En dessous de la moitié de D — le cœur d'une boucle, qui ne roule aucune
arête deux fois, fait au moins cela (`TailPlanner.pair`) — la réponse est `NO_ROUTE`, détail
`NO_WAY_BACK`. Les départs 2 et 3 répondent en 10 à 50 ms au lieu de 0,25 à 2,5 s. Le détail n'est
pas exposé (journal seulement, comme les autres), le contrat ne change pas. Un départ sur une trace
isolée sans cycle répond maintenant `NO_WAY_BACK` là où il répondait `TAIL_TOO_LONG` : même code
d'erreur, détail plus juste.

**Flot orienté.** Avec des sens uniques, le problème est une paire de chemins orientés
arête-disjoints A_S → T et T → A_E, qu'aucun flot ne résout exactement (NP-difficile : c'est le
problème des deux chemins disjoints). `EdgeDisjointPaths` cherche donc chaque passe pour un côté :
la première pour le côté arrivée (états roulés dans leur sens), la seconde pour le côté départ
(états roulés à contresens du flot), puis l'ordre inverse, et garde le cœur légal le moins cher des
deux. Un graphe sans aucun sens restreint garde le flot aveugle d'origine, donc le même calcul
qu'avant. La seconde passe peut encore échanger un tronçon avec la première, d'où le contrôle a
posteriori conservé.

| Sur 24 requêtes (A, route) | Flot aveugle | Flot orienté |
|---|---|---|
| Cœurs acceptés sortis du flot | 15 | 207 |
| Cœurs sortis du repli séquentiel | 160 | 11 |
| Appels sans aucun flot | 220 | 210 |
| Flot trouvé mais refusé dans les deux ordres | 459 | 197 |
| Requêtes réussies | 11 | 12 (départ 1 à 80 km) |

Garder le meilleur des deux ordres compte : pour un point de demi-tour à 500 m du départ 4, le
premier ordre seul rendait une boucle de 113,7 km, le second 5,1 km. Essai écarté : interdire
l'arête fautive et relancer le flot (2 ou 4 fois) ne récupère que 4 à 5 des 197 refus pour 10 à
30 % de temps en plus. Les refus restants sont des sens uniques placés du mauvais côté par
l'échange de tronçons et des virages mesurés sur fenêtre parcourue, que le flot ne modélise pas.

**Ce que ces mesures corrigent dans le §13.10.** Le flot aveugle n'était pas la première cause du
taux de succès de A : il est accepté quatorze fois plus souvent et une seule requête de plus
réussit. Les échecs restants des départs 4, 5 et 7 ne viennent pas du repli séquentiel :

- départ 7 : la plus courte boucle sans arête répétée fait 73 km par une sortie et 99 km par les
  deux autres (la boucle de 35,7 km qu'on y trouve roule deux arêtes deux fois). Les demandes de 30
  et 50 km n'ont pas de solution hors queue ; celle de 80 km en a une ;
- départ 4 : de courtes boucles existent (5,1 et 9,2 km), mais les chemins disjoints vers les
  points de demi-tour à 10 km passent tous par les mêmes boucles de 59,5 ou 62,9 km. Non expliqué :
  étranglement réel du réseau admis autour du départ, ou défaut du choix des points de demi-tour ;
- départ 5 : une boucle orientée de 0,8 km existe (sortie par un sens unique), ce n'est donc pas
  une simple antenne ; à 30 et 50 km aucun point de demi-tour n'a de flot (34 et 64 échecs), à
  80 km trois propositions. Non expliqué non plus.

Restent ouverts : ces deux départs, les composantes par type (§13.10, correction b) et le temps
perdu sur les points de demi-tour sans flot (210 appels sur 614).

### 13.12 Banc du 15 novembre : avant et après les quatre correctifs

`RealDataGeneratorBench` sur les neuf équipes de l'export, mêmes requêtes des deux côtés (120 par
équipe au plus, pas de coupure par temps global, budget de 5 s par requête), au commit en production
(`43b15bb9d`) et au commit `c03e3193a`. Les deux passages ont tourné en même temps sur la même
machine : les temps sont pessimistes de la même façon. Le tirage des départs garde son biais (§13.10).

| Équipe | Requêtes | Réussies avant | Réussies après | Arrêts sur budget avant → après |
|---|---|---|---|---|
| A (69 458 arêtes) | 120 | 55 | 53 | 8 → 15 |
| `903379379966724603` | 120 | 19 | 22 | 0 → 0 |
| `902861823942084536` | 77 | 0 | 6 | 0 → 0 |
| `902614221043964356` | 120 | 4 | 4 | 0 → 0 |
| `904316204013810796` | 120 | 2 | 2 | 0 → 0 |
| quatre petites équipes | 22 | 0 | 0 | 0 → 0 |
| **Total** | **579** | **80** | **87** | **8 → 15** |

- Les trois équipes qui gagnent le doivent au flot orienté : là où le flot aveugle ne sortait
  aucun candidat (64 échecs sur 64), il en sort 12 à 16.
- A perd deux requêtes : 8 réussites deviennent des arrêts sur budget, 4 arrêts deviennent des
  réussites, 2 échecs réussissent, 3 échecs deviennent des arrêts. Le flot orienté calcule deux
  flots par point de demi-tour : sur les 47 requêtes réussies des deux côtés, la médiane passe de
  1,6 à 2,1 s, et le budget de 5 s mord plus souvent. Aucune relance sans budget (plafond 20 s)
  ne récupère un échec, ni avant ni après.
- Le gain de temps du retour impossible n'apparaît pas dans cet échantillon : ses 23 requêtes de A
  échouaient déjà en quelques millisecondes (`NETWORK_TOO_SMALL` avant l'accroche du §13.9).
- Le contrôleur n'a refusé aucun candidat rendu. L'oracle de test signale 32 candidats sur A
  (36 avant ; les sens uniques roulés à contresens passent de 62 à 33 relevés) et des relevés
  nouveaux, non analysés : 6 candidats de `902861823942084536` pour un virage sur jonction, et sur
  A un passage répété hors queue et trois échantillons gravel sur une arête qu'aucune observation
  n'admet.
- L'oracle lui-même est devenu lent sur A (13,7 s par parcours contrôlé, à cause de
  `admittedPieceLength` ajouté au §13.9) : le passage dure 25 minutes au lieu de 10.

Suite proposée : le temps de A part dans les flots sans issue, dont la seconde passe épuise le
graphe. Un calcul de ponts par requête sur les seules arêtes admises (`BridgeFinder`, linéaire,
pas de cache) permettrait d'écarter ces points de demi-tour avant le flot et de rendre du budget.
