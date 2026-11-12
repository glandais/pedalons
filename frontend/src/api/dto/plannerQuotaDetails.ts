import type { LocalDate } from './localDate.ts'
import type { PlannerQuotaDetailsType } from './plannerQuotaDetailsType.ts'
import type { PlannerQuotaScope } from './plannerQuotaScope.ts'

export interface PlannerQuotaDetails {
  type: PlannerQuotaDetailsType
  /** TEAM: the team is on the free plan and its monthly saves are spent. PERSONAL: the caller is a member of no unlocked team and their monthly saves in the GPX tools are spent. */
  scope: PlannerQuotaScope
  /** Saves of a drawn track allowed per calendar month */
  limit: number
  /** Saves already counted this month */
  current: number
  /** The day the count starts again: the first day of next month, in the team's zone for TEAM, in UTC for PERSONAL */
  resetsOn: LocalDate
  /** Name of the team, for TEAM only */
  teamName?: string
}
