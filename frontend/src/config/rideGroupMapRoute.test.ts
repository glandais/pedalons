import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { pathVariants } from './paths'
import { routesConfig } from './routes.config'
import { readUrlFilters } from '@/hooks/useUrlFilters'
import {
  mapColorFiltersAlias,
  mapColorFiltersSchema,
  withMapColor,
} from '@/hooks/filters/mapColorFilters'

/** The group's fullscreen map (ledger WEB-117): a web route only, generated from routes.yaml. */
describe('the rideGroupMap route', () => {
  it('builds the paths of the plan, in both languages', () => {
    expect(pathVariants.rideGroupMap('np', 'sortie', 'g1')).toEqual({
      en: '/teams/np/rides/sortie/groups/g1/map',
      fr: '/equipes/np/sorties/sortie/groupes/g1/carte',
    })
  })

  it('is registered as a bare page under the group, with a prefetch and the WEB-79 redirect', () => {
    const route = routesConfig.find((r) => r.id === 'ride-group-map')
    expect(route).toBeDefined()
    expect(route?.paths).toEqual(pathVariants.rideGroupMap(':teamSlug', ':rideSlug', ':groupId'))
    expect(route?.layout).toBe('bare')
    expect(route?.auth).toBe('public')
    expect(route?.parentId).toBe('ride-group')
    expect(route?.prefetch).toBeTypeOf('function')
    expect(route?.dataRedirect).toBeTypeOf('function')
  })

  it("is no universal link: the app has no screen for it, the group's link stays the app's", () => {
    const aasa = readFileSync(
      resolve(process.cwd(), 'public/.well-known/apple-app-site-association'),
      'utf8'
    )
    expect(aasa).toContain('"NOT /teams/*/rides/*/groups/*/map"')
    expect(aasa).toContain('"NOT /equipes/*/sorties/*/groupes/*/carte"')
  })
})

describe('the map colour mode in the URL', () => {
  const read = (search: string) =>
    readUrlFilters(new URLSearchParams(search), {
      schema: mapColorFiltersSchema,
      alias: mapColorFiltersAlias,
    }).colorBy

  it('reads ?color=, the grade by default and for a mode it does not know', () => {
    expect(read('color=wind')).toBe('wind')
    expect(read('color=surface')).toBe('surface')
    expect(read('')).toBe('grade')
    expect(read('color=rainbow')).toBe('grade')
  })

  it('writes the mode a link opens in, nothing for the grade', () => {
    expect(withMapColor('/carte', 'wind')).toBe('/carte?color=wind')
    expect(withMapColor('/carte', 'surface')).toBe('/carte?color=surface')
    expect(withMapColor('/carte', 'grade')).toBe('/carte')
  })
})
