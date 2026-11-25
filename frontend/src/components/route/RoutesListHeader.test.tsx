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
  useGpxUpload: () => ({ open: upload.open, progress: null }),
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

  it('with the planner: draw on the map, then the GPX import and the generator', async () => {
    renderHeader(team())
    const draw = screen.getByRole('link', { name: 'routes.create.form.sourceModePlanner' })
    expect(draw.getAttribute('href')).toBe(paths.routeNew('club'))
    await openMenu()
    fireEvent.click(item('route-import')!)
    expect(upload.open).toHaveBeenCalled()
    expect(item('route-generate')?.getAttribute('href')).toBe(paths.routeGenerate('club'))
  })

  it('nothing for a member', () => {
    renderHeader(team({ role: 'MEMBER' }))
    expect(screen.queryByRole('button', { name: 'routes.upload.button' })).toBeNull()
  })

  it('without the planner: the GPX import alone, as a plain button', () => {
    renderHeader(team({ enableRoutePlanner: false }))
    fireEvent.click(screen.getByRole('button', { name: 'routes.upload.button' }))
    expect(upload.open).toHaveBeenCalled()
    expect(screen.queryByRole('button', { name: 'aria.createOther' })).toBeNull()
  })

  it('a spent quota closes drawing and the generator: the import leads', async () => {
    renderHeader(team({ plannerQuota: { limit: 20, used: 20, resetsOn: '2026-12-01' } }))
    fireEvent.click(screen.getByRole('button', { name: 'routes.upload.button' }))
    expect(upload.open).toHaveBeenCalled()
    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'aria.createOther' })).toBeTruthy()
    )
    fireEvent.click(screen.getByRole('button', { name: 'aria.createOther' }))
    await waitFor(() => expect(item('route-generate')).not.toBeNull())
    const generate = item('route-generate')!
    expect(generate.hasAttribute('disabled') || generate.getAttribute('data-disabled')).toBeTruthy()
    expect(generate.getAttribute('href')).toBeNull()
  })
})
