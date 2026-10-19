export type PlannerJunctionKind = (typeof PlannerJunctionKind)[keyof typeof PlannerJunctionKind]

export const PlannerJunctionKind = {
  CONTROL: 'CONTROL',
  JOIN: 'JOIN',
} as const
