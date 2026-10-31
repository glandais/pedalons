/**
 * A track of an imported GPX file
 */
export interface GpxImportTrack {
  /** Polyline (precision 6, latitude then longitude) of the processed track, as PlannerSource.line */
  line: string
  /** One-dimension polyline (tenths of a metre), one value per point of line; absent when an elevation is not finite */
  ele?: string
  /** One-dimension polyline (tenths of a metre): the ascent accumulated up to each point of line (dead-band, non-decreasing, first 0, last = ascend); absent when ele is */
  climb?: string
  /** Length in metres */
  dist: number
  /** Reported ascent in metres */
  ascend: number
  /** Polyline (precision 6, latitude then longitude) of the raw track of the file, 2D, as sanitized, neither resampled nor simplified. Opaque to the client, which carries it into PlannerSource.shape. Only in the GPX import answer: always absent from the line-elevation answer, and absent from the import answer when the file's raw tracks together exceed the planner's point budget */
  shape?: string
}
