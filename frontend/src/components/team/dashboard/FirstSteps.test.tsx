import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { FirstStepsState } from '@/pages/team/teamHomeData'
import { paths } from '@/config/paths'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys and their params, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) =>
      options ? `${key}:${JSON.stringify(options)}` : key,
    i18n: { language: 'fr' },
  }),
}))

import { FirstSteps } from './FirstSteps'

/**
 * « Premières étapes » (docs/LEDGER_*.md WEB-195): what each step leads to, how it ticks, and how
 * the list goes — all three done, or closed by hand.
 */
const store = new Map<string, string>()

beforeEach(() => {
  vi.stubGlobal('localStorage', {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => void store.set(key, value),
  })
})

afterEach(() => {
  cleanup()
  store.clear()
  vi.unstubAllGlobals()
})

function renderSteps(state: FirstStepsState) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <FirstSteps teamId="t1" teamSlug="vc-craponne" state={state} />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

function step(key: string): HTMLElement {
  const item = document.querySelector<HTMLElement>(`[data-step="${key}"]`)
  if (!item) throw new Error(`no step ${key}`)
  return item
}

describe('FirstSteps', () => {
  it('a new team: the three steps, in order, each leading to its screen', () => {
    renderSteps({ invite: false, ride: false, route: false })

    expect(screen.getByRole('heading', { name: 'teams.dashboard.firstSteps.title' })).toBeVisible()
    expect(
      Array.from(document.querySelectorAll('[data-step]')).map((el) => el.getAttribute('data-step'))
    ).toEqual(['invite', 'ride', 'route'])
    expect(step('invite').querySelector('a')).toHaveAttribute(
      'href',
      paths.teamAdminMembers('vc-craponne')
    )
    expect(step('ride').querySelector('a')).toHaveAttribute('href', paths.rideNew('vc-craponne'))
    expect(step('route').querySelector('a')).toHaveAttribute('href', paths.routeNew('vc-craponne'))
    expect(screen.getByText(/firstSteps\.progress:.*"done":0,"total":3/)).toBeVisible()
  })

  it('a done step is ticked and leads nowhere', () => {
    renderSteps({ invite: true, ride: false, route: false })

    expect(step('invite')).toHaveAttribute('data-done', 'true')
    expect(step('invite').querySelector('a')).toBeNull()
    expect(step('ride').querySelector('a')).not.toBeNull()
    expect(screen.getByText(/"done":1,"total":3/)).toBeVisible()
  })

  it('a team that may not invite by e-mail has no invite step', () => {
    renderSteps({ ride: false, route: true })

    expect(document.querySelector('[data-step="invite"]')).toBeNull()
    expect(screen.getByText(/"done":1,"total":2/)).toBeVisible()
  })

  it('all done: the list is gone', () => {
    renderSteps({ invite: true, ride: true, route: true })

    expect(screen.queryByRole('heading', { name: 'teams.dashboard.firstSteps.title' })).toBeNull()
  })

  it('closed by hand: gone, and still gone on the next visit', () => {
    renderSteps({ invite: false, ride: false, route: false })
    fireEvent.click(screen.getByRole('button', { name: 'teams.dashboard.firstSteps.dismiss' }))

    expect(screen.queryByRole('heading', { name: 'teams.dashboard.firstSteps.title' })).toBeNull()
    cleanup()

    renderSteps({ invite: false, ride: false, route: false })
    expect(screen.queryByRole('heading', { name: 'teams.dashboard.firstSteps.title' })).toBeNull()
  })
})
