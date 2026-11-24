import type { GeoPoint } from './geoPoint.ts'

/**
 * The new finish of a retouch: exactly one of a point and a place of the team
 */
export interface RouteRetouchEnd {
  /** A position, e.g. a tap on the map */
  point?: GeoPoint
  /** A place of the route's team, by id: its position is the finish (400 VALIDATION on end.placeId when it is not one of the team's) */
  placeId?: string
}
