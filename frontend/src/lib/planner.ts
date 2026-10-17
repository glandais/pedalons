import { distance } from '@/components/map/mapUtils'
import { route as routerRoute } from '@/api/endpoints/router/router'
import KDBush from 'kdbush'
import { RouterProfile } from '@/api/dto'

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

export function createRoute(coords: number[][]): Route {
  const points = createPoints(coords)
  return computeRoute(points)
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

function createPoint(lng: number, lat: number, ele?: number): RoutePoint {
  return {
    id: `p-${++pointIdCounter}`,
    idx: 0,
    lng,
    lat,
    ele,
    manual: false,
    zoom: 0,
  }
}

function createPoints(coords: number[][]): RoutePoint[] {
  return coords.map((coord) => createPoint(coord[0], coord[1], coord[2]))
}

export function computeRoute(input: RoutePoint[]): Route {
  const points = ramerDouglasPeucker(input, 5)
  points.forEach((p, idx) => {
    p.idx = idx
    p.zoom = p.manual ? MIN_ANCHOR_ZOOM : getZoomLevelForDistance(p.lat, p.rdpDistance)
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

  return computeRoute(route.points)
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
  const startIdx = startPoint ? route.points.findIndex((pt) => pt.idx === startPoint.idx) : -1
  const endIdx = endPoint
    ? route.points.findIndex((pt) => pt.idx === endPoint.idx)
    : route.points.length

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
  route.points = [...before, ...segmentToP, ...[manualPoint], ...segmentToEnd, ...after]
  return computeRoute(route.points)
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
  // Removing first point: just keep from endPoint onwards
  if (!startPoint && endPoint) {
    const endIdx = route.points.findIndex((pt) => pt.idx === endPoint.idx)
    route.points = route.points.slice(endIdx)
    return computeRoute(route.points)
  }

  // Removing last point: just keep up to startPoint
  if (startPoint && !endPoint) {
    const startIdx = route.points.findIndex((pt) => pt.idx === startPoint.idx)
    route.points = route.points.slice(0, startIdx + 1)
    return computeRoute(route.points)
  }

  // Both undefined: clear route
  if (!startPoint && !endPoint) {
    return computeRoute([])
  }

  // Normal case: reroute around removed point
  const startIdx = route.points.findIndex((pt) => pt.idx === startPoint!.idx)
  const endIdx = route.points.findIndex((pt) => pt.idx === endPoint!.idx)

  const before = route.points.slice(0, startIdx + 1)
  const segment = await router(startPoint!, endPoint!, profile, direct, signal, teamSlug)
  const after = route.points.slice(endIdx)

  return computeRoute([...before, ...segment, ...after])
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

function crossarc(coord1: RoutePoint, coord2: RoutePoint, coord3: RoutePoint): number {
  // Calculates the perpendicular distance in meters
  // between a line segment (defined by p1 and p2) and a third point, p3.
  // Uses simple planar geometry (ignores earth curvature).

  // Convert to meters using approximate scaling
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

  if (segmentLengthSquared === 0) {
    // p1 and p2 are the same point
    return Math.sqrt((x3 - x1) * (x3 - x1) + (y3 - y1) * (y3 - y1))
  }

  // Project p3 onto the line defined by p1-p2
  const t = Math.max(0, Math.min(1, ((x3 - x1) * dx + (y3 - y1) * dy) / segmentLengthSquared))

  // Find the closest point on the segment
  const projX = x1 + t * dx
  const projY = y1 + t * dy

  // Return distance from p3 to the projected point
  return Math.sqrt((x3 - projX) * (x3 - projX) + (y3 - projY) * (y3 - projY))
}
