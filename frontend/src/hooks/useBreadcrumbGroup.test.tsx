import { describe, expect, it, vi } from 'vitest'
import { renderHook } from '@testing-library/react'

vi.mock('react-i18next', async () => {
  const { frenchT } = await import('@/test/frenchT')
  return { useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }) }
})

const { empty } = vi.hoisted(() => ({ empty: () => ({ data: undefined, isLoading: false }) }))
vi.mock('../api/endpoints/teams/teams', () => ({ useGetTeam: empty }))
vi.mock('../api/endpoints/rides/rides', () => ({
  useGetRide: () => ({
    data: { name: 'Sortie du samedi', groups: [{ id: 'g1', name: 'Rapide' }] },
    isLoading: false,
  }),
}))
vi.mock('../api/endpoints/trips/trips', () => ({ useGetTrip: empty }))
vi.mock('../api/endpoints/routes/routes', () => ({ useGetRoute: empty }))
vi.mock('../api/endpoints/ride-templates/ride-templates', () => ({ useGetTemplate: empty }))
vi.mock('../api/endpoints/ads/ads', () => ({ useGetAd: empty }))
vi.mock('../api/endpoints/posts/posts', () => ({ useGetPost: empty }))
vi.mock('../api/endpoints/team-pages/team-pages', () => ({ useGetPage: empty }))

import { useBreadcrumbData } from './useBreadcrumbData'

// Agenda › <sortie> › Groupe <nom> (WEB-77): the group's crumb is read off its ride's groups.
describe('the ride group crumb', () => {
  it('names the group as its page titles it', () => {
    const { result } = renderHook(() =>
      useBreadcrumbData({ teamSlug: 'np', rideSlug: 'sortie', groupId: 'g1' })
    )
    expect(result.current.ride.name).toBe('Sortie du samedi')
    expect(result.current.rideGroup.name).toBe('Groupe Rapide')
  })

  it('has no name for a group the ride no longer has', () => {
    const { result } = renderHook(() =>
      useBreadcrumbData({ teamSlug: 'np', rideSlug: 'sortie', groupId: 'gone' })
    )
    expect(result.current.rideGroup.name).toBeUndefined()
  })
})
