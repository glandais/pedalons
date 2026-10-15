// @vitest-environment-options { "url": "https://club-exemple.fr/" }
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createMemoryRouter, replace, type RouteObject } from 'react-router-dom'
import type { ConfigDto } from '@/api/dto'
import { seedAppConfig } from '@/config/appConfig'
import { installPageViewCounter, SEND_DELAY_MS } from './pageViewCounter'

/**
 * When a page view is counted (docs/plans/2026-10-15-web-analytics.md §4.1, docs/LEDGER_*.md
 * WEB-90), on a memory data router shaped like the app's: routes carry `handle.routeId` from
 * routes.config.ts, a gated route carries none, the catch-all is `not-found`.
 */

const HOST = 'club-exemple.fr'

let fetchMock: ReturnType<typeof vi.fn>
let releaseHome: (() => void) | undefined

function routes(options: { slowHome?: boolean } = {}): RouteObject[] {
  return [
    {
      id: 'home',
      path: '/',
      handle: { routeId: 'home' },
      loader: options.slowHome
        ? () => new Promise<null>((resolve) => (releaseHome = () => resolve(null)))
        : () => null,
      element: null,
    },
    { path: '/applications', handle: { routeId: 'apps' }, element: null },
    { path: '/fonctionnalites', handle: { routeId: 'features' }, element: null },
    { path: '/equipes/:teamSlug/sorties', handle: { routeId: 'team-rides' }, element: null },
    {
      // A former address: its loader replaces it, as teamLegacyRedirects does.
      path: '/equipes/:teamSlug/fil',
      handle: { routeId: 'team-posts' },
      loader: ({ params }) => {
        throw replace(`/equipes/${params.teamSlug}/sorties`)
      },
      element: null,
    },
    // Gated on a single-team site: no handle, and a <Navigate replace> home once rendered.
    { path: '/equipes', element: null },
    { path: '/profil/vie-privee', handle: { routeId: 'profile-privacy' }, element: null },
    { path: '/connexion', handle: { routeId: 'login' }, element: null },
    { path: '/sans-handle', element: null },
    { path: '*', handle: { routeId: 'not-found' }, element: null },
  ]
}

/** The `p` of every hit sent so far. */
function sentPaths(): string[] {
  return fetchMock.mock.calls.map(([url]) => {
    const params = new URL(url as string, `https://${HOST}`).searchParams
    return params.get('p')!
  })
}

const settle = () => vi.advanceTimersByTimeAsync(SEND_DELAY_MS + 1)

beforeEach(() => {
  vi.useFakeTimers()
  fetchMock = vi.fn(() => Promise.resolve(new Response(null, { status: 200 })))
  vi.stubGlobal('fetch', fetchMock)
  Object.defineProperty(navigator, 'webdriver', { value: false, configurable: true })
  seedAppConfig({ analytics: { countPath: '/count' } } as unknown as ConfigDto)
  releaseHome = undefined
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
  seedAppConfig({} as ConfigDto)
})

describe('the first page view', () => {
  it('is counted from the state at creation when hydrated from SSR', async () => {
    const router = createMemoryRouter(routes(), {
      initialEntries: ['/'],
      hydrationData: { loaderData: { home: null } },
    })
    expect(router.state.initialized).toBe(true)
    const stop = installPageViewCounter(router)
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}`])
    stop()
    router.dispose()
  })

  it('is counted once the router initializes, without hydration data', async () => {
    const router = createMemoryRouter(routes({ slowHome: true }), { initialEntries: ['/'] })
    expect(router.state.initialized).toBe(false)
    const stop = installPageViewCounter(router)
    await settle()
    expect(sentPaths()).toEqual([])
    releaseHome!()
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}`])
    stop()
    router.dispose()
  })

  it('carries the external referrer, and the next one does not', async () => {
    Object.defineProperty(document, 'referrer', {
      value: 'https://www.google.fr/search?q=velo',
      configurable: true,
    })
    try {
      const router = createMemoryRouter(routes(), {
        initialEntries: ['/'],
        hydrationData: { loaderData: { home: null } },
      })
      const stop = installPageViewCounter(router)
      await settle()
      await router.navigate('/applications')
      await settle()
      const referrers = fetchMock.mock.calls.map(([url]) =>
        new URL(url as string, `https://${HOST}`).searchParams.get('r')
      )
      expect(referrers).toEqual(['https://www.google.fr', null])
      stop()
      router.dispose()
    } finally {
      Object.defineProperty(document, 'referrer', { value: '', configurable: true })
    }
  })
})

