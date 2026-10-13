import { describe, expect, it, vi, beforeEach } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { RideDto, RideGroupDto, RideWeatherDto } from '@/api/dto'
import { getGetRideParticipantsQueryKey } from '@/api/endpoints/rides/rides'
import { groupParticipantsParams } from '@/hooks/filters/groupParticipantFilters'
import { okWeather, weatherLeg } from '@/test/weatherFixtures'

// Every request the prefetch makes, answered from `responses` by URL.
const requests = vi.hoisted(() => ({
  urls: [] as string[],
  responses: {} as Record<string, unknown>,
}))
vi.mock('@/lib/axiosInstance', () => ({
  axiosMutator: (config: { url: string }) => {
    requests.urls.push(config.url)
    return Promise.resolve(requests.responses[config.url] ?? {})
  },
}))
vi.mock('@/store/authStore', () => ({
  useAuthStore: { getState: () => ({ isAuthenticated: false }) },
}))

import { leavesGroupPage, ownLeg, prefetchRideDetail, soloGroup } from './rideDetailData'

const g = (id: string) => ({ id, name: id }) as RideGroupDto
const ride = (groups: RideGroupDto[]) => ({ slug: 'sortie', groups }) as unknown as RideDto

describe('a solo ride (WEB-79)', () => {
  it('is a ride with exactly one group', () => {
    expect(soloGroup(ride([]))).toBeUndefined()
    expect(soloGroup(ride([g('g1')]))?.id).toBe('g1')
    expect(soloGroup(ride([g('g1'), g('g2')]))).toBeUndefined()
    expect(soloGroup(undefined)).toBeUndefined()
  })

  it('has no group page, nor has a ride without groups', () => {
    expect(leavesGroupPage(ride([]))).toBe(true)
    expect(leavesGroupPage({ slug: 'sortie' } as RideDto)).toBe(true)
    expect(leavesGroupPage(ride([g('g1')]))).toBe(true)
    expect(leavesGroupPage(ride([g('g1'), g('g2')]))).toBe(false)
  })
})

describe('ownLeg: the leg the ride page unrolls (WEB-79)', () => {
  const weather = (legs: RideWeatherDto['legs']) => ({ ...okWeather, legs })

  it("is a ride without groups' single leg", () => {
    expect(ownLeg(ride([]), weather([weatherLeg(undefined)]))?.groupId).toBeUndefined()
    expect(ownLeg(ride([]), weather([weatherLeg(undefined)]))).toBeTruthy()
  })

  it("is a solo ride's group leg", () => {
    expect(ownLeg(ride([g('g1')]), weather([weatherLeg('g1')]))?.groupId).toBe('g1')
  })

  it('is none for a leg of another group, or with several groups', () => {
    expect(ownLeg(ride([g('g1')]), weather([weatherLeg('g9')]))).toBeUndefined()
    expect(ownLeg(ride([g('g1'), g('g2')]), okWeather)).toBeUndefined()
    expect(ownLeg(ride([g('g1')]), undefined)).toBeUndefined()
  })
})

describe('prefetchRideDetail', () => {
  beforeEach(() => {
    requests.urls = []
    requests.responses = {}
  })

  it("prefetches a solo ride's participants under the list's key, filters from the URL", async () => {
    requests.responses['/api/teams/np/rides/sortie'] = ride([g('g1')])
    const queryClient = new QueryClient()
    await prefetchRideDetail(
      queryClient,
      'np',
      'sortie',
      new URL('https://pedalons.fr/equipes/np/sorties/sortie?q=col&p=2')
    )
    const key = getGetRideParticipantsQueryKey(
      'np',
      'sortie',
      groupParticipantsParams('g1', { search: 'col', page: 2 })
    )
    expect(queryClient.getQueryState(key)?.status).toBe('success')
    expect(requests.urls.filter((u) => u.endsWith('/participants'))).toHaveLength(1)
  })

  it('reads no participants for a ride with several groups', async () => {
    requests.responses['/api/teams/np/rides/sortie'] = ride([g('g1'), g('g2')])
    await prefetchRideDetail(
      new QueryClient(),
      'np',
      'sortie',
      new URL('https://pedalons.fr/equipes/np/sorties/sortie')
    )
    expect(requests.urls.filter((u) => u.endsWith('/participants'))).toHaveLength(0)
  })
})
