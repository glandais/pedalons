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
}
