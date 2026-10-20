import type { WaypointDto, WaypointRequest, WaypointType } from '@/api/dto'
import { WaypointOrigin } from '@/api/dto'
import { distance as haversine } from '@/components/map/mapUtils'
import { cumulativeDistances, nearestSegment, type Point, type Route } from '@/lib/planner'
import { waypointTypeOf } from '@/lib/waypoints'

/**
 * The route points of the editor (ledger WEB-100, C3e): the model the planner keeps beside its
 * route, and the local twin of the server's anchoring (WaypointAnchoring.java, research §11.3). The
 * server has the last word at save time; this only keeps what the editor shows consistent with it.
 */

/** WaypointAnchoring.SNAP_RADIUS_M: how far from the track a point still counts as on it. */
export const WAYPOINT_SNAP_RADIUS_M = 50
/** WaypointAnchoring.PASSAGE_GAP_M: two candidates closer than this along the track are one passage. */
export const WAYPOINT_PASSAGE_GAP_M = 100
/** GpxLimits: the most route points one route or file carries. */
export const MAX_WAYPOINTS = 500
/** The editor's bound on a name (the API accepts what an import brings, up to 250). */
export const WAYPOINT_NAME_MAX = 40
export const WAYPOINT_DESCRIPTION_MAX = 500

const EARTH_RADIUS_M = 6_371_008.8
const M_PER_DEGREE = (Math.PI / 180) * EARTH_RADIUS_M
const MIN_SEGMENT_SQ = 1e-6

/** What picks the passage of a route that goes by twice: where the point stood, on which length. */
export interface WaypointHint {
  distance: number
  /** Length of the route where `distance` was measured: the target is rescaled onto the new one. */
  total?: number
}

export interface PlannerWaypoint {
  /** Stable local identifier: React key, history, form. */
  key: string
  /** TSID of the server; absent for a new point and for one that comes from an imported file. */
  id?: string
  origin: WaypointOrigin
  type: WaypointType
  name: string
  /** Empty for none. */
  description: string
  /** The position the author wants (the point's geometry): never recomputed. */
  lng: number
  lat: number
  hint?: WaypointHint
}

/** A point and where it sits on the current route; null distance: off the track (> 50 m). */
export interface PlacedWaypoint extends PlannerWaypoint {
  distance: number | null
}

/** A place on the route line: the projection and the distance along the route to it. */
export interface WaypointPlacement {
  lng: number
  lat: number
  distance: number
}

let keyCounter = 0
export function nextWaypointKey(): string {
  keyCounter += 1
  return `w-${keyCounter}`
}

interface Candidate {
  along: number
  perp: number
}

/**
 * Where along the route `p` sits, or null when the route passes farther than 50 m. Port of
 * `WaypointAnchoring.locate`: candidates are the edges within the radius, grouped in passages and
 * chosen by the hint, else the first.
 */
export function locateOnRoute(
  route: Route,
  cum: readonly number[],
  p: Point,
  hint?: WaypointHint
): number | null {
  const points = route.points
  if (points.length < 2) return null
  const cos = Math.cos((p.lat * Math.PI) / 180)
  const marginLat = (WAYPOINT_SNAP_RADIUS_M * 1.1) / M_PER_DEGREE
  const marginLng = cos < 1e-9 ? 360 : marginLat / cos
  const minLat = p.lat - marginLat
  const maxLat = p.lat + marginLat
  const minLng = p.lng - marginLng
  const maxLng = p.lng + marginLng
  const candidates: Candidate[] = []
  for (let i = 0; i + 1 < points.length; i++) {
    const a = points[i]
    const b = points[i + 1]
    if (
      (a.lat < minLat && b.lat < minLat) ||
      (a.lat > maxLat && b.lat > maxLat) ||
      (a.lng < minLng && b.lng < minLng) ||
      (a.lng > maxLng && b.lng > maxLng)
    ) {
      continue
    }
    const ax = (a.lng - p.lng) * cos * M_PER_DEGREE
    const ay = (a.lat - p.lat) * M_PER_DEGREE
    const bx = (b.lng - p.lng) * cos * M_PER_DEGREE
    const by = (b.lat - p.lat) * M_PER_DEGREE
    const dx = bx - ax
    const dy = by - ay
    const lengthSq = dx * dx + dy * dy
    let t = 0
    if (lengthSq >= MIN_SEGMENT_SQ) t = Math.max(0, Math.min(1, -(ax * dx + ay * dy) / lengthSq))
    const px = ax + t * dx
    const py = ay + t * dy
    const perp = Math.sqrt(px * px + py * py)
    if (perp > WAYPOINT_SNAP_RADIUS_M) continue
    candidates.push({ along: cum[i] + t * (cum[i + 1] - cum[i]), perp })
  }
  if (candidates.length === 0) return null
  candidates.sort((x, y) => x.along - y.along)

  // Passages: runs of candidates less than a gap apart, the closest of each run
  const passages: Candidate[] = []
  let best = candidates[0]
  let last = best.along
  for (let i = 1; i < candidates.length; i++) {
    const next = candidates[i]
    if (next.along - last >= WAYPOINT_PASSAGE_GAP_M) {
      passages.push(best)
      best = next
    } else if (next.perp < best.perp) {
      best = next
    }
    last = next.along
  }
  passages.push(best)

  let chosen = passages[0]
  if (hint) {
    const total = cum[cum.length - 1]
    const target =
      hint.total && hint.total > 0 ? (hint.distance * total) / hint.total : hint.distance
    let bestGap = Math.abs(chosen.along - target)
    for (const passage of passages) {
      const gap = Math.abs(passage.along - target)
      if (gap < bestGap || (gap === bestGap && passage.perp < chosen.perp)) {
        chosen = passage
        bestGap = gap
      }
    }
  }
  return chosen.along
}

