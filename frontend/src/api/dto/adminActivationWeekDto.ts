import type { LocalDate } from './localDate.ts'

/**
 * Activation of the accounts created in one sign-up week on one domain: counts only, no person named. The rates are the client's to compute, over signedUp.
 */
export interface AdminActivationWeekDto {
  /** Domain ID (TSID) */
  domainId: string
  /** Domain name */
  domainName: string
  /** Monday of the sign-up week (ISO week, UTC) */
  weekStart: LocalDate
  /** Whether every account of the week has had its 7 days: the counts of a week that is not complete can still grow */
  complete: boolean
  /** Accounts created that week, deleted ones left out */
  signedUp: number
  /** Of those, accounts whose address is verified */
  verified: number
  /** Of those, accounts that joined a team (or created one) within 7 days of their creation, and still belong to it */
  joinedTeam: number
  /** Of those, accounts that signed up to a ride within 7 days of their creation, and are still signed up */
  joinedRide: number
}
