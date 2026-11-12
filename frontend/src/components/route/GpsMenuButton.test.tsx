import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { GpsServiceConnectionDto, RouteDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'

const gps = vi.hoisted(() => ({
  connectedServices: [] as GpsServiceConnectionDto[],
  uploadRoute: vi.fn(),
}))
const bulk = vi.hoisted(() => ({
  calls: [] as Array<{ enabled?: boolean }>,
  route: undefined as unknown,
}))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/hooks/useAuth', () => ({ useAuth: () => ({ isAuthenticated: true }) }))
vi.mock('@/hooks/useGpsConnections', () => ({
  useGpsConnections: () => ({ ...gps, isUploading: false }),
}))
vi.mock('@/api/endpoints/routes/routes', () => ({
  useGetRoutesBulk: (
    _team: string,
    _params: unknown,
    options: { query: { enabled?: boolean } }
  ) => {
    bulk.calls.push(options.query)
    return {
      data: options.query.enabled && bulk.route ? { routes: [bulk.route] } : undefined,
      isLoading: false,
    }
  },
}))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { GpsMenuButton } from './GpsMenuButton'

const files = {
  media: {
    markdown: '',
    assets: {
      images: [],
      attachments: [],
      gpx: { id: 'g', fileName: 'b.gpx', contentType: 'application/gpx', url: '/files/b.gpx' },
      fit: { id: 'f', fileName: 'b.fit', contentType: 'application/fit', url: '/files/b.fit' },
    },
  },
} as unknown as Pick<RouteDetailDto, 'media'>

function mount(route?: Pick<RouteDetailDto, 'media'>) {
  render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <GpsMenuButton teamSlug="vcm" routeSlug="boucle-b" route={route} subtitle="B · 78,0 km" />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

function open(route?: Pick<RouteDetailDto, 'media'>) {
  mount(route)
  fireEvent.click(
    screen.getByRole('button', { name: "Envoyer le parcours vers un GPS ou l'exporter" })
  )
}

// R7 (docs/LEDGER_*.md WEB-167): one « GPS » button, the app's GPS sheet as a menu.
describe('GpsMenuButton', () => {
  afterEach(() => {
    cleanup()
    gps.connectedServices = []
    gps.uploadRoute.mockReset()
    bulk.calls = []
    bulk.route = undefined
  })

  it('sends the route to a connected device', async () => {
    gps.connectedServices = [{ serviceType: 'GARMIN' } as GpsServiceConnectionDto]
    open(files)
    expect(await screen.findByText('B · 78,0 km')).toBeTruthy()
    expect(screen.getByText('Vers un appareil')).toBeTruthy()
    fireEvent.click(screen.getByRole('menuitem', { name: 'Garmin Connect', hidden: true }))
    expect(gps.uploadRoute).toHaveBeenCalledWith({
      serviceType: 'GARMIN',
      teamSlug: 'vcm',
      routeSlug: 'boucle-b',
    })
  })

  it('offers « Connecter un compteur » to the devices page when none is connected', async () => {
    open(files)
    const connect = await screen.findByRole('menuitem', {
      name: 'Connecter un compteur',
      hidden: true,
    })
    expect(connect.getAttribute('href')).toBe(paths.profileDevices())
  })

  it('downloads the GPX and the FIT', async () => {
    open(files)
    const gpx = await screen.findByRole('menuitem', { name: 'Fichier GPX', hidden: true })
    expect(gpx.getAttribute('href')).toBe('/files/b.gpx')
    expect(gpx.hasAttribute('download')).toBe(true)
    expect(
      screen
        .getByRole('menuitem', { name: 'Fichier FIT, pour compteur', hidden: true })
        .getAttribute('href')
    ).toBe('/files/b.fit')
  })

  it('reads the files only once opened, when the card does not have the route', async () => {
    bulk.route = files
    mount()
    expect(bulk.calls.every((query) => !query.enabled)).toBe(true)
    fireEvent.click(screen.getByTestId('gps-button'))
    expect(
      (await screen.findByRole('menuitem', { name: 'Fichier GPX', hidden: true })).getAttribute(
        'href'
      )
    ).toBe('/files/b.gpx')
    expect(bulk.calls.some((query) => query.enabled)).toBe(true)
  })
})
