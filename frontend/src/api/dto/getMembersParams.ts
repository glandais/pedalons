import type { MemberSortBy } from './memberSortBy.ts'
import type { SortDirection } from './sortDirection.ts'
import type { TeamRole } from './teamRole.ts'

export type GetMembersParams = {
  /** Page number */
  page?: number
  /** Filter by role. Only for a caller who gets the roles (an administrator, or anyone once the directory is open): 403 otherwise. */
  role?: TeamRole
  /** Search by display name. Also matches the e-mail address, for administrators only. */
  search?: string
  /** Page size */
  size?: number
  /** Order of the list, always ended by the membership id so pages never overlap. NAME is the display name, regardless of case. JOINED_AT is the join date; only for a caller who gets the join dates (an administrator, or anyone once the directory is open): 403 otherwise. Omitted, NAME. */
  sortBy?: MemberSortBy
  /** Direction of sortBy. Omitted is ASC (A to Z) for NAME, and DESC (newest first) for JOINED_AT. */
  sortDir?: SortDirection
}
