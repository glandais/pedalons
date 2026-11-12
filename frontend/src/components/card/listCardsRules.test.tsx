import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { AdDto, RouteDto, TripDto } from '@/api/dto'
import { plain } from '@/test/weatherFixtures'

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false }))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { AdCard } from './AdCard'
import { RouteCard } from './RouteCard'
import { AgendaRow } from '../agenda/AgendaRow'

const PRIVATE_TEAM = {
  id: 't1',
  name: 'VCM',
  slug: 'vcm',
  visibility: 'TEAM' as const,
  accessible: true,
}
const MEDIA = { markdown: '', assets: { images: [], attachments: [] } }

function wrap(node: React.ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>{node}</MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const text = () => plain(document.body.textContent)

const route = (overrides: Partial<RouteDto> = {}) =>
  ({
    id: 'rt',
    slug: 'boucle',
    team: PRIVATE_TEAM,
    name: 'Boucle',
    media: MEDIA,
    distance: 92_400,
    elevationGain: 1_240,
    surfaceType: 'ROAD',
    visibility: 'TEAM',
    deleted: false,
    commentCount: 0,
    tags: [],
    ...overrides,
  }) as RouteDto

const ad = (overrides: Partial<AdDto> = {}) =>
  ({
    id: 'ad',
    slug: 'velo',
    team: PRIVATE_TEAM,
    name: 'Vélo',
    media: MEDIA,
    status: 'PUBLISHED',
    visibility: 'TEAM',
    adType: 'SALE',
    createdAt: '2026-11-07T17:42:00Z',
    tags: [],
    ...overrides,
  }) as AdDto

describe('RouteCard (docs/LEDGER_*.md WEB-167)', () => {
  afterEach(cleanup)

  it('opens on a gradient with the route’s icon when it has no thumbnail yet (R10)', () => {
    wrap(<RouteCard route={route({ thumbnailUrl: undefined })} showTeam={false} />)
    expect(screen.getByTestId('card-image-gradient')).toBeTruthy()
  })

  it('says no « 0 commentaire » (R4), and the visibility only when it differs (R1)', () => {
    wrap(<RouteCard route={route()} showTeam={false} />)
    expect(text()).not.toContain('commentaire')
    expect(text()).not.toContain('Équipe uniquement')
    cleanup()
    wrap(<RouteCard route={route({ visibility: 'PUBLIC', commentCount: 2 })} showTeam={false} />)
    expect(text()).toContain('Public')
    expect(text()).toContain('2 commentaires')
  })
})

describe('AdCard (R1)', () => {
  afterEach(cleanup)

  it('says its type alone when published: neither « Publié » nor « Équipe uniquement »', () => {
    wrap(<AdCard ad={ad()} />)
    expect(text()).toContain('Vente')
    expect(text()).not.toContain('Publié')
    expect(text()).not.toContain('Équipe uniquement')
  })

  it('adds « Brouillon » after the type when it is not published', () => {
    wrap(<AdCard ad={ad({ status: 'DRAFT' })} />)
    expect(text()).toMatch(/Vente.*Brouillon/)
  })
})

describe('AgendaRow (R1, R4)', () => {
  afterEach(cleanup)

  const trip = {
    type: 'TRIP',
    team: PRIVATE_TEAM,
    id: 'tr',
    slug: 'raid',
    name: 'Raid',
    media: MEDIA,
    dateTime: '2020-05-15T06:00:00Z',
    endDateTime: '2020-05-17T15:00:00Z',
    timezone: 'Europe/Paris',
    status: 'PUBLISHED',
    finished: true,
    visibility: 'TEAM',
    participantCount: 0,
    stageCount: 0,
    participants: [],
    stages: [],
    deleted: false,
    registered: false,
    tags: [],
  } as unknown as TripDto

  it('says « Terminé » of a trip over, no ordinary visibility, no zero counter', () => {
    wrap(<AgendaRow publication={trip} />)
    expect(text()).toContain('Terminé')
    expect(text()).not.toContain('Équipe uniquement')
    expect(text()).not.toContain('étape')
    expect(text()).not.toContain('personne')
  })
})
