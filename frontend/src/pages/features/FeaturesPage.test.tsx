import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import { paths } from '@/config/paths'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))

// Keys, not wording: the assertions read which text is shown, not how it is phrased.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

const auth = { isAuthenticated: false }
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => auth }))

let singleTeam = false
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => singleTeam }))

const generator: { team: { slug: string } | undefined; isPending: boolean } = {
  team: undefined,
  isPending: false,
}
vi.mock('./featuresData', () => ({ useGeneratorTeam: () => generator }))

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
  generator.team = undefined
  generator.isPending = false
})

describe('FeaturesPage', () => {
  it('renders every section, each reachable from its jump chip', () => {
    renderPage()
    const chips = within(screen.getByRole('navigation', { name: 'features.jump.label' }))
    const ids = ['rides', 'groups', 'routes', 'weather', 'devices', 'trips', 'more', 'roles']
    expect(chips.getAllByRole('link').map((a) => a.getAttribute('href'))).toEqual(
      ids.map((id) => `#${id}`)
    )
    for (const id of ids) {
      expect(document.getElementById(id)).toBeInTheDocument()
    }
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('features.hero.title')
  })

  it('draws the generator as it is: direction grid, two proposals to open in the editor', () => {
    renderPage()
    const routes = document.getElementById('routes')!
    expect(within(routes).getAllByText('routeGenerator.card.open')).toHaveLength(2)
    expect(within(routes).getAllByText('routeGenerator.card.title')).toHaveLength(2)
    expect(within(routes).getByText('routeGenerator.bearing.label')).toBeInTheDocument()
    expect(within(routes).queryByText('routeGenerator.card.use')).toBeNull()
  })

  it("shows the ride's group cards and a group's own page, counts only", () => {
    renderPage()
    const rides = within(document.getElementById('rides')!)
    expect(rides.queryByText('rides.detail.groups.join')).toBeNull()
    expect(rides.getAllByText('rides.detail.groups.switchTo')).toHaveLength(1)
    expect(rides.getAllByText('rides.detail.groups.joined')).toHaveLength(1)
    expect(rides.getAllByText('rides.detail.groups.full')).toHaveLength(1)
    expect(rides.getAllByTestId('group-count')).toHaveLength(3)
    const groups = within(document.getElementById('groups')!)
    expect(groups.getByText('rides.group.participantsTitle')).toBeInTheDocument()
    expect(groups.getByText('routes.gps.button')).toBeInTheDocument()
    const weather = within(document.getElementById('weather')!)
    expect(weather.getByText('rides.weather.route.timeline.title')).toBeInTheDocument()
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
    expect(hrefs).toEqual(['#routes', '#routes', '#devices', '#groups'])
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

  // `hidden`: the sticky bar is hidden by CSS at jsdom's viewport width, yet in the markup.
  const links = (name: string) => screen.queryAllByRole('link', { name, hidden: true })

  it('offers browsing and sign-in in the hero to a visitor, sign-up in the final band and sticky bar', () => {
    renderPage()
    expect(links('features.cta.browseTeams').length).toBe(2)
    expect(links('features.cta.signUp').length).toBe(2)
    expect(links('features.cta.signIn').length).toBe(2)
    expect(links('features.cta.generate').length).toBe(0)
    expect(links('features.cta.backToFeed').length).toBe(0)
  })

  it('keeps the hero sign-up on a single-team site', () => {
    singleTeam = true
    renderPage()
    expect(links('features.cta.signUp').length).toBe(3)
    expect(links('features.cta.signIn').length).toBe(2)
    expect(links('features.cta.browseTeams').length).toBe(0)
  })

  it('opens the generator of a member who may generate', () => {
    auth.isAuthenticated = true
    generator.team = { slug: 'vc-craponne' }
    renderPage()
    expect(screen.getByRole('link', { name: /features\.cta\.generate/ })).toHaveAttribute(
      'href',
      paths.routeGenerate('vc-craponne')
    )
    expect(links('features.cta.browseTeams').length).toBe(2)
    expect(links('features.cta.backToFeed').length).toBe(1)
    expect(links('features.cta.signUp').length).toBe(0)
    expect(links('features.cta.signIn').length).toBe(0)
  })

  it('opens the generator of a member with a generator team on a single-team site', () => {
    auth.isAuthenticated = true
    singleTeam = true
    generator.team = { slug: 'x' }
    renderPage()
    expect(screen.getByRole('link', { name: /features\.cta\.generate/ })).toHaveAttribute(
      'href',
      paths.routeGenerate('x')
    )
    expect(links('features.cta.browseTeams').length).toBe(0)
  })

  it('falls back to browsing teams for a member with no generator team', () => {
    auth.isAuthenticated = true
    renderPage()
    expect(links('features.cta.generate').length).toBe(0)
    expect(links('features.cta.browseTeams').length).toBe(2)
    expect(links('features.cta.backToFeed').length).toBe(1)
  })

  it('shows nothing extra to such a member on a single-team site', () => {
    auth.isAuthenticated = true
    singleTeam = true
    renderPage()
    expect(links('features.cta.generate').length).toBe(0)
    expect(links('features.cta.browseTeams').length).toBe(0)
    expect(links('features.cta.backToFeed').length).toBe(1)
  })

  it('holds the hero buttons back while the team listing loads', () => {
    auth.isAuthenticated = true
    generator.isPending = true
    renderPage()
    const hero = within(document.querySelector<HTMLElement>('.features-hero')!)
    expect(hero.queryByRole('link', { name: /features\.cta\.generate/ })).toBeNull()
    expect(hero.queryByRole('link', { name: /features\.cta\.browseTeams/ })).toBeNull()
  })

  it('draws the GPS and privacy pastilles with readable variants', () => {
    renderPage()
    const gps = document.getElementById('devices')!.querySelector('.mantine-ThemeIcon-root')!
    expect(gps).toHaveAttribute('data-variant', 'light')
    expect(gps.getAttribute('style') ?? '').not.toContain('gray')
    const icons = document.getElementById('more')!.querySelectorAll('.mantine-ThemeIcon-root')
    expect(icons[3]).toHaveAttribute('data-variant', 'default')
  })

  it('renders its illustrations inert: hidden from assistive tech, nothing focusable', () => {
    const { container } = renderPage()
    const frames = container.querySelectorAll('[aria-hidden="true"]')
    expect(frames.length).toBeGreaterThanOrEqual(6)
    const groupsText = within(document.getElementById('groups')!).getByText(
      'rides.group.participantsTitle'
    )
    expect(groupsText.closest('[aria-hidden="true"]')).not.toBeNull()
    for (const frame of frames) {
      expect(frame.querySelector('a, button, input, [tabindex]')).toBeNull()
    }
  })
})
