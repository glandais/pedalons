import { describe, expect, it, vi } from 'vitest'

// A host pinned to one team: the browser shows `/sorties/x`, the router works on
// `/equipes/n-peloton/sorties/x` (config/pinnedHistory.ts).
const pinned = vi.hoisted(() => ({ slug: null as string | null }))
vi.mock('@/config/appConfig', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/config/appConfig')>()),
  getPinnedTeamSlug: () => pinned.slug,
}))

import { matchRoutes } from 'react-router-dom'
import { QueryClient } from '@tanstack/react-query'
import { buildRoutes } from '@/config/RouteGenerator'
import { toRouter } from '@/config/pinnedHistory'
import { toCountHit } from './countHit'

function hitOn(host: string, routerPath: string) {
  const routes = buildRoutes(new QueryClient())
  const matches = matchRoutes(routes, routerPath) ?? []
  return toCountHit(
    { matches: matches.map(({ params, route }) => ({ params, route })) },
    host,
    '',
    false
  )
}

describe('toCountHit on a pinned host', () => {
  it('counts the same path as on the shared host, the host aside', () => {
    pinned.slug = null
    const shared = hitOn('pedalons.fr', '/equipes/n-peloton/sorties/sortie-secrete')

    pinned.slug = 'n-peloton'
    try {
      // What the pinned history hands the router for the browser's clean path.
      const routerPath = toRouter('/sorties/sortie-secrete')
      expect(routerPath).toBe('/equipes/n-peloton/sorties/sortie-secrete')
      const onPinned = hitOn('club-np.fr', routerPath)

      expect(shared!.p).toBe('/pedalons.fr/equipes/n-peloton/sorties/:rideSlug')
      expect(onPinned!.p).toBe('/club-np.fr/equipes/n-peloton/sorties/:rideSlug')
      expect(onPinned!.t).toBe(shared!.t)

      // A global page of the pinned host has no team: it stays a template.
      expect(hitOn('club-np.fr', toRouter('/connexion'))!.p).toBe('/club-np.fr/connexion')
      // The team home is the pinned host's root.
      expect(hitOn('club-np.fr', toRouter('/'))!.p).toBe('/club-np.fr/equipes/n-peloton')
    } finally {
      pinned.slug = null
    }
  })
})
