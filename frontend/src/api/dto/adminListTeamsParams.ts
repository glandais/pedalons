import type { TeamTier } from './teamTier.ts'

export type AdminListTeamsParams = {
  /** Filter by domain ID */
  domainId?: string
  /** Page number (0-indexed) */
  page?: number
  /** Page size */
  size?: number
  /** Filter by tier: the free teams, to unlock one; the unlocked ones */
  tier?: TeamTier
}
