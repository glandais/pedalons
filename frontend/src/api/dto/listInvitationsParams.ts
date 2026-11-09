import type { InvitationStatus } from './invitationStatus.ts'

export type ListInvitationsParams = {
  /** Page number */
  page?: number
  /** Page size */
  size?: number
  /** Filter by status */
  status?: InvitationStatus
}
