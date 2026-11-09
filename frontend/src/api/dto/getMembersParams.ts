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
  /** Order of the list. JOINED_AT is the join date, then the membership id; only for a caller who gets the join dates (an administrator, or anyone once the directory is open): 403 otherwise. Omitted, the order is unspecified. */
  sortBy?: MemberSortBy
  /** Direction of sortBy. Omitted is DESC — newest first. */
  sortDir?: SortDirection
}