/**
 * The point of the route line nearest to `p`, and its distance along the route. Used by the
 * gestures on the line: the segment is known, so there is no passage to choose.
 */
export function projectOnRoute(
  route: Route,
  cum: readonly number[],
  p: Point
): WaypointPlacement | null {
  const segment = nearestSegment(route, p)
  if (!segment) return null
  const start = route.points[segment.index]
  return {
    lng: segment.point.lng,
    lat: segment.point.lat,
    distance:
      cum[segment.index] + haversine(start.lng, start.lat, segment.point.lng, segment.point.lat),
  }
}

/** The points placed on the route, in the order of the list. O(points x route). */
export function placeWaypoints(
  route: Route,
  waypoints: readonly PlannerWaypoint[]
): PlacedWaypoint[] {
  if (waypoints.length === 0) return []
  const cum = cumulativeDistances(route.points)
  return waypoints.map((w) => ({
    ...w,
    distance: locateOnRoute(route, cum, w, w.hint),
  }))
}

/** A point of a saved route or preview; `total` is the stored length its distance was measured on. */
export function waypointFromDto(dto: WaypointDto, total?: number): PlannerWaypoint {
  return {
    key: nextWaypointKey(),
    id: dto.id,
    origin: dto.origin,
    type: waypointTypeOf(dto.type),
    name: dto.name ?? '',
    description: dto.description ?? '',
    lng: dto.geometry.coordinates[0],
    lat: dto.geometry.coordinates[1],
    hint: dto.distance != null ? { distance: dto.distance, total } : undefined,
  }
}

/** A point of an imported file: no id, no hint (the server takes the first passage). */
export function waypointFromImport(dto: WaypointDto): PlannerWaypoint {
  return {
    key: nextWaypointKey(),
    origin: WaypointOrigin.IMPORTED,
    type: waypointTypeOf(dto.type),
    name: dto.name ?? '',
    description: dto.description ?? '',
    lng: dto.geometry.coordinates[0],
    lat: dto.geometry.coordinates[1],
  }
}

/**
 * The list after an import. `replace`: the server's rule, a new file replaces the imported points
 * and keeps the author's; `append` keeps everything. Capped at {@link MAX_WAYPOINTS}.
 */
export function mergeImported(
  current: PlannerWaypoint[],
  imported: readonly PlannerWaypoint[],
  mode: 'replace' | 'append'
): { waypoints: PlannerWaypoint[]; dropped: number } {
  const kept = mode === 'replace' ? current.filter((w) => w.origin !== 'IMPORTED') : [...current]
  const room = Math.max(0, MAX_WAYPOINTS - kept.length)
  const added = imported.slice(0, room)
  const dropped = imported.length - added.length
  // Nothing changed: the same list, so that the editor does not take it for touched
  if (added.length === 0 && kept.length === current.length) return { waypoints: current, dropped }
  return { waypoints: [...kept, ...added], dropped }
}

/** The list the API takes (RouteRequest.waypoints and its twins). */
export function toWaypointRequests(placed: readonly PlacedWaypoint[]): WaypointRequest[] {
  return placed.map((w) => ({
    id: w.id,
    position: { lng: w.lng, lat: w.lat },
    type: w.type,
    name: w.name.trim(),
    description: w.description.trim().slice(0, WAYPOINT_DESCRIPTION_MAX) || undefined,
    distance: w.distance ?? undefined,
    // Ignored by the server for a point that exists, which keeps its own
    origin: w.id ? undefined : w.origin,
  }))
}

/** The point as the read-only components (profile, details) take it. */
export function toWaypointDto(w: PlacedWaypoint): WaypointDto {
  return {
    geometry: { type: 'Point', coordinates: [w.lng, w.lat] },
    name: w.name,
    id: w.id,
    type: w.type,
    description: w.description || undefined,
    distance: w.distance ?? undefined,
    origin: w.origin,
  }
}
