import type { PlannerPieceMode } from './plannerPieceMode.ts'

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
}
