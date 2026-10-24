import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter, Route, Routes } from 'react-router-dom'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('@/store/authStore', () => ({
  useAuthStore: (select: (s: unknown) => unknown) =>
    select({ isAuthenticated: true, logout: vi.fn() }),
}))

const accept = vi.fn()
vi.mock('@/api/endpoints/invitations/invitations', () => ({
  preview: () =>
    Promise.resolve({
      teamSlug: 'vc-craponne',
      teamName: 'VC Craponne',
      inviterName: 'Camille',
      role: 'MEMBER',
      maskedEmail: 'c***@example.org',
      redeemable: true,
    }),
  accept: (...args: unknown[]) => accept(...args),
}))

import { AcceptInvitationPage } from './AcceptInvitationPage'
import { getListTeamsQueryKey } from '@/api/endpoints/teams/teams'
import { MY_TEAMS_PARAMS } from '@/pages/home/homeFeedData'

afterEach(() => {
  cleanup()
  accept.mockReset()
})

describe('AcceptInvitationPage', () => {
  it('invalidates the teams listings on accepting: the team switcher shows the new team (WEB-111)', async () => {
    accept.mockResolvedValue({})
    const client = new QueryClient()
    // The « my teams » listing the home and the team switcher share, cached before joining.
    client.setQueryData(getListTeamsQueryKey(MY_TEAMS_PARAMS), { teams: [] })

    render(
      <MantineProvider>
        <QueryClientProvider client={client}>
          <MemoryRouter initialEntries={['/invitation?token=abc']}>
            <Routes>
              <Route path="/invitation" element={<AcceptInvitationPage />} />
              <Route path="*" element={<p>team page</p>} />
            </Routes>
          </MemoryRouter>
        </QueryClientProvider>
      </MantineProvider>
    )

    fireEvent.click(await screen.findByRole('button', { name: 'invitations.accept.join' }))

    await waitFor(() => expect(accept).toHaveBeenCalledWith({ token: 'abc' }))
    await waitFor(() =>
      expect(client.getQueryState(getListTeamsQueryKey(MY_TEAMS_PARAMS))?.isInvalidated).toBe(true)
    )
  })
})
