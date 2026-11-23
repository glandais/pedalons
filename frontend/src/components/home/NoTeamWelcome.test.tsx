import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { MyInvitationDto } from '@/api/dto'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys and their params, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) =>
      options ? `${key}:${JSON.stringify(options)}` : key,
    i18n: { language: 'fr' },
  }),
}))

const app = vi.hoisted(() => ({ singleTeam: false }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => app.singleTeam }))

const invitations = vi.hoisted(() => ({ list: [] as MyInvitationDto[] }))
vi.mock('@/api/endpoints/invitations/invitations', () => ({
  useListMyInvitations: () => ({ data: { invitations: invitations.list } }),
}))

const accept = vi.hoisted(() => vi.fn())
vi.mock('@/components/team/useAcceptPendingInvitation', () => ({
  useAcceptPendingInvitation: () => ({ acceptInvitation: accept, isPending: false }),
}))

import { NoTeamWelcome } from './NoTeamWelcome'

const invitation = {
  id: 'inv-1',
  team: {
    id: 't1',
    name: 'VC Craponne',
    slug: 'vc-craponne',
    visibility: 'PUBLIC',
    accessible: true,
  },
  inviterName: 'Léa',
  role: 'MEMBER',
  expiresAt: '2026-12-01T00:00:00Z',
} as MyInvitationDto

function renderWelcome() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <NoTeamWelcome />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

/** The three steps' headings or buttons, in document order. */
function stepsInOrder(): string[] {
  const block = screen.getByTestId('home-no-team')
  return Array.from(block.querySelectorAll('a, button')).map((el) => el.textContent ?? '')
}

afterEach(() => {
  cleanup()
  invitations.list = []
  app.singleTeam = false
  accept.mockReset()
})

describe('NoTeamWelcome (WEB-194)', () => {
  it('without an invitation: find a team, then create one', () => {
    renderWelcome()

    expect(stepsInOrder()).toEqual(['home.noTeam.find.action', 'home.noTeam.create.action'])
    expect(screen.getByRole('link', { name: 'home.noTeam.find.action' })).toHaveAttribute(
      'href',
      expect.stringMatching(/\?role=all$/)
    )
  })

  it('invitations first, joined on the spot', () => {
    invitations.list = [invitation]
    renderWelcome()

    expect(stepsInOrder()).toEqual([
      'home.noTeam.join',
      'home.noTeam.find.action',
      'home.noTeam.create.action',
    ])
    fireEvent.click(screen.getByRole('button', { name: /home\.noTeam\.joinTeam/ }))
    expect(accept).toHaveBeenCalledWith(invitation)
  })

  it('on a single-team site, no « find a team »', () => {
    app.singleTeam = true
    renderWelcome()

    expect(stepsInOrder()).toEqual(['home.noTeam.create.action'])
  })
})
