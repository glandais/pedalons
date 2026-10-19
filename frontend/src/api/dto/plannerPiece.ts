import type { PlannerPieceMode } from './plannerPieceMode.ts'
import type { UnpavedSpan } from './unpavedSpan.ts'

export interface PlannerPiece {
  mode: PlannerPieceMode
  /**
   * ROUTED and DIRECT: polyline6 of the points strictly inside the piece
   * @maxLength 2000000
   */
  line?: string
  /**
   * ROUTED and DIRECT: one-dimension polyline of their elevations
   * @maxLength 2000000
   */
  ele?: string
  /** ROUTED: climb of the piece in metres */
  ascend?: number
  /** IMPORTED: index of the source track */
  source?: number
  /** IMPORTED: index in the source of the first junction */
  from?: number
  /** IMPORTED: index in the source of the last junction */
  to?: number
  /**
   * ROUTED: runs of unpaved edges of the piece, half-open, ascending and disjoint; edge 0 joins the first junction to the first interior point, the last edge ends at the last junction. Absent: surface unknown
   * @maxItems 50000
   */
  unpaved?: UnpavedSpan[]
}
