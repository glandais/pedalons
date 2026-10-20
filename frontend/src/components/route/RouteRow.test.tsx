import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { ElevationState, SurfaceType, Visibility, type RouteDto } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})
vi.mock('@/components/common/PrefetchLink', () => ({
  PrefetchLink: ({ children }: { children?: React.ReactNode }) => <a>{children}</a>,
}))

import { RouteRow } from './RouteRow'

function route(deleted: boolean): RouteDto {
  return {
    id: '0abcdefghijkl',
    slug: 'boucle',
    team: { id: '0team', name: 'Vélo club', slug: 'velo', visibility: Visibility.PUBLIC },
    name: 'Boucle des étangs',
    media: defaultMedia(),
    distance: 42_000,
    elevationGain: 350,
    elevationLoss: 350,
    elevationState: ElevationState.HD,
    surfaceType: SurfaceType.ROAD,
    visibility: Visibility.PUBLIC,
    createdAt: '2026-10-15T08:00:00Z',
    deleted,
    tags: [],
  }
}

function renderRow(shown: RouteDto, compact = false) {
  render(
    <MantineProvider>
      <MemoryRouter>
        <RouteRow route={shown} compact={compact} />
      </MemoryRouter>
    </MantineProvider>
  )
}

describe('RouteRow', () => {
  afterEach(cleanup)

  it.each([false, true])('says a deleted route is deleted (compact: %s)', (compact) => {
    renderRow(route(true), compact)
    expect(screen.getByText('Supprimé')).toBeTruthy()
  })

  it('says nothing of the kind for a live route', () => {
    renderRow(route(false))
    expect(screen.queryByText('Supprimé')).toBeNull()
  })
})
