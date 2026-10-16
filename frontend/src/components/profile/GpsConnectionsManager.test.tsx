import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest'
import { render, screen, cleanup, fireEvent, within } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MantineProvider } from '@mantine/core'
import type { GpsServiceConnectionDto, GpsServiceType, UserDto } from '@/api/dto'

// Keys and their parameters, not wording: the assertions read which message is shown.
vi.mock('react-i18next', () => ({
  useTranslation: () => ({
    t: (key: string, options?: Record<string, unknown>) =>
      options
        ? `${key}(${Object.entries(options)
            .map(([name, value]) => `${name}=${String(value)}`)
            .join(',')})`
        : key,
    i18n: { language: 'fr' },
  }),
}))

const state = vi.hoisted(() => ({
  autoSyncEnabled: true,
  available: [] as GpsServiceType[],
  connections: [] as GpsServiceConnectionDto[],
  mutate: vi.fn(),
  isPending: false,
  variables: undefined as { serviceType: GpsServiceType; data: { enabled: boolean } } | undefined,
  mutationOptions: undefined as
    | {
        mutation?: {
          onSuccess?: (
            connection: GpsServiceConnectionDto,
            variables: { serviceType: GpsServiceType; data: { enabled: boolean } }
          ) => void
        }
      }
    | undefined,
}))

vi.mock('@/hooks/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: true,
    user: { id: 'u1', connectedServices: state.connections } as unknown as UserDto,
    refetchUser: vi.fn(),
  }),
}))

vi.mock('@/api/endpoints/gps-services/gps-services', () => ({
  useGetAvailableServices: () => ({ data: state.available, isLoading: false }),
  useSetGpsAutoSync: (options: typeof state.mutationOptions) => {
    state.mutationOptions = options
    return { mutate: state.mutate, isPending: state.isPending, variables: state.variables }
  },
}))

vi.mock('@/config/appConfig', () => ({ isGpsAutoSyncEnabled: () => state.autoSyncEnabled }))

vi.mock('@/api/endpoints/gpx-previews/gpx-previews', () => ({ uploadToGpsService: vi.fn() }))

vi.mock('@/utils/dateFormat', () => ({
  useFormattedDate: () => ({
    formatDate: (date: string) => `date:${date}`,
    formatDateTime: (date: string) => `dateTime:${date}`,
  }),
}))

import { GpsConnectionsManager } from './GpsConnectionsManager'
import { getGetMeQueryKey } from '@/api/endpoints/users/users'

function connection(overrides: Partial<GpsServiceConnectionDto> = {}): GpsServiceConnectionDto {
  return {
    serviceType: 'WAHOO',
    displayName: 'Wahoo',
    connectedAt: '2026-09-01T08:00:00Z',
    autoSync: false,
    autoSyncState: 'OFF',
    autoSyncRouteCount: 0,
    ...overrides,
  }
}

function renderManager(queryClient = new QueryClient()) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>
          <GpsConnectionsManager />
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const wahooSwitch = () =>
  screen.getByRole('switch', {
    name: 'gps.autoSync.ariaLabel(service=gps.services.wahoo)',
  }) as HTMLInputElement

const status = () => screen.queryByTestId('gps-auto-sync-status')

