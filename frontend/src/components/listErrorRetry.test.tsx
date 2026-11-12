import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'

/**
 * The three lists whose error said « Erreur lors du chargement » or « Réessayez » with no button
 * (DL12) — the home feed, every route, the people taking part — now say « Chargement impossible »
 * with « Réessayer »; the people's search that finds nobody offers to clear it (DL20).
 */

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
    Translation: ({ children }: { children: (t: typeof frenchT) => ReactNode }) =>
      children(frenchT),
  }
})
vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: false }) }))
vi.mock('@/components/route/RouteFilterPanel', () => ({ RouteFilterPanel: () => null }))
vi.mock('@/components/route/RouteViewSwitch', () => ({ RouteViewSwitch: () => null }))
vi.mock('@/components/common/MembershipSelect', () => ({ MembershipSelect: () => null }))

const state = vi.hoisted(() => ({ list: {} as Record<string, unknown> }))

vi.mock('@/pages/route/allRouteListData', async () => {
  const { routeFiltersSchema } = await import('@/hooks/filters/routeFilters')
  return {
    useAllRouteListData: () => ({
      filters: { ...routeFiltersSchema.parse({}), membership: 'all' },
      setFilters: () => {},
      filtersOpen: false,
      setFiltersOpen: () => {},
      handleFiltersChange: () => {},
      handlePageChange: () => {},
      hasFiltersOrSearch: false,
      clearFilters: () => {},
      routes: state.list,
      density: 'card',
      totalPages: 1,
    }),
  }
})
vi.mock('@/api/endpoints/rides/rides', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/rides/rides')>()),
  useGetRideParticipants: () => state.list,
}))

import { AllRoutesPage } from '@/pages/route/AllRoutesPage'
import { HomeFeedSection } from './home/HomeFeedSection'
import { ParticipantList } from './ride/ParticipantList'

const query = (over: Record<string, unknown> = {}) => ({
  data: undefined,
  isLoading: false,
  isPending: false,
  isFetching: false,
  isError: false,
  error: null,
  refetch: vi.fn(),
  ...over,
})

function renderIt(element: ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{element}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

beforeEach(() => {
  state.list = query({ isError: true, error: new Error('Network Error') })
})
afterEach(cleanup)

function expectRetry() {
  expect(screen.getByText('Chargement impossible')).toBeTruthy()
  expect(screen.queryByText('Erreur lors du chargement')).toBeNull()
  fireEvent.click(screen.getByRole('button', { name: 'Réessayer' }))
  expect((state.list as { refetch: () => void }).refetch).toHaveBeenCalled()
}

const participantProps = {
  source: { kind: 'ride' as const, teamSlug: 'vc', rideSlug: 'mardi' },
  count: 4,
  page: 0,
  onPageChange: () => {},
}

describe('an error a list can retry (DL12)', () => {
  it('every route', () => {
    renderIt(<AllRoutesPage />)
    expectRetry()
  })

  it('the home feed', () => {
    const feed = {
      membershipDefault: 'all',
      filters: { page: 0, filter: 'all', scope: 'all', membership: 'all' },
      setFilters: () => {},
      publications: state.list,
      totalPages: 0,
    } as never
    renderIt(<HomeFeedSection feed={feed} title="Fil" />)
    expectRetry()
  })

  it('the people taking part', () => {
    renderIt(
      <ParticipantList
        {...participantProps}
        search={undefined}
        searchInput=""
        onSearchInputChange={() => {}}
      />
    )
    expect(screen.queryByText(/n'a pas pu être chargée/)).toBeNull()
    expectRetry()
  })
})

describe('a search of the people that finds nobody (DL20)', () => {
  it('offers « Effacer la recherche »', () => {
    state.list = query({ data: { participants: [], total: 0 } })
    const onSearchInputChange = vi.fn()
    renderIt(
      <ParticipantList
        {...participantProps}
        search="zoé"
        searchInput="zoé"
        onSearchInputChange={onSearchInputChange}
        noMatch="Personne ne correspond à votre recherche."
      />
    )
    expect(screen.getByText('Personne ne correspond à votre recherche.')).toBeTruthy()
    // The field's cross bears the same name (DL19): the state's own button comes after it.
    const buttons = screen.getAllByRole('button', { name: 'Effacer la recherche' })
    expect(buttons).toHaveLength(2)
    fireEvent.click(buttons[1])
    expect(onSearchInputChange).toHaveBeenCalledWith('')
  })
})