describe('navigations', () => {
  async function started() {
    const router = createMemoryRouter(routes(), {
      initialEntries: ['/'],
      hydrationData: { loaderData: { home: null } },
    })
    const stop = installPageViewCounter(router)
    await settle()
    fetchMock.mockClear()
    return {
      router,
      done: () => {
        stop()
        router.dispose()
      },
    }
  }

  it('counts one hit per PUSH', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await settle()
    await router.navigate('/fonctionnalites')
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/applications`, `/${HOST}/fonctionnalites`])
    done()
  })

  it('counts one hit per POP', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await settle()
    fetchMock.mockClear()
    await router.navigate(-1)
    await settle()
    expect(router.state.historyAction).toBe('POP')
    expect(sentPaths()).toEqual([`/${HOST}`])
    done()
  })

  it('counts no REPLACE on the same route (a filter edit)', async () => {
    const { router, done } = await started()
    await router.navigate('/equipes/equipe-privee/sorties')
    await settle()
    fetchMock.mockClear()
    await router.navigate('/equipes/equipe-privee/sorties?page=2', { replace: true })
    await settle()
    expect(router.state.historyAction).toBe('REPLACE')
    expect(sentPaths()).toEqual([])
    done()
  })

  it('counts a REPLACE that changes the route', async () => {
    const { router, done } = await started()
    await router.navigate('/applications', { replace: true })
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/applications`])
    done()
  })

  it('counts the arrival of a loader redirect, once', async () => {
    const { router, done } = await started()
    await router.navigate('/equipes/equipe-privee/fil')
    await settle()
    expect(router.state.location.pathname).toBe('/equipes/equipe-privee/sorties')
    expect(sentPaths()).toEqual([`/${HOST}/equipes/equipe-privee/sorties`])
    done()
  })

  it('counts a loader redirect that lands back on the route it left', async () => {
    const { router, done } = await started()
    await router.navigate('/equipes/x/sorties')
    await settle()
    fetchMock.mockClear()
    // team-rides of x → a former address of y → team-rides of y: same routeId, recorded as REPLACE.
    await router.navigate('/equipes/y/fil')
    await settle()
    expect(router.state.historyAction).toBe('REPLACE')
    expect(router.state.location.pathname).toBe('/equipes/y/sorties')
    expect(sentPaths()).toEqual([`/${HOST}/equipes/y/sorties`])
    done()
  })

  it('counts both of two PUSHes within the delay, in order', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await vi.advanceTimersByTimeAsync(SEND_DELAY_MS / 2)
    await router.navigate('/fonctionnalites')
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/applications`, `/${HOST}/fonctionnalites`])
    done()
  })

  it('gives a PUSH that follows another its full delay before a component redirect', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await vi.advanceTimersByTimeAsync(SEND_DELAY_MS / 2)
    await router.navigate('/profil/vie-privee')
    // Past the first PUSH's deadline, within the second's.
    await vi.advanceTimersByTimeAsync(SEND_DELAY_MS * 0.75)
    await router.navigate('/connexion', { replace: true })
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/applications`, `/${HOST}/connexion`])
    done()
  })

  it('counts one hit for a gated route that redirects home', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await settle()
    fetchMock.mockClear()
    await router.navigate('/equipes')
    // What <Navigate to={paths.home()} replace /> does once the gated route renders.
    await router.navigate('/', { replace: true })
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}`])
    done()
  })

  it('counts one hit for a members-only page visited without a session', async () => {
    const { router, done } = await started()
    await router.navigate('/profil/vie-privee')
    // ProtectedRoute's <Navigate to={paths.login()} replace />, within the delay.
    await vi.advanceTimersByTimeAsync(SEND_DELAY_MS / 2)
    await router.navigate('/connexion', { replace: true })
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/connexion`])
    done()
  })

  it('counts /404 for the catch-all only, and nothing for a route without routeId', async () => {
    const { router, done } = await started()
    await router.navigate('/adresse/inconnue?token=SECRET')
    await settle()
    await router.navigate('/sans-handle')
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/404`])
    done()
  })

  it('counts a location key once', async () => {
    const { router, done } = await started()
    await router.navigate('/applications')
    await settle()
    // A revalidation keeps the location: no second hit.
    await router.revalidate()
    await settle()
    expect(sentPaths()).toEqual([`/${HOST}/applications`])
    done()
  })
})

describe('without the analytics config', () => {
  it('installs nothing', async () => {
    seedAppConfig({} as ConfigDto)
    const router = createMemoryRouter(routes(), {
      initialEntries: ['/'],
      hydrationData: { loaderData: { home: null } },
    })
    const subscribe = vi.spyOn(router, 'subscribe')
    installPageViewCounter(router)
    await router.navigate('/applications')
    await settle()
    expect(subscribe).not.toHaveBeenCalled()
    expect(fetchMock).not.toHaveBeenCalled()
    router.dispose()
  })
})
