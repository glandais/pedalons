import type { LocalDate } from './localDate.ts'

/**
 * Saves of a drawn track this calendar month, against the plan's quota
 */
export interface PlannerQuotaDto {
  /** Saves of a drawn track allowed per calendar month; null when unlimited */
  limit?: number
  /** Saves of a drawn track counted this month */
  used: number
  /** The day the count starts again: the first day of next month, in the team's zone for a team, in UTC for the personal quota */
  resetsOn: LocalDate
}
