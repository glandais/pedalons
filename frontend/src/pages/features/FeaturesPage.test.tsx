import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording: the assertions read which text is shown, not how it is phrased.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

const auth = { isAuthenticated: false }
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

let singleTeam = false
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => singleTeam }))

import { FeaturesPage } from './FeaturesPage'

function renderPage() {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter initialEntries={['/fonctionnalites']}>
          <FeaturesPage />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

afterEach(() => {
  cleanup()
  auth.isAuthenticated = false
  singleTeam = false
})

describe('FeaturesPage', () => {
  it('renders every section, each reachable from its jump chip', () => {
    renderPage()
    const chips = within(screen.getByRole('navigation', { name: 'features.jump.label' }))
    const ids = ['rides', 'routes', 'weather', 'devices', 'trips', 'more', 'roles']
    expect(chips.getAllByRole('link').map((a) => a.getAttribute('href'))).toEqual(
      ids.map((id) => `#${id}`)
    )
    for (const id of ids) {
      expect(document.getElementById(id)).toBeInTheDocument()
    }
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('features.hero.title')
  })

  it('presents the GPS feature by its points, not by a list of makes', () => {
    renderPage()
    const devices = document.getElementById('devices')!
    for (const key of [
      'features.devices.point1',
      'features.devices.point2',
      'features.devices.point3',
      'features.devices.point4',
    ]) {
      expect(within(devices).getAllByText(key).length).toBeGreaterThan(0)
    }
  })

  it('links each « what is new » card to its section', () => {
    renderPage()
    const news = screen.getByRole('heading', { level: 2, name: 'features.news.title' })
      .parentElement!.parentElement!
    const hrefs = within(news)
      .getAllByRole('link')
      .map((a) => a.getAttribute('href'))
    expect(hrefs).toEqual(['#routes', '#routes', '#devices', '#rides'])
  })

  it('shows the routes chapter: three ways and the library', () => {
    renderPage()
    const routes = document.getElementById('routes')!
    for (const key of [
      'features.routes.generate.title',
      'features.routes.trace.title',
      'features.routes.retouch.title',
      'features.routes.library.point6',
    ]) {
      expect(within(routes).getAllByText(key).length).toBeGreaterThan(0)
    }
  })

  it('offers sign-up and sign-in to a visitor, sticky bar included', () => {
    renderPage()
    // `hidden`: the sticky bar is hidden by CSS at jsdom's viewport width, yet in the markup.
    const links = (name: string) => screen.getAllByRole('link', { name, hidden: true })
    expect(links('features.cta.signUp').length).toBe(3)
    expect(links('features.cta.signIn').length).toBe(2)
    expect(screen.queryByRole('link', { name: 'features.cta.backToFeed' })).toBeNull()
    expect(screen.getByRole('link', { name: 'features.cta.browseTeams' })).toBeInTheDocument()
  })

  it('sends a signed-in member back to the feed instead', () => {
    auth.isAuthenticated = true
    renderPage()
    expect(screen.queryByRole('link', { name: 'features.cta.signUp' })).toBeNull()
    expect(screen.queryByRole('link', { name: 'features.cta.signIn' })).toBeNull()
    expect(screen.getAllByRole('link', { name: /features\.cta\.backToFeed/ }).length).toBe(2)
  })

  it('hides team browsing on a single-team site', () => {
    singleTeam = true
    renderPage()
    expect(screen.queryByRole('link', { name: 'features.cta.browseTeams' })).toBeNull()
  })

  it('renders its illustrations inert: hidden from assistive tech, nothing focusable', () => {
    const { container } = renderPage()
    const frames = container.querySelectorAll('[aria-hidden="true"]')
    expect(frames.length).toBeGreaterThanOrEqual(5)
    for (const frame of frames) {
      expect(frame.querySelector('a, button, input, [tabindex]')).toBeNull()
    }
  })
})
