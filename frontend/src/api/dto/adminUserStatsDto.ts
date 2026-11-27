/**
 * Accounts of the platform (or of one domain). Every field but total and deleted counts accounts that are not deleted; activity is based on the last sign-in date.
 */
export interface AdminUserStatsDto {
  /** Accounts that are not deleted */
  total: number
  /** Accounts deleted */
  deleted: number
  /** Accounts whose e-mail address is verified */
  emailVerified: number
  /** Accounts that accepted the terms */
  termsAccepted: number
  /** Platform administrators */
  platformAdmins: number
  /** Accounts with an avatar */
  withAvatar: number
  /** Accounts that never signed in */
  neverLoggedIn: number
  /** Accounts that signed in during the last 7 days */
  activeLast7Days: number
  /** Accounts that signed in during the last 30 days */
  activeLast30Days: number
  /** Accounts that signed in during the last 90 days */
  activeLast90Days: number
}
