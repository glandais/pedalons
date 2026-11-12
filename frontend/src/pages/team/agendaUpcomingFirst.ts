import type { QueryKey } from '@tanstack/react-query'
import {
  getListPublicationsQueryKey,
  listPublications,
} from '@/api/endpoints/publications/publications'
import { PublicationWhen, type PublicationListResponse } from '@/api/dto'
import { agendaKeepsPostsOut, type AgendaApiParams } from '@/hooks/filters/agendaFilters'
import { LIST_REQUEST } from '@/lib/listQuery'

/**
 * The agenda's « Tout » over « Toutes les dates », in the shape `when=UPCOMING_FIRST` answers —
 * the page of the list in two sections, `upcomingTotal` included — but without the posts, which
 * `UPCOMING_FIRST` puts in « Plus tôt » and `type` cannot leave out with both kinds (it takes one).
 *
 * Built from the two lists the API serves page by page: `when=UPCOMING` (its page `page` is
 * exactly the upcoming part of the combined page `page`, both sections sharing the size) and
 * `when=PAST`, whose rows `[page * size - upcomingTotal, (page + 1) * size - upcomingTotal)` close
 * the page — one or two of its pages, since that window rarely falls on a page boundary. Its total
 * is the size of « Plus tôt ». Every row comes from the API, in the API's order.
 *
 * A bridge until the API can keep a `UPCOMING_FIRST` list to rides and trips: then this is one
 * `listPublications` call, like the agenda's other lists.
 */
export async function listRidesAndTripsUpcomingFirst(
  teamSlug: string,
  params: AgendaApiParams,
  signal?: AbortSignal
): Promise<PublicationListResponse> {
  const { page, size } = params
  const base = { ...params, when: undefined }
  const upcoming = await listPublications(
    teamSlug,
    { ...base, when: PublicationWhen.UPCOMING },
    LIST_REQUEST,
    signal
  )
  const upcomingTotal = upcoming.total
  // The window of the past list this page shows, end excluded; empty while the page is all ahead.
  const from = Math.max(0, page * size - upcomingTotal)
  const to = Math.max(from, (page + 1) * size - upcomingTotal)
  const firstPage = Math.floor(from / size)
  const lastPage = to > from ? Math.floor((to - 1) / size) : firstPage
  // The first past page is read even when the page shows none of it: its total is the section's.
  const pastPages = await Promise.all(
    Array.from({ length: lastPage - firstPage + 1 }, (_, i) =>
      listPublications(
        teamSlug,
        { ...base, when: PublicationWhen.PAST, page: firstPage + i },
        LIST_REQUEST,
        signal
      )
    )
  )
  const pastRows = pastPages.flatMap((response) => response.publications)
  const offset = firstPage * size
  return {
    publications: [...upcoming.publications, ...pastRows.slice(from - offset, to - offset)],
    total: upcomingTotal + pastPages[0].total,
    upcomingTotal,
    page,
    size,
  }
}

/**
 * The query the agenda reads for a page: `listPublications` itself when `UPCOMING_FIRST` keeps it
 * to rides and trips, {@link listRidesAndTripsUpcomingFirst} otherwise — under its own key, since
 * it is not that endpoint's answer. Shared by the page, its neighbour prefetch and the route's
 * `prefetch`, so the three land on one key.
 */
export function agendaListQuery(
  teamSlug: string,
  params: AgendaApiParams
): {
  queryKey: QueryKey
  queryFn: (context: { signal?: AbortSignal }) => Promise<PublicationListResponse>
} {
  if (agendaKeepsPostsOut(params)) {
    return {
      queryKey: getListPublicationsQueryKey(teamSlug, params),
      queryFn: ({ signal }: { signal?: AbortSignal }) =>
        listPublications(teamSlug, params, LIST_REQUEST, signal),
    }
  }
  return {
    queryKey: ['agenda-rides-and-trips', ...getListPublicationsQueryKey(teamSlug, params)],
    queryFn: ({ signal }: { signal?: AbortSignal }) =>
      listRidesAndTripsUpcomingFirst(teamSlug, params, signal),
  }
}
