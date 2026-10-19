import { distance } from '@/components/map/mapUtils'
import { route as routerRoute } from '@/api/endpoints/router/router'
import KDBush from 'kdbush'
import { around } from 'geokdbush'
import { RouterProfile, type GpxImportTrack } from '@/api/dto'
import { decode1, decode2 } from '@/lib/polyline'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import type { MappableRoute } from '@/components/route/RouteMapView'

export interface Point {
  lng: number
  lat: number
}

export interface RoutePoint {
  id: string
  idx: number
  lng: number
  lat: number
  ele?: number
  manual: boolean
  /** Comes from a loaded track (file, existing route), not from the router or a gesture. */
  imported: boolean
  /**
   * The edge `points[i-1] -> points[i]` is a straight line (requested mode, not "no router call").
   * Carried by the arrival point, like the leg data of the profile; always false on the first point.
   * A straight leg has no inner point: it is exactly one edge.
   */
  direct: boolean
  /**
   * Climb (m) of the routed leg arriving at this point, as /api/router measured it. Absent: this
   * point does not end a routed leg. Carried by the leg's last point, like `direct`.
   */
  legAscend?: number
  /**
   * Cumulative climb (m) of the loaded track from its start to this point, scaled to the track's
   * reference D+. Imported points only.
   */
  importAscend?: number
  /** Index of the loaded track this point comes from, in the editor's `sources` (imported points only). */
  sourceId?: number
  /** Index of this point in that source track: lets a deletion give back the file between two of its points. */
  sourceIdx?: number
  rdpDistance?: number
  zoom: number
}

export interface Route {
  points: RoutePoint[]
  dist: number
  ascend: number
  index: KDBush
}

/**
 * What the router is asked: the profile and, for the bicycle ones, the two tuning knobs (0..1).
 * An absent knob means « the profile's value » and is not sent, so the call stays what it was
 * before the knobs existed.
 */
export interface RouterSettings {
  profile: RouterProfile
  /** 0 avoids hills, 1 ignores them. */
  useHills?: number
  /** 0 prefers cycleways and paths, 1 roads. */
  useRoads?: number
}

function definedSettings(settings: RouterSettings): RouterSettings {
  const { profile, useHills, useRoads } = settings
  return {
    profile,
    ...(useHills !== undefined && { useHills }),
    ...(useRoads !== undefined && { useRoads }),
  }
}

let pointIdCounter = 0

/**
 * A loaded track kept whole, beside the simplified route: what the editor gives back when the
 * portion of the file between two of its points is restored, and what the planner state saves.
 */
export interface PlannerSource {
  /** [lng, lat, ele?] of the loaded track, unsimplified. */
  coords: number[][]
  /** Raw cumulative climb (m) per point: the sum of the positive steps between points that have an elevation. */
  cumul: number[]
  /** Factor that scales the raw climb onto the stored D+ of the route (1 without reference). */
  ascendScale: number
  /**
   * `cumul` is the server's dead-band climb of the imported file (and `ascendScale` is 1), not a
   * raw sum: the saved state carries it as `climb`, trimmed to the range in use.
   */
  serverClimb?: boolean
}

/**
 * Cumulative climb of the whole loaded track, computed before any simplification (which drops
 * vertices and their climb). Points without elevation are skipped: they carry the running total.
 */
export function cumulativeClimb(coords: number[][]): number[] {
  const cumul: number[] = new Array(coords.length)
  let total = 0
  let previous: number | undefined
  for (let i = 0; i < coords.length; i++) {
    const ele = coords[i][2]
    if (ele !== undefined && ele !== null) {
      if (previous !== undefined && ele > previous) total += ele - previous
      previous = ele
    }
    cumul[i] = total
  }
  return cumul
}

/** A loaded track as a source; its climb is scaled to the reference D+ of the stored route when known. */
export function sourceOf(coords: number[][], referenceAscend?: number): PlannerSource {
  const cumul = cumulativeClimb(coords)
  const total = cumul.length > 0 ? cumul[cumul.length - 1] : 0
  const ascendScale =
    referenceAscend !== undefined && referenceAscend > 0 && total > 0 ? referenceAscend / total : 1
  return { coords, cumul, ascendScale }
}

/**
 * A track of an imported GPX file (POST /api/router/import-gpx) as a source: its climb is the
 * server's, per point, so the D+ of the route is the file's reported one.
 */
