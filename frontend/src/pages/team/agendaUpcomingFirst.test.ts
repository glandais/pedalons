import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { ListPublicationsParams, PublicationListResponse } from '@/api/dto'
import { agendaApiParams, agendaFiltersSchema } from '@/hooks/filters/agendaFilters'

/** A team with `UPCOMING` rides 0…u-1 and `PAST` rides 100…100+p-1, served page by page. */
const served = { upcoming: 0, past: 0 }
const calls: ListPublicationsParams[] = []

vi.mock('@/api/endpoints/publications/publications', () => ({
  getListPublicationsQueryKey: (slug: string, params: unknown) => [
    `/api/teams/${slug}/publications`,
    params,
  ],
  listPublications: async (_slug: string, params: ListPublicationsParams) => {
    calls.push(params)
    const page = params.page ?? 0
    const size = params.size ?? 12
    const [count, base] = params.when === 'UPCOMING' ? [served.upcoming, 0] : [served.past, 100]
    const ids = Array.from({ length: count }, (_, i) => base + i).slice(
      page * size,
      (page + 1) * size
    )
    return {
      publications: ids.map((id) => ({ id: String(id), type: 'RIDE' })),
      total: count,
      page,
      size,
    } as unknown as PublicationListResponse
  },
}))

const { agendaListQuery, listRidesAndTripsUpcomingFirst } = await import('./agendaUpcomingFirst')

const params = (page: number) =>
  agendaApiParams({ ...agendaFiltersSchema.parse({}), page, size: 12 })
const ids = (response: PublicationListResponse) => response.publications.map((p) => Number(p.id))

beforeEach(() => {
  calls.length = 0
})

/**
 * The agenda's « Tout » over « Toutes les dates » (RL15): `UPCOMING_FIRST` would put the team's
 * posts in « Plus tôt », so the page is built from `UPCOMING` and `PAST`, in the shape and the
 * order `UPCOMING_FIRST` would serve.
 */
describe('listRidesAndTripsUpcomingFirst', () => {
  it('a page all ahead: the upcoming page, the past list read for its total only', async () => {
    Object.assign(served, { upcoming: 18, past: 29 })
    const response = await listRidesAndTripsUpcomingFirst('vc', params(0))
    expect(ids(response)).toEqual(Array.from({ length: 12 }, (_, i) => i))
    expect(response).toMatchObject({ total: 47, upcomingTotal: 18, page: 0, size: 12 })
    expect(calls.map((c) => [c.when, c.page])).toEqual([
      ['UPCOMING', 0],
      ['PAST', 0],
    ])
  })

  it('the page where the sections meet: the last upcoming rows, then the first past ones', async () => {
    Object.assign(served, { upcoming: 18, past: 29 })
    const response = await listRidesAndTripsUpcomingFirst('vc', params(1))
    expect(ids(response)).toEqual([12, 13, 14, 15, 16, 17, 100, 101, 102, 103, 104, 105])
  })

  it('a page in the past section, across two of its pages', async () => {
    Object.assign(served, { upcoming: 18, past: 29 })
    // Positions 24…35 are past rows 6…17: past pages 0 and 1.
    const response = await listRidesAndTripsUpcomingFirst('vc', params(2))
    expect(ids(response)).toEqual(Array.from({ length: 12 }, (_, i) => 106 + i))
    expect(calls.filter((c) => c.when === 'PAST').map((c) => c.page)).toEqual([0, 1])
  })

  it('sends neither UPCOMING_FIRST nor anything but its own when', async () => {
    Object.assign(served, { upcoming: 2, past: 3 })
    const response = await listRidesAndTripsUpcomingFirst('vc', params(0))
    expect(ids(response)).toEqual([0, 1, 100, 101, 102])
    expect(calls.every((c) => c.when === 'UPCOMING' || c.when === 'PAST')).toBe(true)
  })
})

describe('agendaListQuery', () => {
  it('reads UPCOMING_FIRST itself when it keeps the posts out', () => {
    const withKind = agendaApiParams(agendaFiltersSchema.parse({ filter: 'ride' }))
    expect(agendaListQuery('vc', withKind).queryKey[0]).toBe('/api/teams/vc/publications')
  })

  it('reads the bridge, under its own key, for « Tout » over « Toutes les dates »', () => {
    expect(agendaListQuery('vc', params(0)).queryKey[0]).toBe('agenda-rides-and-trips')
  })
})
