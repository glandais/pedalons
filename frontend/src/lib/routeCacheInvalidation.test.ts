import { describe, expect, it } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import {
  getCountAllRoutesQueryKey,
  getCountRoutesQueryKey,
  getGetAllRoutesBoundsQueryKey,
  getGetRoutesBoundsQueryKey,
  getListAllRoutesQueryKey,
  getListRoutesQueryKey,
} from '@/api/endpoints/routes/routes'
import { invalidateRouteQueries } from './routeCacheInvalidation'

describe('invalidateRouteQueries', () => {
  it('reaches the cross-team route list, count and bounds, whatever their filters', () => {
    const queryClient = new QueryClient()
    const keys = [
      getListRoutesQueryKey('velo', { page: 0 }),
      getCountRoutesQueryKey('velo', {}),
      getGetRoutesBoundsQueryKey('velo', {}),
      getListAllRoutesQueryKey({ page: 1 }),
      getCountAllRoutesQueryKey({}),
      getGetAllRoutesBoundsQueryKey({}),
    ]
    for (const key of keys) queryClient.setQueryData(key, {})

    invalidateRouteQueries(queryClient, 'velo')

    for (const key of keys) {
      expect(queryClient.getQueryState(key)?.isInvalidated, JSON.stringify(key)).toBe(true)
    }
  })

  it('leaves another team alone', () => {
    const queryClient = new QueryClient()
    const other = getListRoutesQueryKey('autre')
    queryClient.setQueryData(other, {})

    invalidateRouteQueries(queryClient, 'velo')

    expect(queryClient.getQueryState(other)?.isInvalidated).toBe(false)
  })
})
