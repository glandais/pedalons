import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

const auth = { isAuthenticated: false }
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

let singleTeam = false
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => singleTeam }))

import { HeaderMainNav } from './MainNav'
import { paths } from '@/config/paths'

function renderAt(path: string) {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={[path]}>
          <HeaderMainNav />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
  return within(screen.getByRole('navigation', { name: 'nav.landmark.home' }))
}

const linkNames = (nav: ReturnType<typeof renderAt>) =>
  nav.getAllByRole('link').map((link) => link.getAttribute('aria-label'))

const current = (nav: ReturnType<typeof renderAt>) =>
  nav
    .queryAllByRole('link')
    .filter((link) => link.getAttribute('aria-current') === 'page')
    .map((link) => link.getAttribute('aria-label'))

afterEach(() => {
  cleanup()
  auth.isAuthenticated = false
  singleTeam = false
})

describe('HeaderMainNav', () => {
  it('lists the home section, the calendar only when signed in, the features page for a visitor, the GPX tools for a member', () => {
    expect(linkNames(renderAt(paths.home()))).toEqual([
      'home.tabs.feed',
      'teams.title',
      'nav.explore',
      'nav.features',
    ])
    cleanup()
    auth.isAuthenticated = true
    expect(linkNames(renderAt(paths.home()))).toEqual([
      'home.tabs.feed',
      'teams.title',
      'calendar.title',
      'nav.explore',
      'gpxTools.title',
    ])
  })

  it('opens « Explorer » on the routes map, not the list (WEB-114)', () => {
    const nav = renderAt(paths.home())
    expect(nav.getByRole('link', { name: 'nav.explore' }).getAttribute('href')).toBe(
      paths.allRoutesMap()
    )
  })

  it('drops the teams entry on a single-team site', () => {
    singleTeam = true
    expect(linkNames(renderAt(paths.home()))).not.toContain('teams.title')
  })

  it('marks the section of the current page, sub-routes included', () => {
    auth.isAuthenticated = true
    expect(current(renderAt(paths.home()))).toEqual(['home.tabs.feed'])
    cleanup()
    expect(current(renderAt(paths.allRoutesMap()))).toEqual(['nav.explore'])
    cleanup()
    expect(current(renderAt(paths.allRoutes()))).toEqual(['nav.explore'])
    cleanup()
    expect(current(renderAt(paths.team('les-velos')))).toEqual(['teams.title'])
    cleanup()
    expect(current(renderAt(paths.calendar()))).toEqual(['calendar.title'])
    cleanup()
    expect(current(renderAt(paths.gpxToolsList()))).toEqual(['gpxTools.title'])
    cleanup()
    auth.isAuthenticated = false
    expect(current(renderAt(paths.features()))).toEqual(['nav.features'])
  })

  it('marks nothing off the sections', () => {
    auth.isAuthenticated = true
    expect(current(renderAt(paths.profile()))).toEqual([])
  })
})
