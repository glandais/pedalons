import { describe, expect, it } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import { makeLoader } from './RouteGenerator'
import type { RouteConfig } from './routes.types'

function route(overrides: Partial<RouteConfig>): RouteConfig {
  return {
    id: 'test-route',
    paths: { fr: '/test/:rideSlug', en: '/test/:rideSlug' },
    component: () => null,
    auth: 'public',
    parentId: null,
    ...overrides,
  }
}

const request = new Request('https://pedalons.fr/test/sortie?q=a')

describe('the route loader (WEB-79)', () => {
  it('redirects where `dataRedirect` reads, from the cache `prefetch` filled — never 301', async () => {
    const queryClient = new QueryClient()
    const loader = makeLoader(
      route({
        prefetch: async (qc, params) => {
          qc.setQueryData(['ride', params.rideSlug], { moved: '/ailleurs' })
        },
        dataRedirect: (qc, params, url) =>
          qc.getQueryData<{ moved: string }>(['ride', params.rideSlug])!.moved + url.search,
      }),
      queryClient
    )
    const thrown = await loader({ request, params: { rideSlug: 'sortie' } }).catch(
      (e: unknown) => e
    )
    expect(thrown).toBeInstanceOf(Response)
    expect((thrown as Response).status).toBe(302)
    expect((thrown as Response).headers.get('Location')).toBe('/ailleurs?q=a')
  })

  it('renders when `dataRedirect` names nothing, or there is none', async () => {
    const queryClient = new QueryClient()
    const prefetch = async () => {}
    await expect(
      makeLoader(
        route({ prefetch, dataRedirect: () => undefined }),
        queryClient
      )({
        request,
        params: {},
      })
    ).resolves.toBeNull()
    await expect(
      makeLoader(route({ prefetch }), queryClient)({ request, params: {} })
    ).resolves.toBeNull()
  })
})
