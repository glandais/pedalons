import { describe, expect, it } from 'vitest'
import { createMemoryRouter, generatePath, matchRoutes, type RouteObject } from 'react-router-dom'
import { QueryClient } from '@tanstack/react-query'
import { buildRoutes } from '@/config/RouteGenerator'
import { routesConfig } from '@/config/routes.config'
import { LOCALES } from '@/config/paths'
import { useAuthStore } from '@/store/authStore'
import { NOT_FOUND_ROUTE_ID, toCountHit, type CountableState } from './countHit'

/**
 * The promise of docs/plans/2026-10-15-web-analytics.md §4.2 (docs/LEDGER_*.md WEB-90): a page view
 * carries the host, the route template and the team slug — never another parameter, the query
 * string, the fragment, the title or the session.
 */

const HOST = 'club-exemple.fr'
const TEAM = 'equipe-privee'

/** One sentinel per route parameter: none but the team's may ever reach `p`. */
function sentinel(name: string): string {
  if (name === 'teamSlug') return TEAM
  if (name === 'previewId') return 'SECRET123'
  if (name === 'rideSlug') return 'sortie-secrete'
  return `secret-${name.toLowerCase()}`
}

/** The app's real route table, matched the way the data router matches a location. */
const routes = buildRoutes(new QueryClient())

/** The same table without loaders: a memory router built on it is initialized and fetches nothing. */
function withoutLoaders(table: RouteObject[]): RouteObject[] {
  return table.map((route) => {
    const copy = { ...route, loader: undefined } as RouteObject
    if (route.children) copy.children = withoutLoaders(route.children)
    return copy
  })
}
const routesWithoutLoaders = withoutLoaders(routes)

/** The state a data router holds at a full URL — query string and fragment included. */
function routerStateAt(url: string) {
  const router = createMemoryRouter(routesWithoutLoaders, { initialEntries: [url] })
  const { state } = router
  router.dispose()
  return state
}

function stateAt(pathname: string): CountableState {
  const matches = matchRoutes(routes, pathname) ?? []
  return { matches: matches.map(({ params, route }) => ({ params, route })) }
}

function hitAt(pathname: string, referrer = '', isFirst = false) {
  return toCountHit(stateAt(pathname), HOST, referrer, isFirst)
}

const cases = routesConfig.flatMap((route) =>
  LOCALES.map((locale) => {
    const pattern = route.paths[locale]
    const names = [...pattern.matchAll(/:(\w+)/g)].map(([, name]) => name)
    const params = Object.fromEntries(names.map((name) => [name, sentinel(name)]))
    return { route, locale, names, url: generatePath(pattern, params) }
  })
)

