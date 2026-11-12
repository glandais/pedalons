import { describe, expect, it, vi } from 'vitest'
import { act, renderHook } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { ErrorCode, RideDto } from '@/api/dto'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { ApiClientError } from '@/lib/apiError'

const failWith = vi.hoisted(() => ({ code: undefined as string | undefined }))

vi.mock('@mantine/notifications', () => ({ notifications: { show: vi.fn() } }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/api/endpoints/rides/rides', async (importOriginal) => {
  const failing = () => ({
    isPending: false,
    mutate: (_vars: unknown, handlers: { onError: (e: unknown) => void }) =>
      handlers.onError(
        failWith.code
          ? new ApiClientError(409, { code: failWith.code as ErrorCode })
          : new Error('réseau')
      ),
  })
  return {
    ...(await importOriginal<typeof import('@/api/endpoints/rides/rides')>()),
    useJoinGroup: failing,
    useLeaveGroup: failing,
    useSwitchGroup: failing,
  }
})

import { useRideGroupMembership } from './useRideGroupMembership'

function failedMessage(code: string | undefined) {
  failWith.code = code
  const queryClient = new QueryClient()
  queryClient.setQueryData(getGetRideQueryKey('vcm', 'boucle'), {
    groups: [{ id: 'g-b', name: 'B', registered: false, countParticipants: 11 }],
  } as unknown as RideDto)
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
  const { result } = renderHook(() => useRideGroupMembership('vcm', 'boucle'), { wrapper })
  act(() => result.current.join('g-b'))
  return result.current.error
}

// R6 (docs/LEDGER_*.md WEB-167): the app's words, what happened then what can be done, kept on the
// group acted on — its card shows it.
describe('useRideGroupMembership — the failure of a card', () => {
  it('says a full group is full, and to choose another', () => {
    expect(failedMessage('GROUP_FULL')).toEqual({
      groupId: 'g-b',
      message: 'Ce groupe est complet. Choisissez un autre groupe.',
    })
  })

  it('points a reader registered elsewhere at « Changer pour »', () => {
    expect(failedMessage('ALREADY_REGISTERED')?.message).toBe(
      'Vous participez déjà à cette sortie, dans un autre groupe. Changez de groupe avec « Changer pour Groupe B ».'
    )
  })

  it('names any other refusal, then « Réessayez »', () => {
    expect(failedMessage('RIDE_PAST')?.message).toBe(
      "Cette sortie est passée : on ne peut plus s'y inscrire. Réessayez."
    )
  })

  it('falls back on the generic message without a code', () => {
    expect(failedMessage(undefined)?.message).toBe(
      "L'inscription n'a pas pu être enregistrée. Réessayez."
    )
  })
})
