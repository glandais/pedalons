import { describe, expect, it, vi } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import { getGetTripQueryKey, getGetTripWeatherQueryKey } from '@/api/endpoints/trips/trips'
import { getGetRouteQueryKey } from '@/api/endpoints/routes/routes'

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

import { prefetchStageMap } from './stageMapData'

describe('prefetchStageMap (WEB-118)', () => {
  it("reads the team, the trip, its weather (the stage's Météo mode), then the stage's route", async () => {
    requests.responses['/api/teams/np/trips/voyage'] = {
      slug: 'voyage',
      stages: [{ id: 's1', slug: 'etape-1', route: { slug: 'aller' } }],
    }
    const queryClient = new QueryClient()
    await prefetchStageMap(queryClient, 'np', 'voyage', 'etape-1')
    expect(queryClient.getQueryState(getGetTripQueryKey('np', 'voyage'))?.status).toBe('success')
    // The stage page's own key: going from the stage to its map reads nothing twice
    expect(queryClient.getQueryState(getGetTripWeatherQueryKey('np', 'voyage'))?.status).toBe(
      'success'
    )
    expect(queryClient.getQueryState(getGetRouteQueryKey('np', 'aller'))?.status).toBe('success')
    expect(requests.urls.some((u) => u.endsWith('/comments'))).toBe(false)
  })
})
