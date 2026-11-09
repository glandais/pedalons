import type { MinRole } from './minRole.ts'
import type { SortDirection } from './sortDirection.ts'
import type { TeamSortBy } from './teamSortBy.ts'

export type ListTeamsParams = {
  /** Keep only teams that accept a join request from any domain user (true), or only those that do not (false). Omitted keeps both. A filter on top of the visibility rules, never instead of them. */
  joinable?: boolean
  /** Minimum role in team */
  minRole?: MinRole
  /** Page number (0-indexed) */
  page?: number
  /** Search query to filter teams by name */
  search?: string
  /** Page size */
  size?: number
  /** Sort column (default: name ascending). MEMBER_COUNT orders by the memberCount the rows carry. The team id always ends the key, so the order is total. */
  sortBy?: TeamSortBy
  /** Sort direction when sortBy is set (default: DESC) */
  sortDir?: SortDirection
}
