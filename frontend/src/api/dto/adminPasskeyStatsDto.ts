/**
 * Passkeys of accounts that are not deleted
 */
export interface AdminPasskeyStatsDto {
  /** Passkeys registered */
  total: number
  /** Passkeys used during the last 30 days */
  usedLast30Days: number
}
