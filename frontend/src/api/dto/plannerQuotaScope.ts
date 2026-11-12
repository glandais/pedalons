export type PlannerQuotaScope = (typeof PlannerQuotaScope)[keyof typeof PlannerQuotaScope]

export const PlannerQuotaScope = {
  TEAM: 'TEAM',
  PERSONAL: 'PERSONAL',
} as const