export function sourceFromImport(track: GpxImportTrack): PlannerSource {
  const lngLat = decode2(track.line)
  if (lngLat.length < 2) throw new Error('imported track under two points')
  let coords: number[][] = lngLat
  if (track.ele !== undefined) {
    const ele = decode1(track.ele)
    if (ele.length !== lngLat.length) throw new Error('imported track elevations')
    coords = lngLat.map((c, i) => [c[0], c[1], ele[i]])
  }
  if (track.climb !== undefined && track.ele !== undefined) {
    const cumul = decode1(track.climb)
    if (cumul.length !== coords.length) throw new Error('imported track climb')
    return { coords, cumul, ascendScale: 1, serverClimb: true }
  }
  return sourceOf(coords)
}

/**
 * The route of imported sources, side by side: the points of each carry their provenance (source
 * `firstId + k`, index in it) and the climb of the file; the ends of every track are control points
 * and a track starts from the end of the previous one by a straight line.
 */
export function routeFromSources(sources: PlannerSource[], firstId: number): Route {
  const points: RoutePoint[] = []
  sources.forEach((source, k) => {
    const start = points.length
    source.coords.forEach((c, i) => {
      const p = createPoint(c[0], c[1], c[2], true)
      p.sourceId = firstId + k
      p.sourceIdx = i
      p.importAscend = source.cumul[i] * source.ascendScale
      points.push(p)
    })
    points[start].manual = true
    points[points.length - 1].manual = true
    if (k > 0) points[start].direct = true
  })
  return computeRoute(points)
}

/**
 * Adds imported tracks (`imported`, made by {@link routeFromSources}) at the end of `route`. The
 * last point is joined to the first imported one the way the current mode says: a straight line,
 * or a routed leg (one request) unless the two are under 5 m apart (none). Nothing of the route
 * is touched before the router answered: a failure leaves it intact.
 */
