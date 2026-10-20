import type { WaypointDto, WaypointType } from '@/api/dto'

/** A waypoint picked on the map, on the profile or in the list, and where the pick came from. */
export interface WaypointSelection {
  waypoint: WaypointDto
  from: 'map' | 'profile' | 'list'
}

/**
 * Stacking order of the waypoint pictograms, from the bottom up: a danger is drawn over everything
 * else, an information over nothing. Also the key of the collision pass for their labels.
 */
export const WAYPOINT_PRIORITY: Record<WaypointType, number> = {
  INFO: 0,
  TOILETS: 1,
  BIKE_SHOP: 2,
  VIEWPOINT: 3,
  CAFE: 4,
  WATER: 5,
  SUPPLY: 6,
  SUMMIT: 7,
  SPLIT: 8,
  REAL_START: 9,
  REGROUP: 10,
  DANGER: 11,
}

/** A type this client does not know (a tab older than the contract) is an information. */
export function waypointTypeOf(type: string): WaypointType {
  return Object.prototype.hasOwnProperty.call(WAYPOINT_PRIORITY, type)
    ? (type as WaypointType)
    : 'INFO'
}

/** Map image ids: they carry everything needed to draw the image again (see `mapImages`). */
export const WAYPOINT_ICON_PREFIX = 'pdl-waypoint:'
export const WAYPOINT_LABEL_PREFIX = 'pdl-waypoint-label:'

export function waypointIconId(type: string): string {
  return `${WAYPOINT_ICON_PREFIX}${waypointTypeOf(type)}`
}

export function waypointLabelId(name: string, dark: boolean): string {
  return `${WAYPOINT_LABEL_PREFIX}${dark ? 'dark' : 'light'}:${name}`
}

/** Along the route, off-route points (no distance) last; stable. */
export function sortWaypoints(waypoints: readonly WaypointDto[]): WaypointDto[] {
  return waypoints
    .map((waypoint, index) => ({ waypoint, index }))
    .sort((a, b) => {
      const da = a.waypoint.distance ?? Infinity
      const db = b.waypoint.distance ?? Infinity
      if (da !== db) return da < db ? -1 : 1
      return a.index - b.index
    })
    .map((entry) => entry.waypoint)
}

/**
 * The GeoJSON of the waypoint layer. The feature id is the index in `waypoints`. There is no
 * filter on the coordinates: a point on the equator or the Greenwich meridian is a point
 * (ledger WEB-108).
 */
export function waypointFeatures(
  waypoints: readonly WaypointDto[],
  darkBasemap: boolean
): GeoJSON.FeatureCollection<GeoJSON.Point> {
  return {
    type: 'FeatureCollection',
    features: waypoints.map((waypoint, index) => ({
      type: 'Feature' as const,
      id: index,
      properties: {
        icon: waypointIconId(waypoint.type),
        label: waypoint.name ? waypointLabelId(waypoint.name, darkBasemap) : '',
        priority: WAYPOINT_PRIORITY[waypointTypeOf(waypoint.type)],
        onTrack: waypoint.distance != null,
      },
      geometry: {
        type: 'Point' as const,
        coordinates: [waypoint.geometry.coordinates[0], waypoint.geometry.coordinates[1]],
      },
    })),
  }
}

/** Index of the track point closest to `distance` (metres, `p[3]`) in an ordered track. */
export function pointIndexAtDistance(points: readonly number[][], distance: number): number {
  if (points.length === 0) return -1
  let lo = 0
  let hi = points.length - 1
  while (lo < hi) {
    const mid = (lo + hi) >> 1
    if (points[mid][3] < distance) lo = mid + 1
    else hi = mid
  }
  if (lo > 0 && Math.abs(points[lo - 1][3] - distance) <= Math.abs(points[lo][3] - distance)) {
    return lo - 1
  }
  return lo
}

/** The waypoints on the track within `tolerance` metres of `distance`. */
export function waypointsNear(
  waypoints: readonly WaypointDto[],
  distance: number,
  tolerance: number
): WaypointDto[] {
  return waypoints.filter((w) => w.distance != null && Math.abs(w.distance - distance) <= tolerance)
}
