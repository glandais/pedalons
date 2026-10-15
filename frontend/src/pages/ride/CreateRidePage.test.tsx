import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MemoryRouter, Route, Routes } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { RideTemplateDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => ({
  ...(await importOriginal<typeof import('react-i18next')>()),
  useTranslation: () => ({ t: (key: string) => key, i18n: { language: 'fr' } }),
}))

const state = vi.hoisted(() => ({
  template: undefined as RideTemplateDto | undefined,
  templateLoading: false,
  templateSlugs: [] as Array<{ slug: string; enabled: boolean }>,
}))

vi.mock('@/pages/ride/rideFormData', () => ({
  useCreateRideFormData: () => ({
    team: {
      data: {
        slug: 'velo-club',
        name: 'Vélo Club',
        role: 'ORGANIZER',
        enableRides: true,
        enableRoutes: true,
        visibility: 'PUBLIC',
        timezone: 'Europe/Paris',
      },
      isLoading: false,
    },
  }),
}))
vi.mock('../../api/endpoints/rides/rides', () => ({
  useCreateRide: () => ({ mutate: vi.fn(), isPending: false }),
}))
vi.mock('../../api/endpoints/ride-templates/ride-templates', () => ({
  useGetTemplate: (_team: string, slug: string, options: { query: { enabled: boolean } }) => {
    state.templateSlugs.push({ slug, enabled: options.query.enabled })
    return options.query.enabled
      ? {
          data: state.templateLoading ? undefined : state.template,
          isLoading: state.templateLoading,
        }
      : { data: undefined, isLoading: false }
  },
}))
vi.mock('../../components/ride/RideEditor', () => ({
  RideEditor: ({ initialValues }: { initialValues: { name: string } }) => (
    <div data-testid="editor">{initialValues.name || '(vide)'}</div>
  ),
}))
vi.mock('../../components/ridetemplate/RideTemplatePickerModal', () => ({
  RideTemplatePickerModal: () => null,
}))

import { CreateRidePage } from './CreateRidePage'

const TEMPLATE = {
  id: 't1',
  slug: 'sortie-du-dimanche',
  name: 'Sortie du dimanche',
  markdown: '',
  visibility: 'PUBLIC',
  status: 'DRAFT',
  tags: [],
  groups: [{ name: 'Groupe A', routeSlug: 'monts-d-or' }],
} as unknown as RideTemplateDto

function renderAt(url: string, routerState?: unknown) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter
          initialEntries={[
            {
              pathname: url.split('?')[0],
              search: url.includes('?') ? `?${url.split('?')[1]}` : '',
              state: routerState,
            },
          ]}
        >
          <Routes>
            <Route path="/teams/:teamSlug/rides/new" element={<CreateRidePage />} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

describe('CreateRidePage — « Créer depuis un modèle »', () => {
  beforeEach(() => {
    state.template = TEMPLATE
    state.templateLoading = false
    state.templateSlugs = []
  })
  afterEach(cleanup)

  it('fills the form from the template named in the URL (mobile dashboard)', () => {
    renderAt('/teams/velo-club/rides/new?template=sortie-du-dimanche')

    expect(state.templateSlugs).toContainEqual({ slug: 'sortie-du-dimanche', enabled: true })
    expect(screen.getByTestId('editor').textContent).toBe('Sortie du dimanche')
  })

  it('waits for the template rather than showing an empty form', () => {
    state.templateLoading = true
    renderAt('/teams/velo-club/rides/new?template=sortie-du-dimanche')

    expect(screen.queryByTestId('editor')).toBeNull()
  })

  it('falls back to the plain form when the template cannot be read', () => {
    state.template = undefined
    renderAt('/teams/velo-club/rides/new?template=disparu')

    expect(screen.getByTestId('editor').textContent).toBe('(vide)')
  })

  it('numbers the ride when the template counts its rides (API-108)', () => {
    state.template = { ...TEMPLATE, nextNumber: 42 }
    renderAt('/teams/velo-club/rides/new?template=sortie-du-dimanche')

    expect(screen.getByTestId('editor').textContent).toBe('Sortie du dimanche #42')
  })

  it('prefers the router state, and then reads nothing', () => {
    renderAt('/teams/velo-club/rides/new', { template: { ...TEMPLATE, name: 'Depuis le web' } })

    expect(state.templateSlugs.every((c) => !c.enabled)).toBe(true)
    expect(screen.getByTestId('editor').textContent).toBe('Depuis le web')
  })
})
