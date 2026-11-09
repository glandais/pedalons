import { describe, it, expect, vi, beforeEach } from 'vitest'
import { act, renderHook } from '@testing-library/react'
import type { ReactNode } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TripDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: { defaultValue?: string }) =>
      key === 'errors.api.TRIP_FINISHED' ? 'Ce voyage est terminé' : (options?.defaultValue ?? key),
  }),
}))
vi.mock('@mantine/notifications', () => ({ notifications: { show: vi.fn() } }))

type MutateOptions = {
  onSuccess?: () => void
  onError?: (cause: unknown) => void
  onSettled?: () => void
}
const calls: { join: MutateOptions[]; leave: MutateOptions[] } = { join: [], leave: [] }

vi.mock('@/api/endpoints/trips/trips', async (importActual) => {
  const actual = await importActual<typeof import('@/api/endpoints/trips/trips')>()
  return {
    ...actual,
    useJoinTrip: () => ({ mutate: (_: unknown, o: MutateOptions) => calls.join.push(o) }),
    useLeaveTrip: () => ({ mutate: (_: unknown, o: MutateOptions) => calls.leave.push(o) }),
  }
})

import { getGetTripQueryKey } from '@/api/endpoints/trips/trips'
import { useTripMembership } from './useTripMembership'

const key = getGetTripQueryKey('team', 'vosges')

function setup(trip: Partial<TripDto>) {
  const queryClient = new QueryClient()
  queryClient.setQueryData(key, { participantCount: 3, registered: false, ...trip } as TripDto)
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
  const hook = renderHook(() => useTripMembership('team', 'vosges'), { wrapper })
  return { queryClient, hook }
}

describe('useTripMembership', () => {
  beforeEach(() => {
    calls.join = []
    calls.leave = []
  })

  it('counts the reader in before the server answers', () => {
    const { queryClient, hook } = setup({})
    act(() => hook.result.current.join())

    const trip = queryClient.getQueryData<TripDto>(key)
    expect(trip?.registered).toBe(true)
    expect(trip?.participantCount).toBe(4)
  })

  it('rolls back and says why when the trip is over (TRIP_FINISHED)', () => {
    const { queryClient, hook } = setup({})
    act(() => hook.result.current.join())
    act(() => calls.join[0].onError?.(new ApiClientError(409, { code: 'TRIP_FINISHED' })))

    const trip = queryClient.getQueryData<TripDto>(key)
    expect(trip?.registered).toBe(false)
    expect(trip?.participantCount).toBe(3)
    expect(hook.result.current.error).toBe('Ce voyage est terminé')
  })

  it('counts the reader out on leaving', () => {
    const { queryClient, hook } = setup({ registered: true })
    act(() => hook.result.current.leave())

    const trip = queryClient.getQueryData<TripDto>(key)
    expect(trip?.registered).toBe(false)
    expect(trip?.participantCount).toBe(2)
  })

  it('refetches what shows the registration once settled', () => {
    const { queryClient, hook } = setup({})
    const invalidate = vi.spyOn(queryClient, 'invalidateQueries')
    act(() => hook.result.current.join())
    act(() => calls.join[0].onSettled?.())

    const keys = invalidate.mock.calls.map(([filters]) => JSON.stringify(filters?.queryKey))
    expect(keys).toContain(JSON.stringify(key))
    expect(keys.some((k) => k.includes('participants'))).toBe(true)
    expect(keys.some((k) => k.includes('weather'))).toBe(true)
  })
})
