import type { AdminActivationWeekDto } from './adminActivationWeekDto.ts'

/**
 * Activation of new accounts per sign-up week and domain, newest week first (ledger API-213)
 */
export interface AdminActivationResponse {
  /** One row per week and domain that has at least one sign-up; a week without any is absent */
  weeks: AdminActivationWeekDto[]
  /** How many weeks back the rows go */
  weeksBack: number
}
