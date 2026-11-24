/**
 * The stretch of a retouched route that changed
 */
export interface RetouchedSpanDto {
  /** Where on the ORIGINAL route, in metres from its start, the replaced stretch begins */
  fromM: number
  /** Where on the original route the replaced stretch ends; its length for MOVE_END and TRUNCATE (the rest is dropped) */
  toM: number
  /** Length of the new stretch in metres, 0 for TRUNCATE */
  newM: number
  /** Index in the polyline of the first point of the new stretch (up to it the polyline is the original route) */
  startIndex: number
  /** Index in the polyline of the last point of the new stretch */
  endIndex: number
  /** Share of the new stretch on the team's roads, 0 to 1 (measured on that stretch alone) */
  teamShare: number
  /** Share of the new stretch off pavement, 0 to 1 (as the route page) */
  unpavedShare: number
  /** Junctions the new stretch crosses more than once */
  crossings: number
}
