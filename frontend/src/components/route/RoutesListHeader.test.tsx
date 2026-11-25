import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { TeamDetailDto } from '@/api/dto'

vi.mock('react-i18next', () => ({
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))
const upload = vi.hoisted(() => ({ open: vi.fn() }))
vi.mock('./useGpxUpload', () => ({
  useGpxUpload: () => ({ input: null, open: upload.open, progress: null, error: null }),
}))

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

const item = (key: string) => screen.queryByTestId(`create-${key}`)

async function openMenu() {
  fireEvent.click(screen.getByRole('button', { name: 'aria.createOther' }))
  await waitFor(() => expect(item('route-import')).not.toBeNull())
}

describe('RoutesListHeader create button', () => {
  afterEach(() => {
    cleanup()
    useAuthStore.setState({ user: null })
    upload.open.mockReset()
  })

  it('an organizer gets « Créer un parcours ▾ »: the form, the GPX import, the generator', async () => {
    renderHeader(team())
    expect(screen.getByRole('link', { name: 'list.create.route' }).getAttribute('href')).toBe(
      paths.routeNew('club')
    )
    await openMenu()
    fireEvent.click(item('route-import')!)
    expect(upload.open).toHaveBeenCalled()
    // The generator (WEB-179).
    expect(item('route-generate')?.getAttribute('href')).toBe(paths.routeGenerate('club'))
  })

  it('nothing for a member', () => {
    renderHeader(team({ role: 'MEMBER' }))
    expect(screen.queryByRole('link', { name: 'list.create.route' })).toBeNull()
  })

  it('no generator when the team has no planner', async () => {
    renderHeader(team({ enableRoutePlanner: false }))
    await openMenu()
    expect(item('route-generate')).toBeNull()
  })

  it('the generator is disabled, with no link, when the quota is spent', async () => {
    renderHeader(team({ plannerQuota: { limit: 20, used: 20, resetsOn: '2026-12-01' } }))
    await openMenu()
    const generate = item('route-generate')!
    expect(generate.hasAttribute('disabled') || generate.getAttribute('data-disabled')).toBeTruthy()
    expect(generate.getAttribute('href')).toBeNull()
  })
})
