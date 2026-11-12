import type { ListViewMode } from './listViewMode.ts'
import type { MinRole } from './minRole.ts'
import type { PublicationType } from './publicationType.ts'
import type { PublicationWhen } from './publicationWhen.ts'
import type { SortDirection } from './sortDirection.ts'
import type { Status } from './status.ts'

export type ListAllPublicationsParams = {
  /** Only the rides and trips — the publications that have a departure; posts are left out. Whatever when says: with when=UPCOMING_FIRST it is an agenda, both sections free of posts, total and upcomingTotal counting rides and trips only. Combines with type: type=POST then yields an empty list (zero on a count endpoint), as when=UPCOMING does, rather than an error. Omitted or false: no such filter. */
  dated?: boolean
  /** Start date filter (ISO format) */
  from?: string
  /** Only publications from teams where the user has at least this role. Yields nothing for an anonymous visitor. */
  minRole?: MinRole
  /** Page number */
  page?: number
  /** Only publications the current user is registered to (rides and trips). Yields nothing for an anonymous visitor. */
  participating?: boolean
  /** Search by name/markdown */
  search?: string
  /** Page size */
  size?: number
  /** Order of the publication date. Omitted, or DESC, is newest first (the feed); ASC is soonest first — what a window of upcoming outings needs, so a page keeps the nearest ones. Given, it overrides the order set by when, except with when=UPCOMING_FIRST or EARLIER, which ignore it. */
  sortDir?: SortDirection
  /** Only publications with this status. Narrows the visibility rules, never widens them. */
  status?: Status
  /** End date filter (ISO format) */
  to?: string
  /** Types */
  type?: PublicationType
  /** How much of each row to send. COMPACT (case-insensitive) returns media.markdown empty and media.assets trimmed to the logo, the first image and the themed thumbnails — read 'excerpt' and 'thumbnailUrl' instead, both of which are present either way. The markdown body, the attachments, the GPX and FIT files and every image past the first are dropped. Omitted, or FULL, is the previous behaviour, byte for byte. */
  view?: ListViewMode
  /** Which side of now, judged by the end of a ride or a trip rather than its start: UPCOMING is what is not over yet (end >= now — an outing under way included), PAST what is over (end < now). Keeps rides and trips only: a post has no end. Sets the order too — UPCOMING soonest departure first, PAST latest first — unless sortDir is given. With participating=true, UPCOMING is « Je participe ». UPCOMING_FIRST filters nothing and orders the list in two sections (rule RL15): first what UPCOMING keeps, soonest departure first, then everything else — the rides and trips over and, unless dated=true, the posts — latest first; the id ends each section's key, so the order is total. The listing then fills upcomingTotal, the size of the first section; sortDir is ignored. On a count endpoint UPCOMING_FIRST counts the whole list, as omitting when does. EARLIER (« Plus tôt ») is exactly the second section of UPCOMING_FIRST: everything UPCOMING leaves out — the rides and trips over and, unless dated=true, the posts — in that section's order, latest first, the id ending the key; with dated=true it lists what PAST lists. No upcomingTotal, sortDir ignored; on a count endpoint it counts that section. Omitted: no such filter, newest first. */
  when?: PublicationWhen
}
