import { z } from 'zod'
import type { GetRideParticipantsParams } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField, sizeField } from './common'

/** The page size of every participants list — the modal's and the group page's. */
export const PARTICIPANTS_PAGE_SIZE = 50

/** The participants section of a group's page: its search and page live in the query string. */
export const groupParticipantFiltersSchema = z.object({
  search: searchField,
  page: pageField,
  size: sizeField(PARTICIPANTS_PAGE_SIZE),
})

export const groupParticipantFiltersAlias = COMMON_ALIAS

export type GroupParticipantFilters = z.infer<typeof groupParticipantFiltersSchema>

/**
 * The params of `GET …/rides/{rideSlug}/participants` for one group — one builder for the page and
 * its route's prefetch, so both read the same query key.
 */
export function groupParticipantsParams(
  groupId: string,
  filters: GroupParticipantFilters
): GetRideParticipantsParams {
  return { groupId, search: filters.search, page: filters.page, size: filters.size }
}
