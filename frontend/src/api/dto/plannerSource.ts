export interface PlannerSource {
  /**
   * Polyline (precision 6, latitude then longitude) of the source track
   * @maxLength 2000000
   */
  line: string
  /**
   * One-dimension polyline (tenths of a metre), one value per point of line; absent: no elevation
   * @maxLength 2000000
   */
  ele?: string
  /** Factor that recalibrates the raw climb of the source on a reference ascent (1 without reference); in ]0, 100] */
  ascendScale: number
  /**
   * One-dimension polyline (tenths of a metre), one value per point of line: the ascent accumulated up to each point, as the server measured it (dead-band, non-decreasing, within [0, 100 000 m]). Absent: the client derives it from ele. Requires ele
   * @maxLength 2000000
   */
  climb?: string
  /**
   * Polyline (precision 6, latitude then longitude) of the raw track of the file, as GpxImportTrack.shape gave it, never edited. An imported piece is cut out of it by projecting its junctions (from and to still index line); absent or inconsistent with line: line
   * @maxLength 2000000
   */
  shape?: string
}
