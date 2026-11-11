import { beforeEach, describe, expect, it, vi } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { Status, WeatherStatus } from '@/api/dto'
import { getGetRideQueryKey, getGetRideWeatherQueryKey } from '@/api/endpoints/rides/rides'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import { paths } from '@/config/paths'
import { weatherLeg } from '@/test/weatherFixtures'

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
  useAuthStore: { getState: () => ({ isAuthenticated: true }) },
  selectIsPlatformAdmin: () => false,
}))

import {
  canSwitchTo,
  groupAction,
  groupWindLeg,
  prefetchRideGroup,
  prefetchRideGroupMap,
  rideGroupDataRedirect,
} from './rideGroupData'

const g = (id: string) => ({ id, name: id }) as RideGroupDto

function redirect(groups: RideGroupDto[] | undefined, groupId = 'g1', search = '') {
  const queryClient = new QueryClient()
  if (groups) {
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      groups,
    } as unknown as RideDto)
  }
  return rideGroupDataRedirect(
    queryClient,
    { teamSlug: 'np', rideSlug: 'sortie', groupId },
    new URL(`https://pedalons.fr${paths.rideGroup('np', 'sortie', groupId)}${search}`)
  )
}

describe('rideGroupDataRedirect (WEB-79)', () => {
  it("sends a solo ride's group to the ride, with its query string", () => {
    expect(redirect([g('g1')], 'g1', '?q=x')).toBe(paths.ride('np', 'sortie') + '?q=x')
  })

  it('sends a group of a ride without groups to the ride', () => {
    expect(redirect([])).toBe(paths.ride('np', 'sortie'))
  })

  it('sends an unknown group of a solo ride to the ride', () => {
    expect(redirect([g('g1')], 'gone')).toBe(paths.ride('np', 'sortie'))
  })

  it('keeps the group page of a ride with several groups', () => {
    expect(redirect([g('g1'), g('g2')])).toBeUndefined()
    expect(redirect([g('g1'), g('g2')], 'gone')).toBeUndefined()
  })

  it('says nothing without the ride in the cache', () => {
    expect(redirect(undefined)).toBeUndefined()
  })
})

describe('prefetchRideGroupMap (WEB-117)', () => {
  beforeEach(() => {
    requests.urls = []
    requests.responses = {}
  })

  it("reads the group page's keys — ride, weather, then the team and the routes — and nothing else", async () => {
    requests.responses['/api/teams/np/rides/sortie'] = {
      slug: 'sortie',
      routeSlug: 'boucle',
      groups: [{ id: 'g1', routeSlug: 'col' }, { id: 'g2' }],
      team: { slug: 'np', accessible: true },
      permissions: { canSeeParticipants: true },
    }
    const queryClient = new QueryClient()
    await prefetchRideGroupMap(queryClient, 'np', 'sortie')
    expect(queryClient.getQueryState(getGetTeamQueryKey('np'))?.status).toBe('success')
    expect(queryClient.getQueryState(getGetRideQueryKey('np', 'sortie'))?.status).toBe('success')
    expect(queryClient.getQueryState(getGetRideWeatherQueryKey('np', 'sortie'))?.status).toBe(
      'success'
    )
    expect(requests.urls.some((u) => u.includes('/routes/bulk'))).toBe(true)
    // No participants nor GPS services: the map mounts neither, even signed in
    expect(requests.urls.some((u) => u.endsWith('/participants'))).toBe(false)
    expect(requests.urls.some((u) => u.includes('gps'))).toBe(false)
  })
})

describe('prefetchRideGroup: participants are members-only (API-144)', () => {
  beforeEach(() => {
    requests.urls = []
    requests.responses = {}
  })
  // The ride's computed rights decide (docs/LEDGER_*.md WEB-166), not the team's role.
  const run = (canSeeParticipants: boolean) => {
    requests.responses['/api/teams/np/rides/sortie'] = {
      slug: 'sortie',
      groups: [g('g1'), g('g2')],
      team: { slug: 'np', accessible: canSeeParticipants },
      permissions: { canSeeParticipants },
    }
    return prefetchRideGroup(
      new QueryClient(),
      'np',
      'sortie',
      'g1',
      new URL('https://pedalons.fr/equipes/np/sorties/sortie/groupes/g1')
    )
  }

  it('reads them for a member', async () => {
    await run(true)
    expect(requests.urls.filter((u) => u.endsWith('/participants'))).toHaveLength(1)
  })

  it('makes no /participants request for a non-member', async () => {
    await run(false)
    expect(requests.urls.some((u) => u.endsWith('/participants'))).toBe(false)
  })
})

describe('groupWindLeg (WEB-115, WEB-117)', () => {
  const ride = (overrides: Partial<RideDto> = {}) =>
    ({ status: Status.PUBLISHED, finished: false, ...overrides }) as RideDto

  it('is the leg with a forecast on a ride still to come', () => {
    expect(groupWindLeg(ride(), weatherLeg('g1'))?.groupId).toBe('g1')
    expect(groupWindLeg(ride(), weatherLeg('g1', { status: WeatherStatus.STALE }))).toBeTruthy()
  })

  it('is none without a forecast, on a finished or a cancelled ride', () => {
    expect(
      groupWindLeg(ride(), weatherLeg('g1', { status: WeatherStatus.NOT_YET_AVAILABLE }))
    ).toBeUndefined()
    expect(groupWindLeg(ride(), undefined)).toBeUndefined()
    expect(groupWindLeg(ride({ finished: true }), weatherLeg('g1'))).toBeUndefined()
    expect(groupWindLeg(ride({ status: Status.CANCELLED }), weatherLeg('g1'))).toBeUndefined()
  })
})

// KIT §8 and §9, ledger WEB-165 (docs/LEDGER_*.md WEB-167).
describe('groupAction and canSwitchTo', () => {
  const group = (id: string, overrides: Partial<RideGroupDto> = {}) =>
    ({ id, name: id, registered: false, full: false, ...overrides }) as RideGroupDto
  const ride = (overrides: Partial<RideDto> = {}) =>
    ({
      status: Status.PUBLISHED,
      registered: true,
      registeredGroupId: 'g1',
      permissions: { canRegister: true },
      ...overrides,
    }) as unknown as RideDto

  it('offers « Changer pour » on an open group to a reader registered in another', () => {
    expect(groupAction(ride(), group('g2'))).toBe('registeredElsewhere')
    expect(canSwitchTo(ride(), group('g2'))).toBe(true)
  })

  it('offers no switch to a full group, a cancelled ride, closed registrations or one’s own group', () => {
    expect(canSwitchTo(ride(), group('g2', { full: true }))).toBe(false)
    expect(canSwitchTo(ride({ status: Status.CANCELLED }), group('g2'))).toBe(false)
    expect(
      canSwitchTo(ride({ permissions: { canRegister: false } } as Partial<RideDto>), group('g2'))
    ).toBe(false)
    expect(canSwitchTo(ride(), group('g1', { registered: true }))).toBe(false)
    expect(
      canSwitchTo(ride({ registered: false, registeredGroupId: undefined }), group('g2'))
    ).toBe(false)
  })

  it('drops « Quitter » on a cancelled ride, keeps it on a published one', () => {
    expect(groupAction(ride(), group('g1', { registered: true }))).toBe('leave')
    expect(groupAction(ride({ status: Status.CANCELLED }), group('g1', { registered: true }))).toBe(
      'none'
    )
  })
})
