import { describe, it, expect, vi } from 'vitest'

vi.mock('./appConfig', () => ({
  getPinnedTeamSlug: () => 'n-peloton',
}))
const current = vi.hoisted(() => ({ locale: 'fr' as 'fr' | 'en' }))
vi.mock('./locale-context', () => ({
  getCurrentLocale: () => current.locale,
}))

import { UNSAFE_createRouter, generatePath, matchPath, redirect } from 'react-router-dom'
import { getPinnedHistory, toBrowser, toRouter } from './pinnedHistory'
import { routesConfig } from './routes.config'
import { buildCanonicalUrl } from '@/lib/seo'

describe('pinnedHistory mapping (pinned to "n-peloton", fr locale)', () => {
  describe('toBrowser (router → browser, strips the prefix)', () => {
    it('maps the team root to /', () => {
      expect(toBrowser('/equipes/n-peloton')).toBe('/')
    })
    it('strips the fr prefix from team sub-paths', () => {
      expect(toBrowser('/equipes/n-peloton/sorties/x')).toBe('/sorties/x')
      expect(toBrowser('/equipes/n-peloton/parcours')).toBe('/parcours')
      expect(toBrowser('/equipes/n-peloton/admin')).toBe('/admin')
    })
    it('strips the en prefix too (cross-locale legacy links)', () => {
      expect(toBrowser('/teams/n-peloton/rides/x')).toBe('/rides/x')
    })
    it('leaves genuinely-global paths untouched', () => {
      expect(toBrowser('/connexion')).toBe('/connexion')
      expect(toBrowser('/plateforme')).toBe('/plateforme')
      expect(toBrowser('/')).toBe('/')
    })
    it('does not strip a lookalike that is not the prefix', () => {
      expect(toBrowser('/equipes')).toBe('/equipes')
      expect(toBrowser('/equipes/other-team/sorties')).toBe('/equipes/other-team/sorties')
    })
  })

  describe('toRouter (browser → router, adds the prefix for team paths)', () => {
    it('roots / on the team home', () => {
      expect(toRouter('/')).toBe('/equipes/n-peloton')
    })
    it('prefixes team sub-paths', () => {
      expect(toRouter('/sorties/x')).toBe('/equipes/n-peloton/sorties/x')
    })
    it('prefixes collision segments so the TEAM version wins', () => {
      expect(toRouter('/calendrier')).toBe('/equipes/n-peloton/calendrier')
      expect(toRouter('/parcours')).toBe('/equipes/n-peloton/parcours')
      expect(toRouter('/parcours/carte')).toBe('/equipes/n-peloton/parcours/carte')
      expect(toRouter('/admin')).toBe('/equipes/n-peloton/admin')
    })
    it('leaves genuinely-global paths unprefixed', () => {
      expect(toRouter('/connexion')).toBe('/connexion')
      expect(toRouter('/profil')).toBe('/profil')
      expect(toRouter('/confidentialite')).toBe('/confidentialite')
      expect(toRouter('/outils-gpx/abc')).toBe('/outils-gpx/abc')
      expect(toRouter('/garmin')).toBe('/garmin')
    })
    it('keeps the relocated platform admin reachable', () => {
      expect(toRouter('/plateforme')).toBe('/plateforme')
      expect(toRouter('/plateforme/domaines')).toBe('/plateforme/domaines')
    })
    it('is a no-op for already-prefixed (leaked legacy) paths', () => {
      expect(toRouter('/equipes/n-peloton/sorties/x')).toBe('/equipes/n-peloton/sorties/x')
      expect(toRouter('/equipes/n-peloton')).toBe('/equipes/n-peloton')
    })
  })

  it('round-trips team paths: toBrowser ∘ toRouter = identity for clean paths', () => {
    for (const clean of ['/', '/sorties/x', '/parcours', '/calendrier', '/admin']) {
      expect(toBrowser(toRouter(clean))).toBe(clean)
    }
  })
})

describe("a clean path resolves in its own language, whatever the visitor's", () => {
  /** Every team route of routesConfig, in each locale, with its params filled in. */
  const teamPaths = routesConfig.flatMap((route) =>
    Object.values(route.paths)
      .filter((pattern) => pattern.includes(':teamSlug'))
      .map((pattern) => {
        const params = Object.fromEntries(
          [...pattern.matchAll(/:(\w+)/g)].map(([, name]) => [
            name,
            name === 'teamSlug' ? 'n-peloton' : 'x',
          ])
        )
        return {
          id: route.id,
          variants: Object.values(route.paths),
          path: generatePath(pattern, params),
        }
      })
  )

  for (const locale of ['fr', 'en'] as const)
    it(`maps every team path back to the same route (visitor in ${locale})`, () => {
      current.locale = locale
      try {
        for (const { id, variants, path } of teamPaths) {
          const routed = toRouter(toBrowser(path))
          const matched = variants.some((variant) => matchPath(variant, routed))
          expect(matched, `${id}: ${path} → ${routed}`).toBe(true)
        }
      } finally {
        current.locale = 'fr'
      }
    })

  it('routes an English link under the English prefix for a French visitor', () => {
    expect(toRouter('/rides/x')).toBe('/teams/n-peloton/rides/x')
    expect(toRouter('/sorties/x')).toBe('/equipes/n-peloton/sorties/x')
  })

  it('gives every team route a canonical the pinned host serves, for any visitor', () => {
    for (const route of routesConfig) {
      const pattern = route.paths.fr
      if (!pattern?.includes(':teamSlug')) continue
      const params = Object.fromEntries(
        [...pattern.matchAll(/:(\w+)/g)].map(([, name]) => [
          name,
          name === 'teamSlug' ? 'n-peloton' : 'x',
        ])
      )
      const canonical = buildCanonicalUrl(route.paths, params, 'https://np.example', {
        toBrowser,
        toRouter,
      })
      expect(canonical, route.id).toBeDefined()
      for (const locale of ['fr', 'en'] as const) {
        current.locale = locale
        try {
          const routed = toRouter(canonical!.slice('https://np.example'.length))
          const matched = Object.values(route.paths).some((variant) => matchPath(variant, routed))
          expect(matched, `${route.id} (${locale}): ${routed}`).toBe(true)
        } finally {
          current.locale = 'fr'
        }
      }
    }
  })
})

describe('pinned history under a data router', () => {
  it('follows a redirect once, and a push navigates, without re-entering itself', async () => {
    window.history.replaceState(null, '', '/')
    let calendarLoads = 0
    const router = UNSAFE_createRouter({
      history: getPinnedHistory()!,
      routes: [
        { path: '/equipes/n-peloton', element: null },
        { path: '/connexion', element: null },
        {
          // A members-only page visited anonymously: its guard sends to sign in.
          path: '/equipes/n-peloton/calendrier',
          loader: () => {
            calendarLoads++
            return redirect('/connexion')
          },
          element: null,
        },
        { path: '/equipes/n-peloton/parcours', element: null },
      ],
    }).initialize()

    await router.navigate('/equipes/n-peloton/calendrier')
    expect(router.state.location.pathname).toBe('/connexion')
    expect(window.location.pathname).toBe('/connexion')
    // The loop re-ran the navigation from its own history notification.
    expect(calendarLoads).toBe(1)

    await router.navigate('/equipes/n-peloton/parcours')
    expect(router.state.location.pathname).toBe('/equipes/n-peloton/parcours')
    expect(window.location.pathname).toBe('/parcours')
    router.dispose()
  })
})
