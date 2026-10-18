import { distance } from '@/components/map/mapUtils'
import { route as routerRoute } from '@/api/endpoints/router/router'
import KDBush from 'kdbush'
import { around } from 'geokdbush'
import { RouterProfile } from '@/api/dto'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

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
  rdpDistance?: number
  zoom: number
}

export interface Route {
  points: RoutePoint[]
  dist: number
  ascend: number
  index: KDBush
}

let pointIdCounter = 0

// The only place where points become `imported`: a loaded track (initialTrack, imported file).
// The re-fit of a track onto the road network (B2, D1) will go through createPoints(…, true) too.
export function createRoute(coords: number[][]): Route {
  const points = createPoints(coords, true)
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

function getAscend(points: RoutePoint[]): number {
  let ascend = 0
  for (let i = 1; i < points.length; i++) {
    const diff = (points[i].ele ?? 0) - (points[i - 1].ele ?? 0)
    if (diff > 0) ascend += diff
  }
  return ascend
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

function createPoint(lng: number, lat: number, ele?: number, imported = false): RoutePoint {
  return {
    id: `p-${++pointIdCounter}`,
    idx: 0,
    lng,
    lat,
    ele,
    manual: false,
    imported,
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
  points.forEach((p, idx) => {
    p.idx = idx
  })
  const index = new KDBush(points.length)
  for (const { lng, lat } of points) index.add(lng, lat)
  return {
    points,
    dist: getDist(points),
    ascend: getAscend(points),
    index: index.finish(),
  }
}

// add points between route end and p. `teamSlug` names the team the route is drawn for: the backend
// checks that team's planner flag and the caller's right to create routes there (absent: GPX tools).
export async function add(
  route: Route,
  p: Point,
  profile: RouterProfile,
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

  const segment = await router(last, p, profile, direct, signal, teamSlug)
  // Nothing of the route is touched before the router answered: an abandoned call leaves it intact.
  last.manual = true
  if (segment.length > 0) {
    // Snap the previous control point to the route start (nearest road). Only a routed leg moves
    // it: a straight line returns just its target, which is not where the leg starts.
    if (isRouted(last, p, direct)) {
      last.lng = segment[0].lng
      last.lat = segment[0].lat
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
  profile: RouterProfile,
  direct = false,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<Route> {
  signal?.throwIfAborted()
  // Bounds are found by id: `idx` is renumbered by every computation, and the bounds may have been
  // frozen when a menu opened.
  const startIdx = startPoint ? indexOfPoint(route, startPoint) : -1
  const endIdx = endPoint ? indexOfPoint(route, endPoint) : route.points.length

  // Keep points up to and including start
  const before = route.points.slice(0, startIdx + 1)

  // Route segments (parallel if both needed)
  const [segmentToP, segmentToEnd] = await Promise.all([
    startPoint ? router(startPoint, p, profile, direct, signal, teamSlug) : Promise.resolve([]),
    endPoint ? router(p, endPoint, profile, direct, signal, teamSlug) : Promise.resolve([]),
  ])

  // Snap the manual point to the nearest road using segment endpoints
  const snappedP =
    segmentToP.length > 0
      ? segmentToP[segmentToP.length - 1]
      : segmentToEnd.length > 0
        ? segmentToEnd[0]
        : null
  const manualPoint = createPoint(snappedP?.lng ?? p.lng, snappedP?.lat ?? p.lat)
  manualPoint.manual = true

  // Snap boundary points to route endpoints
  if (before.length > 0 && segmentToP.length > 0 && isRouted(startPoint!, p, direct)) {
    const lastBefore = before[before.length - 1]
    lastBefore.lng = segmentToP[0].lng
    lastBefore.lat = segmentToP[0].lat
  }

  // Keep points after and including end
  const after = route.points.slice(endIdx)

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
  profile: RouterProfile,
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
  const segment = await router(
    route.points[startIdx],
    route.points[endIdx],
    profile,
    direct,
    signal,
    teamSlug
  )
  const before = route.points.slice(0, startIdx + 1)
  const after = route.points.slice(endIdx)

  return computeRoute([...before, ...segment, ...after], { start: before.at(-1), end: after[0] })
}

export function geojson(route: Route): GeoJSON.LineString {
  return {
    type: 'LineString',
    coordinates: route.points.map((p) => [p.lng, p.lat]),
  }
}

/** Whether the leg from `from` to `to` goes through the router (a straight line or a hop under 5 m does not). */
function isRouted(from: Point, to: Point, direct: boolean): boolean {
  return !direct && distance(from.lng, from.lat, to.lng, to.lat) >= 5
}

async function router(
  from: Point,
  to: Point,
  profile: RouterProfile,
  direct: boolean,
  signal?: AbortSignal,
  teamSlug?: string
): Promise<RoutePoint[]> {
  if (!isRouted(from, to, direct)) {
    return [createPoint(to.lng, to.lat)]
  }
  // Routing is billed per request: never send one for an operation already abandoned.
  signal?.throwIfAborted()
  // The planner renders the failure itself, by code (plannerErrorMessage): no global toast on top.
  const response = await routerRoute(
    { from, to, profile, teamSlug },
    { skipErrorToast: true },
    signal
  )
  return createPoints(response.route.coordinates)
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
    const distance = p.manual ? 100000 : crossarc(points[start], points[end], p)
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
