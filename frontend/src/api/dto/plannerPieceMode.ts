export type PlannerPieceMode = (typeof PlannerPieceMode)[keyof typeof PlannerPieceMode]

export const PlannerPieceMode = {
  ROUTED: 'ROUTED',
  DIRECT: 'DIRECT',
  IMPORTED: 'IMPORTED',
} as const
