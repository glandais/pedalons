import { describe, it, expect, vi, afterEach } from 'vitest'
import { renderHook } from '@testing-library/react'

const auth = { isAuthenticated: true }
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

const stored: { slug: string | null } = { slug: null }
vi.mock('@mantine/hooks', () => ({ useLocalStorage: () => [stored.slug] }))

const store = { isPlatformAdmin: false }
vi.mock('@/store/authStore', () => ({
  useAuthStore: () => store.isPlatformAdmin,
  selectIsPlatformAdmin: () => store.isPlatformAdmin,
}))

const listing: { data: { teams: unknown[] } | undefined; isPending: boolean } = {
  data: undefined,
  isPending: false,
}
vi.mock('@/api/endpoints/teams/teams', () => ({
  useListTeams: () => listing,
  prefetchListTeamsQuery: vi.fn(),
}))

import { useGeneratorTeam } from './featuresData'

const team = (slug: string, role: string, planner = true) => ({
  slug,
  role,
  enableRoutes: true,
  enableRoutePlanner: planner,
})

afterEach(() => {
  auth.isAuthenticated = true
  store.isPlatformAdmin = false
  listing.data = undefined
  listing.isPending = false
  stored.slug = null
})

describe('useGeneratorTeam', () => {
  it('drops plain members and teams without the planner', () => {
    listing.data = {
      teams: [team('a', 'MEMBER'), team('b', 'ORGANIZER', false), team('c', 'ADMIN')],
    }
    expect(renderHook(() => useGeneratorTeam()).result.current.team?.slug).toBe('c')
  })

  it('prefers the stored slug when eligible, else the first eligible team', () => {
    listing.data = { teams: [team('a', 'ORGANIZER'), team('b', 'ADMIN'), team('m', 'MEMBER')] }
    stored.slug = 'b'
    expect(renderHook(() => useGeneratorTeam()).result.current.team?.slug).toBe('b')
    stored.slug = 'm'
    expect(renderHook(() => useGeneratorTeam()).result.current.team?.slug).toBe('a')
  })

  it('accepts a plain member who is a platform admin', () => {
    store.isPlatformAdmin = true
    listing.data = { teams: [team('a', 'MEMBER')] }
    expect(renderHook(() => useGeneratorTeam()).result.current.team?.slug).toBe('a')
  })

  it('is not pending and has no team for a visitor', () => {
    auth.isAuthenticated = false
    listing.isPending = true
    const { team: found, isPending } = renderHook(() => useGeneratorTeam()).result.current
    expect(found).toBeUndefined()
    expect(isPending).toBe(false)
  })
})
