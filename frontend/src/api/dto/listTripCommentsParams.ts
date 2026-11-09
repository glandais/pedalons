import type { SortDirection } from './sortDirection.ts'

export type ListTripCommentsParams = {
  /** Page number (0-indexed). Omit both page and size to get the whole comment tree, as before this endpoint took parameters. */
  page?: number
  /** Load only the replies of this comment (TSID) instead of the top-level comments. Use it to expand one thread without re-reading the others. */
  parentId?: string
  /** Page size, capped at 100 (default 20) */
  size?: number
  /** Sort by creation date: ASC (oldest first, default) or DESC */
  sort?: SortDirection
}
