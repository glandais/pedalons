import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { MantineProvider, Menu } from '@mantine/core'
import type { GpsServiceConnectionDto, RouteGpsSyncStatusDto } from '@/api/dto'

vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { SendToDeviceItems } from './SendToDeviceItems'

const SERVICES = [
  { serviceType: 'GARMIN' },
  { serviceType: 'HAMMERHEAD' },
  { serviceType: 'WAHOO' },
] as GpsServiceConnectionDto[]

function show(statuses: RouteGpsSyncStatusDto[] | undefined, onSend = vi.fn()) {
  render(
    <MantineProvider>
      <Menu opened>
        <Menu.Target>
          <button type="button">menu</button>
        </Menu.Target>
        <Menu.Dropdown>
          <SendToDeviceItems services={SERVICES} statuses={statuses} onSend={onSend} />
        </Menu.Dropdown>
      </Menu>
    </MantineProvider>
  )
  return onSend
}

describe('SendToDeviceItems — where the route already stands (WEB-163)', () => {
  afterEach(cleanup)

  it('says nothing for a service that does not hold the route', () => {
    show(undefined)
    expect(screen.getByText('Garmin Connect')).toBeTruthy()
    expect(screen.queryByTestId(/gps-route-status-/)).toBeNull()
  })

  it('gives each service its own state, and the date of the last send', () => {
    show([
      { serviceType: 'GARMIN', state: 'SENT', syncedAt: '2026-11-15T08:30:00Z' },
      { serviceType: 'HAMMERHEAD', state: 'OUTDATED', syncedAt: '2026-11-01T08:30:00Z' },
    ])
    expect(screen.getByTestId('gps-route-status-GARMIN').textContent).toMatch(
      /^Déjà envoyé · le .*15 nov/
    )
    expect(screen.getByTestId('gps-route-status-HAMMERHEAD').textContent).toBe(
      'Une version précédente y est : renvoyez-le'
    )
    expect(screen.queryByTestId('gps-route-status-WAHOO')).toBeNull()
  })

  it.each([
    ['PENDING', 'Envoi en cours…'],
    ['FAILING', 'Le dernier envoi a échoué'],
    ['RECONNECT_REQUIRED', 'Accès refusé : reconnectez le service'],
  ] as const)('%s reads « %s »', (state, text) => {
    show([{ serviceType: 'WAHOO', state }])
    expect(screen.getByTestId('gps-route-status-WAHOO').textContent).toBe(text)
  })

  it('still sends a route already there', () => {
    const onSend = show([{ serviceType: 'GARMIN', state: 'SENT' }])
    expect(screen.getByTestId('gps-route-status-GARMIN').textContent).toBe('Déjà envoyé')
    fireEvent.click(screen.getByText('Garmin Connect'))
    expect(onSend).toHaveBeenCalledWith('GARMIN')
  })
})
