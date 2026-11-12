export type PlannerQuotaDetailsType =
  (typeof PlannerQuotaDetailsType)[keyof typeof PlannerQuotaDetailsType]

export const PlannerQuotaDetailsType = {
  PLANNER_QUOTA_REACHED: 'PLANNER_QUOTA_REACHED',
} as const
