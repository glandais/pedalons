import { z } from 'zod'
import type { GetRideParticipantsParams } from '@/api/dto'
import { COMMON_ALIAS, pageField, searchField } from './common'

/** The page size of every participants list — the modal's and the group page's. */
export const PARTICIPANTS_PAGE_SIZE = 50

/**
 * The participants section of a group's page: its search and page live in the query string. No
 * `size`: the list always reads {@link PARTICIPANTS_PAGE_SIZE}, whatever a hand-edited URL says.
 */
export const groupParticipantFiltersSchema = z.object({
  search: searchField,
  page: pageField,
})

export const groupParticipantFiltersAlias = COMMON_ALIAS

export type GroupParticipantFilters = z.infer<typeof groupParticipantFiltersSchema>

/**
 * The paging params of one participants page, as `ParticipantList` asks for them: an empty search
 * is no search, the size is fixed. The one place they are normalised, so a list and its route's
 * prefetch can only build the same query key.
 */
export function participantsPageParams(search: string | undefined, page: number) {
  return { search: search || undefined, page, size: PARTICIPANTS_PAGE_SIZE }
}

/**
 * The params of `GET …/rides/{rideSlug}/participants` for one group — what `ParticipantList`
 * reads for a `{kind: 'ride', groupId}` source, built by the same function for the route's
 * prefetch, so both read the same query key (`?q=` empty, any `?size=`, included).
 */
export function groupParticipantsParams(
  groupId: string,
  filters: GroupParticipantFilters
): GetRideParticipantsParams {
  return { ...participantsPageParams(filters.search, filters.page), groupId }
}
