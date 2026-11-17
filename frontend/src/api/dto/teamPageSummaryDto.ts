import type { Status } from './status.ts'
import type { Visibility } from './visibility.ts'

/**
 * Team page summary for listings
 */
export interface TeamPageSummaryDto {
  /** Page ID (TSID) */
  id: string
  /** Page title */
  title: string
  /** Page URL slug */
  slug: string
  /** Visibility level */
  visibility: Visibility
  /** Page order */
  order: number
  /** Whether the page is soft-deleted */
  deleted: boolean
  /** Publication status: a DRAFT is listed only to the team's administrators and the platform admin, who are told it is one (docs/LEDGER_*.md WEB-120) */
  status: Status
  /** Hidden by moderation: listed only to the team's organisers, administrators and the platform admin (docs/LEDGER_*.md WEB-120) */
  moderationHidden: boolean
}