export async function appendImport(
  route: Route,
  imported: Route,
  settings: RouterSettings,
  straight: boolean,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<Route> {
  signal?.throwIfAborted()
  if (route.points.length === 0) return imported
  const last = route.points[route.points.length - 1]
  const first = imported.points[0]
  const leg = await router(last, first, settings, straight, signal, teamSlug)
  const routed = isRouted(last, first, straight)
  last.manual = true
  // The router's own last point stands for the first imported one, which stays where the file has it.
  const interior = leg.points.slice(0, -1)
  if (routed && leg.points.length > 0) {
    last.lng = leg.points[0].lng
    last.lat = leg.points[0].lat
    last.ele ??= leg.points[0].ele
  }
  first.direct = straight
  first.legAscend = leg.ascend ?? (straight ? undefined : 0)
  first.manual = true
  const points = [...route.points, ...interior, ...imported.points]
  return computeRoute(points, { start: last, end: first })
}

// The only place where points become `imported` from a file or an existing route (restoring a saved
// planner state and giving a source span back do too). The re-fit of a track onto the road network
// (B2, D1) will go through createPoints(…, true) as well.
export function createRoute(coords: number[][], referenceAscend?: number, sourceId = 0): Route {
  const points = createPoints(coords, true)
  const source = sourceOf(coords, referenceAscend)
  points.forEach((p, i) => {
    p.sourceId = sourceId
    p.sourceIdx = i
    p.importAscend = source.cumul[i] * source.ascendScale
  })
  return computeRoute(points)
}

/** A gesture refused before any request: the route is left as it was; `messageKey` is shown. */
export class PlannerRefusedError extends Error {
  constructor(readonly messageKey: TranslationKey) {
    super(messageKey)
  }
}

const CUT_NEEDS_ZOOM_KEY = tRegister('planner.error.cutNeedsZoom')

/** The anchors enclosing a gesture; undefined where the route has nothing on that side. */
export interface Bounds {
  start?: RoutePoint
  end?: RoutePoint
}

function findBounds(
  route: Route,
  before: number,
  after: number,
  isBound: (p: RoutePoint) => boolean
): Bounds {
  const points = route.points
  const last = points.length - 1
  let start: RoutePoint | undefined
  if (before >= 0 && last >= 0) {
    start = points[0]
    for (let i = Math.min(before, last); i >= 0; i--) {
      if (isBound(points[i])) {
        start = points[i]
        break
      }
    }
  }
  let end: RoutePoint | undefined
  if (after <= last && last >= 0) {
    end = points[last]
    for (let i = Math.max(after, 0); i <= last; i++) {
      if (isBound(points[i])) {
        end = points[i]
        break
      }
    }
  }
  return { start, end }
}

/**
 * Leg bounds: the first point that is manual or imported, searched backward from `before` and
 * forward from `after` (both inclusive). Zoom-independent.
 */
export function legBounds(route: Route, before: number, after: number): Bounds {
  return findBounds(route, before, after, (p) => p.manual || p.imported)
}

/**
 * Span bounds: the first point that is manual, or imported and visible at `zoom`
 * (`p.zoom <= zoom`, as the layer filter), searched the same way. Routed points never bound a span.
 */
export function spanBounds(route: Route, before: number, after: number, zoom: number): Bounds {
  return findBounds(route, before, after, (p) => p.manual || (p.imported && p.zoom <= zoom))
}

const NEAREST_VERTICES = 6

/** The route segment nearest to `p`: its start index and the projection of `p` on it. */
export function nearestSegment(route: Route, p: Point): { index: number; point: Point } | null {
  const points = route.points
  if (points.length < 2) return null
  // The nearest vertex is not always on the nearest segment (a long straight leg, a route coming
  // back near itself): test the segments next to several close vertices.
  const nearest = around(route.index, p.lng, p.lat, NEAREST_VERTICES)
  if (nearest.length === 0) return null
  const tried = new Set<number>()
  let best: { index: number; point: Point; distance: number } | null = null
  for (const k of nearest) {
    for (const index of [k - 1, k]) {
      if (tried.has(index) || index < 0 || index + 1 >= points.length) continue
      tried.add(index)
      const projection = projectOnSegment(points[index], points[index + 1], p)
      if (!best || projection.distance < best.distance) best = { index, ...projection }
    }
  }
  return best && { index: best.index, point: best.point }
}

function getDist(points: RoutePoint[]): number {
  let dist = 0
  for (let i = 1; i < points.length; i++) {
    const p1 = points[i - 1]
    const p2 = points[i]
    dist = dist + distance(p1.lng, p1.lat, p2.lng, p2.lat)
  }
  return dist
}

/**
 * Elevation of every point, the missing ones filled by linear interpolation along the distance
 * between the neighbours that have one (the nearest known one at the ends). All undefined when no
 * point has an elevation.
 */
export function fillElevations(points: RoutePoint[]): (number | undefined)[] {
  const n = points.length
  const cum = cumulativeDistances(points)
  const known: number[] = []
  for (let i = 0; i < n; i++) if (typeof points[i].ele === 'number') known.push(i)
  if (known.length === 0) return points.map(() => undefined)
  const result: (number | undefined)[] = new Array(n)
  let k = 0
  for (let i = 0; i < n; i++) {
    const ele = points[i].ele
    if (typeof ele === 'number') {
      result[i] = ele
      continue
    }
    while (k + 1 < known.length && known[k + 1] < i) k++
    const prev = known[k] < i ? known[k] : undefined
    const next = known.find((j) => j > i)
    if (prev === undefined) result[i] = points[next!].ele
    else if (next === undefined) result[i] = points[prev].ele
    else {
      const span = cum[next] - cum[prev]
      const t = span > 0 ? (cum[i] - cum[prev]) / span : 0
      result[i] = points[prev].ele! + t * (points[next].ele! - points[prev].ele!)
    }
  }
  return result
}

function cumulativeDistances(points: RoutePoint[]): number[] {
  const cum: number[] = new Array(points.length)
  let dist = 0
  for (let i = 0; i < points.length; i++) {
    if (i > 0) {
      const p1 = points[i - 1]
      const p2 = points[i]
      dist += distance(p1.lng, p1.lat, p2.lng, p2.lat)
    }
    cum[i] = dist
  }
  return cum
}

/** What an edge of a route is made of. */
export type EdgeMode = 'DIRECT' | 'ROUTED' | 'IMPORTED'

/**
 * What the edge `points[i-1] -> points[i]` is. Exported for the planner state and the D+.
 *
 * <p>Relies on an invariant of the planner: a point carrying `legAscend` ends a routed leg (`add`,
 * `insert` and `remove` write it after the router answered; a hop under 5 m writes 0), and an
 * imported point never carries one otherwise. Without that condition, a routed leg whose interior
 * Douglas-Peucker dropped entirely, between two imported points, would be taken for the portion of
 * the file it replaced.
 */
export function edgeMode(points: RoutePoint[], i: number): EdgeMode {
  const p = points[i]
  const q = points[i - 1]
  if (p.direct) return 'DIRECT'
  if (p.legAscend !== undefined) return 'ROUTED' // closes a routed leg (or a hop: legAscend 0)
  if (
    q &&
    p.imported &&
    q.imported &&
    p.sourceId !== undefined &&
    p.sourceId === q.sourceId &&
    p.sourceIdx !== undefined &&
    q.sourceIdx !== undefined &&
    p.sourceIdx > q.sourceIdx
  ) {
    return 'IMPORTED'
  }
  return 'ROUTED'
}

/**
 * D+ of a route, edge by edge (the first point never counts). The arrival point of an edge says
 * where its climb comes from: a straight line is the net climb between its filled elevations; a
 * routed leg is the router's own figure, counted once at its end; two consecutive points of a
 * loaded track are the difference of their cumulative climb. The interior of a routed leg counts 0.
 */
export function routeAscend(points: RoutePoint[]): number {
  const eleF = fillElevations(points)
  let ascend = 0
  for (let i = 1; i < points.length; i++) {
    const p = points[i]
    const q = points[i - 1]
    const mode = edgeMode(points, i)
    if (mode === 'DIRECT') {
      const a = eleF[i]
      const b = eleF[i - 1]
      if (a !== undefined && b !== undefined) ascend += Math.max(0, a - b)
    } else if (mode === 'ROUTED') {
      ascend += p.legAscend ?? 0
    } else if (p.importAscend !== undefined && q.importAscend !== undefined) {
      ascend += Math.max(0, p.importAscend - q.importAscend)
    }
  }
  return ascend
}

/** The elevation profile of a route being drawn, in the shape ElevationChart reads; indexes match `route.points`. */
export function plannerRouteToMappable(route: Route): MappableRoute | null {
  const points = route.points
  if (points.length < 2) return null
  const eleF = fillElevations(points)
  if (eleF.every((e) => e === undefined)) return null
  const cum = cumulativeDistances(points)
  return {
    distance: route.dist,
    waypoints: [],
    tracks: [
      {
        line: {
          type: 'LineString',
          coordinates: points.map((p, i) => [p.lng, p.lat, eleF[i] as number, cum[i]]),
        },
        climbs: [],
      },
    ],
  } as MappableRoute
}

const EARTH_RADIUS = 6371008.8
const MIN_ANCHOR_ZOOM = 0
const MAX_ANCHOR_ZOOM = 22

function getZoomLevelForDistance(lat: number, dist?: number): number {
  if (dist === undefined || dist <= 0) return MIN_ANCHOR_ZOOM
  const rad = (lat * Math.PI) / 180
  return Math.min(
    MAX_ANCHOR_ZOOM,
    Math.max(MIN_ANCHOR_ZOOM, Math.round(Math.log2((EARTH_RADIUS * Math.cos(rad)) / dist)))
  )
}

export function createPoint(
  lng: number,
  lat: number,
  ele?: number,
  imported = false,
  direct = false
): RoutePoint {
  return {
    id: `p-${++pointIdCounter}`,
    idx: 0,
    lng,
    lat,
    ele,
    manual: false,
    imported,
    direct,
    zoom: 0,
  }
}

function createPoints(coords: number[][], imported = false): RoutePoint[] {
  return coords.map((coord) => createPoint(coord[0], coord[1], coord[2], imported))
}

/**
 * Simplifies `input` into a route. With `changed`, only the span between the two bounds is
 * simplified again (they are objects of `input`, found by identity): everything outside keeps its
 * points and its zoom levels, so a gesture does not reshuffle the anchors far from it.
 */
export function computeRoute(input: RoutePoint[], changed?: Bounds): Route {
  let points: RoutePoint[]
  if (!changed || input.length < 2) {
    points = ramerDouglasPeucker(input, 5)
    points.forEach((p) => {
      p.zoom = p.manual ? MIN_ANCHOR_ZOOM : getZoomLevelForDistance(p.lat, p.rdpDistance)
    })
  } else {
    const s = changed.start ? input.indexOf(changed.start) : 0
    const e = changed.end ? input.indexOf(changed.end) : input.length - 1
    if (s < 0 || e < 0) throw new Error('planner: bound not in route')
    if (e <= s) {
      points = [...input]
    } else {
      // The recursion is called directly: ramerDouglasPeucker would make the bounds manual, and an
      // imported anchor used as a bound would become a marker.
      const middle: RoutePoint[] = []
      ramerDouglasPeuckerRecursive(input, middle, 5, s, e)
      points = [...input.slice(0, s + 1), ...middle, ...input.slice(e)]
      for (const p of middle) p.zoom = getZoomLevelForDistance(p.lat, p.rdpDistance)
    }
    points[0].manual = true
    points[points.length - 1].manual = true
    // Other points, the bounds included, keep their zoom: only a manual one is always visible
    for (const p of points) if (p.manual) p.zoom = MIN_ANCHOR_ZOOM
  }
  return finishRoute(points)
}

/** Indexes the points and measures the route: the end of every computation of a route. */
function finishRoute(points: RoutePoint[]): Route {
  points.forEach((p, idx) => {
    p.idx = idx
  })
  if (points.length) points[0].direct = false
  const index = new KDBush(points.length)
  for (const { lng, lat } of points) index.add(lng, lat)
  return {
    points,
    dist: getDist(points),
    ascend: routeAscend(points),
    index: index.finish(),
  }
}

/**
 * A route from points already cut into pieces (a saved planner state): `junctions` are the indices,
 * ascending, of the points that bound the pieces: the first and the last of `input` among them.
 * Each piece is simplified on its own and the junctions are always kept, visible at every zoom (a
 * control point, or a join which is a handle that means something). Nothing is requested.
 */
export function computeRouteFromPieces(input: RoutePoint[], junctions: number[]): Route {
  const points: RoutePoint[] = []
  for (let k = 0; k < junctions.length; k++) {
    const a = junctions[k]
    points.push(input[a])
    input[a].zoom = MIN_ANCHOR_ZOOM
    const b = junctions[k + 1]
    if (b === undefined) break
    const middle: RoutePoint[] = []
    ramerDouglasPeuckerRecursive(input, middle, 5, a, b)
    for (const p of middle) p.zoom = getZoomLevelForDistance(p.lat, p.rdpDistance)
    points.push(...middle)
  }
  return finishRoute(points)
}

// add points between route end and p. `teamSlug` names the team the route is drawn for: the backend
// checks that team's planner flag and the caller's right to create routes there (absent: GPX tools).
export async function add(
  route: Route,
  p: Point,
  settings: RouterSettings,
  direct = false,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<Route> {
  signal?.throwIfAborted()
  if (route.points.length === 0) {
    const point = createPoint(p.lng, p.lat)
    point.manual = true
    return computeRoute([point])
  }

  const last = route.points[route.points.length - 1]

  const leg = await router(last, p, settings, direct, signal, teamSlug)
  const segment = leg.points
  // Nothing of the route is touched before the router answered: an abandoned call leaves it intact.
  last.manual = true
  if (segment.length > 0) {
    // Written after the await, on the point that stays (the router's last one)
    segment[segment.length - 1].direct = direct
    segment[segment.length - 1].legAscend = leg.ascend
    // Snap the previous control point to the route start (nearest road). Only a routed leg moves
    // it: a straight line returns just its target, which is not where the leg starts.
    if (isRouted(last, p, direct)) {
      last.lng = segment[0].lng
      last.lat = segment[0].lat
      // The first point of a route is created without elevation: it takes the road's
      last.ele ??= segment[0].ele
    }
    route.points.push(...segment)
  }
  route.points[route.points.length - 1].manual = true

  return computeRoute(route.points, { start: last })
}

// keep route up to startPoint, compute points between startPoint and p, compute points between p and endPoint, keep route after endPoint
export async function insert(
  route: Route,
  startPoint: RoutePoint | undefined,
  p: Point,
  endPoint: RoutePoint | undefined,
  settings: RouterSettings,
  direct = false,
  signal?: AbortSignal,
  teamSlug?: string,
  keepId?: string
): Promise<Route> {
  signal?.throwIfAborted()
  // Bounds are found by id: `idx` is renumbered by every computation, and the bounds may have been
  // frozen when a menu opened.
  const startIdx = startPoint ? indexOfPoint(route, startPoint) : -1
  const endIdx = endPoint ? indexOfPoint(route, endPoint) : route.points.length

  // Keep points up to and including start
  const before = route.points.slice(0, startIdx + 1)

  // Route segments (parallel if both needed)
  const emptyLeg: Leg = { points: [] }
  const [toP, toEnd] = await Promise.all([
    startPoint ? router(startPoint, p, settings, direct, signal, teamSlug) : emptyLeg,
    endPoint ? router(p, endPoint, settings, direct, signal, teamSlug) : emptyLeg,
  ])
  const segmentToP = toP.points
  const segmentToEnd = toEnd.points

  // Snap the manual point to the nearest road using segment endpoints
  const snappedP =
    segmentToP.length > 0
      ? segmentToP[segmentToP.length - 1]
      : segmentToEnd.length > 0
        ? segmentToEnd[0]
        : null
  const manualPoint = createPoint(snappedP?.lng ?? p.lng, snappedP?.lat ?? p.lat)
  // A move keeps the id of the point it replaces (a real insertion never passes one): the marker is
  // not remounted, so it keeps the focus and its place in the tab order. The old point lies
  // strictly between the bounds, hence is dropped below: no two points share the id.
  if (keepId) manualPoint.id = keepId
  manualPoint.manual = true
  manualPoint.direct = startPoint ? direct : false
  // The inserted point sits on the road: it takes its elevation, and closes the leg that reached it
  manualPoint.ele = snappedP?.ele
  manualPoint.legAscend = startPoint && segmentToP.length > 0 ? toP.ascend : undefined

  // Snap boundary points to route endpoints
  if (before.length > 0 && segmentToP.length > 0 && isRouted(startPoint!, p, direct)) {
    const lastBefore = before[before.length - 1]
    lastBefore.lng = segmentToP[0].lng
    lastBefore.lat = segmentToP[0].lat
    lastBefore.ele ??= segmentToP[0].ele
  }

  // Keep points after and including end
  const after = route.points.slice(endIdx)

  // The mode of the gesture wins over what the leg was (no inheritance). A point carrying `direct`
  // is manual or a bound (manualPoint, after[0]): it never enters the simplified middle, and the
  // duplicates the router leaves next to them, which Douglas-Peucker drops, carry nothing.
  if (endPoint && after.length > 0) {
    after[0].direct = direct
    after[0].legAscend = toEnd.ascend
  }

  if (after.length > 0 && segmentToEnd.length > 0 && isRouted(p, endPoint!, direct)) {
    const firstAfter = after[0]
    firstAfter.lng = segmentToEnd[segmentToEnd.length - 1].lng
    firstAfter.lat = segmentToEnd[segmentToEnd.length - 1].lat
  }

  // Build new points array
  const points = [...before, ...segmentToP, manualPoint, ...segmentToEnd, ...after]
  return computeRoute(points, { start: before.at(-1), end: after[0] })
}

function indexOfPoint(route: Route, point: RoutePoint): number {
  const i = route.points.findIndex((pt) => pt.id === point.id)
  if (i < 0) throw new Error('planner: bound not in route')
  return i
}

// keep route up to startPoint, compute points between startPoint and endPoint, keep route after endPoint
export async function remove(
  route: Route,
  startPoint: RoutePoint | undefined,
  endPoint: RoutePoint | undefined,
  settings: RouterSettings,
  direct = false,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<Route> {
  signal?.throwIfAborted()
  const startIdx = startPoint ? indexOfPoint(route, startPoint) : -1
  const endIdx = endPoint ? indexOfPoint(route, endPoint) : -1

  // Removing first point: just keep from endPoint onwards
  if (!startPoint && endPoint) {
    const kept = route.points.slice(endIdx)
    // A loaded track must not collapse to a stub because no anchor was visible at this zoom
    if (kept.length < 2 && route.points.slice(0, endIdx).some((p) => p.imported)) {
      throw new PlannerRefusedError(CUT_NEEDS_ZOOM_KEY)
    }
    return computeRoute(kept, { start: kept[0], end: kept[0] })
  }

  // Removing last point: just keep up to startPoint
  if (startPoint && !endPoint) {
    const kept = route.points.slice(0, startIdx + 1)
    if (kept.length < 2 && route.points.slice(startIdx + 1).some((p) => p.imported)) {
      throw new PlannerRefusedError(CUT_NEEDS_ZOOM_KEY)
    }
    return computeRoute(kept, { start: kept.at(-1), end: kept.at(-1) })
  }

  // Both undefined: clear route
  if (!startPoint && !endPoint) {
    return computeRoute([])
  }

  // Normal case: reroute around removed point. The request goes out before the array is cut.
  // The reconnection is straight when asked, or when no routed leg is lost (the replaced legs are
  // all straight); if the router fails the route is left intact.
  const straight = direct || isStraightSpan(route, startIdx, endIdx)
  const leg = await router(
    route.points[startIdx],
    route.points[endIdx],
    settings,
    straight,
    signal,
    teamSlug
  )
  const segment = leg.points
  const before = route.points.slice(0, startIdx + 1)
  const after = route.points.slice(endIdx)
  // Written after the await. A bound (manual or imported) never enters the simplified middle, so
  // the flag survives the simplification; the router's own duplicate of it is dropped.
  after[0].direct = straight
  // Neither routed nor straight (a hop between bounds a few metres apart): no climb, and not the
  // imported fallback either, which would credit the span that was just removed
  after[0].legAscend = leg.ascend ?? (straight ? undefined : 0)

  return computeRoute([...before, ...segment, ...after], { start: before.at(-1), end: after[0] })
}

/**
 * Gives back the source track between two imported bounds of the same import: no request. What lies
 * strictly between `start` and `end` is replaced by `source.coords[start.sourceIdx + 1 ..
 * end.sourceIdx - 1]`, and the edge into `end` is the file's again. The bounds do not move (one
 * snapped on the road network by a routing stays where it is: a few metres from the source point).
 */
export function restoreSourceSpan(
  route: Route,
  start: RoutePoint,
  end: RoutePoint,
  source: PlannerSource
): Route {
  const startIdx = indexOfPoint(route, start)
  const endIdx = indexOfPoint(route, end)
  const from = start.sourceIdx!
  const to = end.sourceIdx!
  const given: RoutePoint[] = []
  for (let i = from + 1; i < to; i++) {
    const c = source.coords[i]
    const p = createPoint(c[0], c[1], c[2], true)
    p.sourceId = start.sourceId
    p.sourceIdx = i
    p.importAscend = source.cumul[i] * source.ascendScale
    given.push(p)
  }
  const target = route.points[endIdx]
  target.direct = false
  target.legAscend = undefined
  const points = [...route.points.slice(0, startIdx + 1), ...given, ...route.points.slice(endIdx)]
  return computeRoute(points, { start: route.points[startIdx], end: target })
}

/** Whether every edge of `points[startIdx..endIdx]` is a straight line (false for an empty or inverted range). */
export function isStraightSpan(route: Route, startIdx: number, endIdx: number): boolean {
  if (endIdx <= startIdx) return false
  return route.points.slice(startIdx + 1, endIdx + 1).every((p) => p.direct)
}

export function geojson(route: Route): GeoJSON.LineString {
  return {
    type: 'LineString',
    coordinates: route.points.map((p) => [p.lng, p.lat]),
  }
}

export type LegProperties = { direct: boolean }

/**
 * The route as a FeatureCollection of LineStrings, consecutive edges of the same kind (straight or
 * not) grouped; each feature repeats the shared vertex so the line stays continuous.
 */
export function legsGeojson(
  route: Route
): GeoJSON.FeatureCollection<GeoJSON.LineString, LegProperties> {
  const features: GeoJSON.Feature<GeoJSON.LineString, LegProperties>[] = []
  const points = route.points
  for (let i = 1; i < points.length; i++) {
    const direct = points[i].direct
    const last = features.at(-1)
    if (last && last.properties.direct === direct) {
      last.geometry.coordinates.push([points[i].lng, points[i].lat])
    } else {
      features.push({
        type: 'Feature',
        properties: { direct },
        geometry: {
          type: 'LineString',
          coordinates: [
            [points[i - 1].lng, points[i - 1].lat],
            [points[i].lng, points[i].lat],
          ],
        },
      })
    }
  }
  return { type: 'FeatureCollection', features }
}

/** Above this length, one straight leg is worth a warning at save time. */
export const DIRECT_WARNING_METERS = 300

export interface DirectStats {
  total: number
  longest: number
  count: number
}

export function directStats(route: Route): DirectStats {
  let total = 0
  let longest = 0
  let count = 0
  const points = route.points
  for (let i = 1; i < points.length; i++) {
    if (!points[i].direct) continue
    const d = distance(points[i - 1].lng, points[i - 1].lat, points[i].lng, points[i].lat)
    total += d
    longest = Math.max(longest, d)
    count++
  }
  return { total, longest, count }
}

/** Whether the leg from `from` to `to` goes through the router (a straight line or a hop under 5 m does not). */
function isRouted(from: Point, to: Point, direct: boolean): boolean {
  return !direct && distance(from.lng, from.lat, to.lng, to.lat) >= 5
}

/** A leg answered by the router: its points and its climb (absent for a straight line or a hop). */
interface Leg {
  points: RoutePoint[]
  ascend?: number
}

async function router(
  from: Point,
  to: Point,
  settings: RouterSettings,
  direct: boolean,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<Leg> {
  if (!isRouted(from, to, direct)) {
    return { points: [createPoint(to.lng, to.lat, undefined, false, direct)] }
  }
  // Routing is billed per request: never send one for an operation already abandoned.
  signal?.throwIfAborted()
  // The planner renders the failure itself, by code (plannerErrorMessage): no global toast on top.
  const response = await routerRoute(
    { from, to, ...definedSettings(settings), teamSlug },
    { skipErrorToast: true },
    signal
  )
  const points = createPoints(response.route.coordinates)
  let positive = 0
  for (let i = 1; i < points.length; i++) {
    const a = points[i - 1].ele
    const b = points[i].ele
    if (a !== undefined && b !== undefined && b > a) positive += b - a
  }
  return { points, ascend: response.ascend ?? positive }
}

function ramerDouglasPeucker(points: RoutePoint[], epsilon: number = 50): RoutePoint[] {
  if (points.length === 0) {
    return []
  } else if (points.length == 1) {
    return points
  }

  points[0].manual = true
  const filtered: RoutePoint[] = [points[0]]
  ramerDouglasPeuckerRecursive(points, filtered, epsilon, 0, points.length - 1)
  points[points.length - 1].manual = true
  filtered.push(points[points.length - 1])
  return filtered
}

function ramerDouglasPeuckerRecursive(
  points: RoutePoint[],
  filtered: RoutePoint[],
  epsilon: number,
  start: number,
  end: number
) {
  const largest = {
    index: 0,
    distance: 0,
  }

  for (let i = start + 1; i < end; i++) {
    const p = points[i]
    const distance =
      p.manual || p.legAscend !== undefined ? 100000 : crossarc(points[start], points[end], p)
    if (distance > largest.distance) {
      largest.index = i
      largest.distance = distance
    }
  }

  if (largest.distance > epsilon && largest.index != 0) {
    ramerDouglasPeuckerRecursive(points, filtered, epsilon, start, largest.index)
    const kept = points[largest.index]
    kept.rdpDistance = largest.distance
    filtered.push(kept)
    ramerDouglasPeuckerRecursive(points, filtered, epsilon, largest.index, end)
  }
}

const metersPerLatitudeDegree = 111320

function getMetersPerLongitudeDegree(latitude: number): number {
  return Math.cos((latitude * Math.PI) / 180) * metersPerLatitudeDegree
}

function crossarc(coord1: Point, coord2: Point, coord3: Point): number {
  // Perpendicular distance in meters between the segment [coord1, coord2] and coord3.
  return projectOnSegment(coord1, coord2, coord3).distance
}

/**
 * Projection of p3 onto the segment [p1, p2] and the distance to it, in meters. Uses simple planar
 * geometry (ignores earth curvature).
 */
function projectOnSegment(
  coord1: Point,
  coord2: Point,
  coord3: Point
): { distance: number; point: Point } {
  const metersPerLongitudeDegree = getMetersPerLongitudeDegree(coord1.lat)

  const x1 = coord1.lng * metersPerLongitudeDegree
  const y1 = coord1.lat * metersPerLatitudeDegree
  const x2 = coord2.lng * metersPerLongitudeDegree
  const y2 = coord2.lat * metersPerLatitudeDegree
  const x3 = coord3.lng * metersPerLongitudeDegree
  const y3 = coord3.lat * metersPerLatitudeDegree

  const dx = x2 - x1
  const dy = y2 - y1
  const segmentLengthSquared = dx * dx + dy * dy

  // p1 and p2 are the same point: t = 0
  const t =
    segmentLengthSquared === 0
      ? 0
      : Math.max(0, Math.min(1, ((x3 - x1) * dx + (y3 - y1) * dy) / segmentLengthSquared))

  const projX = x1 + t * dx
  const projY = y1 + t * dy

  return {
    distance: Math.sqrt((x3 - projX) * (x3 - projX) + (y3 - projY) * (y3 - projY)),
    point: {
      lng: coord1.lng + t * (coord2.lng - coord1.lng),
      lat: coord1.lat + t * (coord2.lat - coord1.lat),
    },
  }
}