describe('GpsConnectionsManager — automatic route sending', () => {
  beforeEach(() => {
    state.autoSyncEnabled = true
    state.available = ['WAHOO', 'GARMIN']
    state.connections = []
    state.mutate.mockReset()
    state.isPending = false
    state.variables = undefined
    state.mutationOptions = undefined
  })
  afterEach(cleanup)

  it('offers the switch only for a connected service', () => {
    state.connections = [connection()]
    renderManager()

    expect(screen.getAllByRole('switch')).toHaveLength(1)
    expect(wahooSwitch().checked).toBe(false)
    // Garmin is offered, not connected: a connect button, no switch.
    expect(screen.getByRole('button', { name: 'gps.connect' })).toBeTruthy()
  })

  it('shows no switch when the deployment does not send routes on its own', () => {
    state.autoSyncEnabled = false
    state.connections = [connection({ autoSync: true, autoSyncState: 'UP_TO_DATE' })]
    renderManager()

    expect(screen.queryAllByRole('switch')).toHaveLength(0)
    expect(status()).toBeNull()
  })

  it('shows no switch when no service is connected', () => {
    renderManager()

    expect(screen.queryAllByRole('switch')).toHaveLength(0)
  })

  it('turns sending on and off through the generated mutation', () => {
    state.connections = [connection()]
    const { unmount } = renderManager()

    fireEvent.click(wahooSwitch())
    expect(state.mutate).toHaveBeenCalledWith({ serviceType: 'WAHOO', data: { enabled: true } })
    unmount()

    state.mutate.mockReset()
    state.connections = [connection({ autoSync: true, autoSyncState: 'UP_TO_DATE' })]
    renderManager()

    fireEvent.click(wahooSwitch())
    expect(state.mutate).toHaveBeenCalledWith({ serviceType: 'WAHOO', data: { enabled: false } })
  })

  it('shows the value being saved and waits for it', () => {
    state.connections = [connection()]
    state.isPending = true
    state.variables = { serviceType: 'WAHOO', data: { enabled: true } }
    renderManager()

    expect(wahooSwitch().checked).toBe(true)
    expect(wahooSwitch().disabled).toBe(true)
    expect(status()).toBeNull()
  })

  it('puts the saved connection into /me at once', () => {
    state.connections = [connection()]
    const queryClient = new QueryClient()
    const other = connection({ serviceType: 'GARMIN', displayName: 'Garmin Connect' })
    queryClient.setQueryData(getGetMeQueryKey(), {
      id: 'u1',
      connectedServices: [connection(), other],
    })
    renderManager(queryClient)

    const saved = connection({ autoSync: true, autoSyncState: 'PENDING' })
    state.mutationOptions?.mutation?.onSuccess?.(saved, {
      serviceType: 'WAHOO',
      data: { enabled: true },
    })

    expect(queryClient.getQueryData<UserDto>(getGetMeQueryKey())?.connectedServices).toEqual([
      saved,
      other,
    ])
  })

  it('says nothing of the state while sending is off', () => {
    state.connections = [connection({ autoSync: false, autoSyncState: 'OFF' })]
    renderManager()

    expect(status()).toBeNull()
  })

  it('counts the routes sent when up to date', () => {
    state.connections = [
      connection({ autoSync: true, autoSyncState: 'UP_TO_DATE', autoSyncRouteCount: 2 }),
    ]
    renderManager()

    expect(status()?.textContent).toBe('gps.autoSync.state.upToDate(count=2)')
  })

  it('says when there is nothing to send, and when it last sent', () => {
    state.connections = [
      connection({
        autoSync: true,
        autoSyncState: 'UP_TO_DATE',
        autoSyncRouteCount: 0,
        lastAutoSyncAt: '2026-10-10T08:00:00Z',
      }),
    ]
    renderManager()

    expect(status()?.textContent).toBe(
      'gps.autoSync.state.upToDateNone · gps.autoSync.lastSent(date=dateTime:2026-10-10T08:00:00Z)'
    )
  })

  it('says a sending is under way', () => {
    state.connections = [connection({ autoSync: true, autoSyncState: 'PENDING' })]
    renderManager()

    expect(status()?.textContent).toBe('gps.autoSync.state.pending')
  })

  it('says the last sending failed', () => {
    state.connections = [connection({ autoSync: true, autoSyncState: 'FAILING' })]
    renderManager()

    expect(status()?.textContent).toBe('gps.autoSync.state.failing(service=gps.services.wahoo)')
  })

  it('asks to reconnect, and offers to', () => {
    state.connections = [connection({ autoSync: true, autoSyncState: 'RECONNECT_REQUIRED' })]
    renderManager()

    expect(status()?.textContent).toBe(
      'gps.autoSync.state.reconnectRequired(service=gps.services.wahoo)'
    )
    expect(screen.getByRole('button', { name: 'gps.autoSync.reconnect' })).toBeTruthy()
  })

  it('warns before disconnecting that the routes sent will be removed', async () => {
    state.connections = [
      connection({ autoSync: true, autoSyncState: 'UP_TO_DATE', autoSyncRouteCount: 3 }),
    ]
    renderManager()

    fireEvent.click(screen.getByLabelText('gps.disconnect'))
    const dialog = await screen.findByRole('dialog')

    expect(
      within(dialog).getByText(
        'gps.disconnectConfirm.message(service=gps.services.wahoo) ' +
          'gps.disconnectConfirm.autoSyncRoutes(count=3,service=gps.services.wahoo)'
      )
    ).toBeTruthy()
  })

  it('does not mention routes on disconnecting when none was sent', async () => {
    state.connections = [connection()]
    renderManager()

    fireEvent.click(screen.getByLabelText('gps.disconnect'))
    const dialog = await screen.findByRole('dialog')

    expect(
      within(dialog).getByText('gps.disconnectConfirm.message(service=gps.services.wahoo)')
    ).toBeTruthy()
  })
})
