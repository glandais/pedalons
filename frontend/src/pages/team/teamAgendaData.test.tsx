import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createMemoryRouter, RouterProvider } from 'react-router-dom'
import type { ListPublicationsParams } from '@/api/dto'

/** Every request the agenda makes, and the answer of its list (RL15: two sections, their counts). */
const requests = vi.hoisted(() => ({
  calls: [] as Array<{ url: string; params?: ListPublicationsParams }>,
  list: {
    publications: [{ id: 'a' }, { id: 'b' }],
    total: 47,
    upcomingTotal: 18,
    page: 0,
    size: 12,
  },
}))
vi.mock('@/lib/axiosInstance', () => ({
  axiosMutator: (config: { url: string; params?: ListPublicationsParams }) => {
    requests.calls.push({ url: config.url, params: config.params })
    return Promise.resolve(config.url.endsWith('/publications') ? requests.list : {})
  },
}))

import { prefetchTeamAgenda, useTeamAgendaData } from './teamAgendaData'

const LIST_URL = '/api/teams/vc/publications'
const listCalls = () => requests.calls.filter((c) => c.url === LIST_URL)

beforeEach(() => {
  requests.calls.length = 0
})
afterEach(cleanup)

/**
 * The agenda is one call per page (API-185, RL15): `when=UPCOMING_FIRST&dated=true`, whatever the
 * kind and the period — `dated=true` keeps the team's posts out of « Plus tôt », so there is no
 * second list to merge.
 */
describe('the agenda reads one list per page: when=UPCOMING_FIRST&dated=true', () => {
  it.each([
    ['« Tout », « Toutes les dates »', '', {}],
    ['« Sorties »', '?type=ride', { type: 'RIDE' }],
    ['« Je participe »', '?w=me', { participating: true }],
    ['« Voyages », « Je participe »', '?type=trip&w=me', { type: 'TRIP', participating: true }],
  ])('%s', async (_label, query, expected) => {
    await prefetchTeamAgenda(new QueryClient(), 'vc', new URL(`https://x.test/agenda${query}`))
    // The page and the next one, each read once, never with another `when`.
    expect(listCalls().map((c) => c.params?.page)).toEqual([0, 1])
    for (const { params } of listCalls()) {
      expect(params).toMatchObject({ when: 'UPCOMING_FIRST', dated: true, ...expected })
    }
  })

  it('a later page reads its window — the page and its two neighbours — one call each', async () => {
    await prefetchTeamAgenda(new QueryClient(), 'vc', new URL('https://x.test/agenda?p=2'))
    expect(
      listCalls()
        .map((c) => c.params?.page)
        .sort()
    ).toEqual([1, 2, 3])
  })

  it('the page lands on the prefetch’s key and reads its sections from total / upcomingTotal', async () => {
    const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: Infinity } } })
    await prefetchTeamAgenda(queryClient, 'vc', new URL('https://x.test/agenda'))
    const prefetched = listCalls().length

    let seen: { total?: number; upcomingTotal?: number } | undefined
    function Probe() {
      seen = useTeamAgendaData('vc').publications.data
      return null
    }
    const router = createMemoryRouter([{ path: '/agenda', element: <Probe /> }], {
      initialEntries: ['/agenda'],
    })
    render(
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    )
    await waitFor(() => expect(seen).toMatchObject({ total: 47, upcomingTotal: 18 }))
    // Hydrated from the prefetch: the page did not read page 0 a second time.
    expect(listCalls().filter((c) => c.params?.page === 0)).toHaveLength(1)
    expect(listCalls().length).toBeGreaterThanOrEqual(prefetched)
  })
})
