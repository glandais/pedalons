import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { QueryClient } from '@tanstack/react-query'
import { describe, expect, it } from 'vitest'
import type { RideDto } from '@/api/dto'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { pathVariants, paths } from './paths'
import { routesConfig } from './routes.config'

/** A solo ride's fullscreen map (ledger WEB-118): a web route only, generated from routes.yaml. */
describe('the rideMap route', () => {
  const route = () => routesConfig.find((r) => r.id === 'ride-map')

  const cached = (groups: { id: string }[]) => {
    const queryClient = new QueryClient()
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      groups,
    } as RideDto)
    return queryClient
  }
  const params = { teamSlug: 'np', rideSlug: 'sortie' }

  it('builds the paths of the plan, in both languages', () => {
    expect(pathVariants.rideMap('np', 'sortie')).toEqual({
      en: '/teams/np/rides/sortie/map',
      fr: '/equipes/np/sorties/sortie/carte',
    })
  })

  it('is registered as a bare page under the ride, with a prefetch and a redirect', () => {
    expect(route()).toBeDefined()
    expect(route()?.paths).toEqual(pathVariants.rideMap(':teamSlug', ':rideSlug'))
    expect(route()?.layout).toBe('bare')
    expect(route()?.auth).toBe('public')
    expect(route()?.parentId).toBe('ride-detail')
    expect(route()?.prefetch).toBeTypeOf('function')
  })

  it('stays for a solo ride, sends any other ride to its page, the mode dropped', () => {
    const redirect = route()!.dataRedirect!
    const url = new URL('https://x/equipes/np/sorties/sortie/carte?color=wind')
    expect(redirect(cached([{ id: 'g1' }]), params, url)).toBeUndefined()
    expect(redirect(cached([{ id: 'g1' }, { id: 'g2' }]), params, url)).toBe(
      paths.ride('np', 'sortie')
    )
    expect(redirect(cached([]), params, url)).toBe(paths.ride('np', 'sortie'))
    // Nothing read (a private team, anonymously): the page decides on the client
    expect(redirect(new QueryClient(), params, url)).toBeUndefined()
  })

  it("is no universal link: the app has no screen for it, the ride's link stays the app's", () => {
    const aasa = readFileSync(
      resolve(process.cwd(), 'public/.well-known/apple-app-site-association'),
      'utf8'
    )
    expect(aasa).toContain('"NOT /teams/*/rides/*/map"')
    expect(aasa).toContain('"NOT /equipes/*/sorties/*/carte"')
  })
})

describe("a group's map for a ride without a group page (WEB-79, WEB-118)", () => {
  const redirect = () => routesConfig.find((r) => r.id === 'ride-group-map')!.dataRedirect!
  const params = { teamSlug: 'np', rideSlug: 'sortie', groupId: 'g1' }
  const url = new URL('https://x/equipes/np/sorties/sortie/groupes/g1/carte?color=wind')
  const cached = (groups: { id: string }[]) => {
    const queryClient = new QueryClient()
    queryClient.setQueryData(getGetRideQueryKey('np', 'sortie'), {
      slug: 'sortie',
      groups,
    } as RideDto)
    return queryClient
  }

  it("sends a solo ride to the ride's map, the mode kept", () => {
    expect(redirect()(cached([{ id: 'g1' }]), params, url)).toBe(
      `${paths.rideMap('np', 'sortie')}?color=wind`
    )
  })

  it("sends a ride without groups to its page, keeps a ride with several on the group's map", () => {
    expect(redirect()(cached([]), params, url)).toBe(paths.ride('np', 'sortie'))
    expect(redirect()(cached([{ id: 'g1' }, { id: 'g2' }]), params, url)).toBeUndefined()
  })
})
