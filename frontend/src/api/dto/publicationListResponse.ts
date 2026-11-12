import type { PublicationDto } from './publicationDto.ts'

/**
 * Paginated publication list response
 */
export interface PublicationListResponse {
  /** List of publications */
  publications: PublicationDto[]
  /** Total number of publications */
  total: number
  /** Current page number */
  page: number
  /** Page size */
  size: number
  /** With when=UPCOMING_FIRST only, null otherwise: how many of the 'total' rows are in the first section, « À venir » (rides and trips not over yet). They are the first upcomingTotal rows of the whole list, so the row at position page * size + i (i its index in 'publications') is « À venir » when that position is below upcomingTotal, « Plus tôt » otherwise; the second section counts total - upcomingTotal. Same filters and same instant as the page. */
  upcomingTotal?: number
}
