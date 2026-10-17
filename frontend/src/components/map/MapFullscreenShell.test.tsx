import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, cleanup } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('@/hooks/useUnits', () => ({
  useUnits: () => ({
    distance: (m: number) => `${m / 1000} km`,
    elevation: (m: number) => `${m} m`,
  }),
}))

import { MapFullscreenShell } from './MapFullscreenShell'

function renderShell(props: Partial<React.ComponentProps<typeof MapFullscreenShell>> = {}) {
  return render(
    <MantineProvider>
      <MapFullscreenShell leading={<button>back</button>} title="Ma sortie" {...props}>
        <div data-testid="map" />
      </MapFullscreenShell>
    </MantineProvider>
  )
}

describe('MapFullscreenShell', () => {
  afterEach(cleanup)

  it('shows the leading control, the title and the map', () => {
    renderShell()
    expect(screen.getByRole('button', { name: 'back' })).toBeTruthy()
    expect(screen.getByText('Ma sortie')).toBeTruthy()
    expect(screen.getByTestId('map')).toBeTruthy()
  })

  it('renders a node title as given', () => {
    renderShell({ title: <h2>Titre libre</h2> })
    expect(screen.getByRole('heading', { name: 'Titre libre' })).toBeTruthy()
  })

  it('shows the distance, and the elevation gain and loss that are hidden below sm', () => {
    renderShell({ stats: { distance: 42000, gain: 800, loss: 750 } })
    expect(screen.getByText('42 km')).toBeTruthy()
    const gain = screen.getByText('800 m')
    const loss = screen.getByText('750 m')
    expect(gain.parentElement?.className).toContain('mantine-visible-from-sm')
    expect(loss.parentElement?.className).toContain('mantine-visible-from-sm')
    expect(screen.getByText('42 km').parentElement?.className).not.toContain(
      'mantine-visible-from-sm'
    )
  })

  it('shows no stats, and no elevation, when none is given', () => {
    renderShell({ stats: { distance: 1000 } })
    expect(screen.getByText('1 km')).toBeTruthy()
    expect(screen.queryByText(/ m$/)).toBeNull()
  })

  it('renders the actions and the bottom strip', () => {
    renderShell({
      actions: <button>done</button>,
      bottom: <div data-testid="strip" />,
    })
    expect(screen.getByRole('button', { name: 'done' })).toBeTruthy()
    expect(screen.getByTestId('strip')).toBeTruthy()
  })

  it('renders no bottom strip by default', () => {
    renderShell()
    expect(screen.queryByTestId('strip')).toBeNull()
  })
})
