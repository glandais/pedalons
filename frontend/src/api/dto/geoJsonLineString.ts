import type { GeoJsonLineStringType } from './geoJsonLineStringType.ts'

export interface GeoJsonLineString {
  type: GeoJsonLineStringType
  /** Array of [lon, lat] coordinates, followed by the elevation in metres when the line carries one ([lon, lat, ele]). A route track's geometry (TrackDto.line) adds a 4th component, [lon, lat, ele, dist]: the distance in metres from the start of THAT track, monotonic, restarting at 0 on each track of the route; it is not the distance along the whole route. */
  coordinates: number[][]
}
