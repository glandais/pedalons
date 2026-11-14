import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto } from '@/api/dto'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
vi.mock('./UploadGpxFiles', () => ({ UploadGpxFiles: () => <div /> }))

import { RoutesListHeader } from './RoutesListHeader'
import { paths } from '@/config/paths'
import { useAuthStore } from '@/store/authStore'

const team = (over: Record<string, unknown> = {}) =>
  ({
    slug: 'club',
    role: 'ORGANIZER',
    enableRoutes: true,
    enableRoutePlanner: true,
    ...over,
  }) as unknown as TeamDetailDto

function renderHeader(t: TeamDetailDto) {
  render(
    <QueryClientProvider client={new QueryClient()}>
      <MantineProvider>
        <MemoryRouter>
          <RoutesListHeader team={t} />
        </MemoryRouter>
      </MantineProvider>
    </QueryClientProvider>
  )
}

const button = () => screen.queryByTestId('route-generate-button')

describe('RoutesListHeader generator button (WEB-179)', () => {
  afterEach(() => {
    cleanup()
    useAuthStore.setState({ user: null })
  })

  it('links an organizer of a team with the planner to the generator page', () => {
    renderHeader(team())
    expect(button()?.getAttribute('href')).toBe(paths.routeGenerate('club'))
    expect(button()?.textContent).toBe('routeGenerator.title')
  })

  it('is hidden for a member', () => {
    renderHeader(team({ role: 'MEMBER' }))
    expect(button()).toBeNull()
  })

  it('is hidden when the team has no planner', () => {
    renderHeader(team({ enableRoutePlanner: false }))
    expect(button()).toBeNull()
  })

  it('is disabled, with no link, when the quota is spent', () => {
    renderHeader(team({ plannerQuota: { limit: 20, used: 20, resetsOn: '2026-12-01' } }))
    expect((button() as HTMLButtonElement).disabled).toBe(true)
    expect(button()?.getAttribute('href')).toBeNull()
  })
})