describe('toCountHit over every route × locale', () => {
  for (const { route, locale, names, url } of cases) {
    it(`${route.id} (${locale}) ${url}`, () => {
      // The concrete URL, with what must never leave: the query string and the fragment.
      const full = `${url}?token=SECRET&next=/x#frag`
      const state = routerStateAt(full)
      // They are really in the state handed over: the checks below can fail.
      expect(state.location.search).toBe('?token=SECRET&next=/x')
      expect(state.location.hash).toBe('#frag')
      const hit = toCountHit(state, HOST, '', false)

      expect(hit, 'a route without a counted hit').not.toBeNull()
      expect(hit!.t).toBe(`${route.id} · ${route.auth}`)
      expect(hit!.p).not.toMatch(/[?#]/)
      expect(hit!.p).not.toContain('SECRET')
      expect(hit!.p).not.toContain('frag')
      for (const name of names.filter((name) => name !== 'teamSlug')) {
        expect(hit!.p).not.toContain(sentinel(name))
        expect(hit!.p).toContain(`:${name}`)
      }

      // The French template, whatever the locale of the URL; only `:teamSlug` is filled in.
      const template = route.paths.fr === '/' ? '' : route.paths.fr
      const expected = `/${HOST}${template.replace(':teamSlug', TEAM)}`
      expect(hit!.p).toBe(expected)
      const segments = hit!.p.split('/')
      if (route.paths.fr.includes(':teamSlug')) {
        expect(segments.filter((segment) => segment === TEAM)).toHaveLength(1)
        expect(hit!.p).not.toContain(':teamSlug')
      } else {
        expect(hit!.p).not.toContain(TEAM)
      }
    })
  }

  it('covers team routes', () => {
    expect(cases.some(({ names }) => names.includes('teamSlug'))).toBe(true)
  })
})

describe('the team slug', () => {
  const ride = (teamSlug: string): CountableState => ({
    matches: [
      { params: {}, route: {} },
      {
        params: { teamSlug, rideSlug: 'sortie-secrete' },
        route: { handle: { routeId: 'ride-detail' } },
      },
    ],
  })
  const template = routesConfig.find((route) => route.id === 'ride-detail')!.paths.fr

  it.each([
    ['an encoded space and capitals', 'Equipe%20X'],
    ['its decoded form', 'Equipe X'],
    ['an e-mail address', 'a@b.fr'],
    ['a token-like value', 'eyJhbGciOiJIUzI1NiJ9.x'],
    ['a trailing dash', 'equipe-'],
    ['more than 200 characters', 'a'.repeat(201)],
    ['an empty value', ''],
  ])('stays a marker when malformed: %s', (_label, teamSlug) => {
    const hit = toCountHit(ride(teamSlug), HOST, '', false)
    expect(hit!.p).toBe(`/${HOST}${template}`)
    expect(hit!.p).toContain(':teamSlug')
    if (teamSlug) expect(hit!.p).not.toContain(teamSlug)
  })

  it('is kept at 200 characters', () => {
    const slug = 'a'.repeat(200)
    expect(toCountHit(ride(slug), HOST, '', false)!.p).toBe(
      `/${HOST}${template.replace(':teamSlug', slug)}`
    )
  })

  it('comes from the matched params, never from the URL', () => {
    const state = stateAt('/equipes/equipe-privee/sorties/sortie-secrete')
    // The params the router resolved say another team: they win.
    state.matches.at(-1)!.params = { ...state.matches.at(-1)!.params, teamSlug: 'autre-equipe' }
    expect(toCountHit(state, HOST, '', false)!.p).toContain('/autre-equipe/')
  })
})

describe('the title', () => {
  it('is the route id and its static auth, not document.title nor the session', () => {
    document.title = 'Sortie secrète — Équipe privée'
    const anonymous = hitAt('/equipes/equipe-privee/sorties/sortie-secrete')
    useAuthStore.setState({ isAuthenticated: true })
    try {
      const signedIn = hitAt('/equipes/equipe-privee/sorties/sortie-secrete')
      expect(signedIn).toEqual(anonymous)
    } finally {
      useAuthStore.setState({ isAuthenticated: false })
    }
    expect(anonymous!.t).toBe('ride-detail · public')
    expect(anonymous!.t).not.toContain('secrète')
    expect(hitAt('/profil/vie-privee')!.t).toBe('profile-privacy · authenticated')
  })
})

describe('the referrer', () => {
  const page = '/equipes/equipe-privee'

  it('is the external origin only — no path, no query', () => {
    expect(hitAt(page, 'https://www.google.fr/search?q=velo&token=x', true)!.r).toBe(
      'https://www.google.fr'
    )
    expect(hitAt(page, 'http://lemonde.fr:8080/article/1', true)!.r).toBe('http://lemonde.fr:8080')
  })

  it('is absent when internal', () => {
    expect(hitAt(page, `https://${HOST}/equipes/x?token=SECRET`, true)).not.toHaveProperty('r')
  })

  it('is absent when empty, unreadable or not http', () => {
    expect(hitAt(page, '', true)).not.toHaveProperty('r')
    expect(hitAt(page, 'not a url', true)).not.toHaveProperty('r')
    expect(hitAt(page, 'android-app://com.google.android.gm/', true)).not.toHaveProperty('r')
  })

  it('is sent on the first page view only', () => {
    expect(hitAt(page, 'https://www.google.fr/', false)).not.toHaveProperty('r')
  })
})

describe('routes without a page', () => {
  it('counts the catch-all as /404, and only it', () => {
    const hit = hitAt('/une/adresse/inconnue-SECRET')
    expect(hit).toEqual({ p: `/${HOST}/404`, t: `${NOT_FOUND_ROUTE_ID} · public` })
  })

  it('ignores a match without routeId (a gated route) and an unknown one', () => {
    const gated: CountableState = { matches: [{ params: {}, route: {} }] }
    expect(toCountHit(gated, HOST, '', true)).toBeNull()
    const unknown: CountableState = {
      matches: [{ params: {}, route: { handle: { routeId: 'nope' } } }],
    }
    expect(toCountHit(unknown, HOST, '', true)).toBeNull()
    expect(toCountHit({ matches: [] }, HOST, '', true)).toBeNull()
  })

  it('counts the home page as the bare host', () => {
    expect(hitAt('/')!.p).toBe(`/${HOST}`)
  })
})
