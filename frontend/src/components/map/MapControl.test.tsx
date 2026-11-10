import { useState } from 'react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render, screen } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

const positions = vi.hoisted(() => [] as string[])

// `useControl` without a map: the control is built once and its element put in the page, where the
// portal renders the buttons.
vi.mock('react-map-gl/maplibre', () => ({
  useControl: (
    factory: () => { onAdd: () => HTMLElement },
    options: { position: string }
  ): unknown => {
    const [control] = useState(() => {
      const built = factory()
      document.body.appendChild(built.onAdd())
      positions.push(options.position)
      return built
    })
    return control
  },
}))

// The tooltip's side is what matters, not Floating UI's placement in a layout-less DOM.
vi.mock('@mantine/core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@mantine/core')>()),
  Tooltip: ({ position, children }: { position?: string; children: React.ReactNode }) => (
    <span data-testid="tooltip" data-position={position}>
      {children}
    </span>
  ),
}))

import { MapControlButton, MapControlGroup } from './MapControl'

const originalMatchMedia = window.matchMedia

function setCoarse(coarse: boolean) {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: query.includes('pointer: coarse') ? coarse : false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })) as unknown as typeof window.matchMedia
}

function show(zone: 'camera' | 'display', slot: 'fullscreen' | 'style') {
  render(
    <MantineProvider>
      <MapControlGroup zone={zone} slot={slot}>
        <MapControlButton label="Bouton" icon={null} onClick={() => {}} />
      </MapControlGroup>
    </MantineProvider>
  )
  return screen.getByRole('button', { name: 'Bouton' })
}

describe('MapControlGroup', () => {
  afterEach(() => {
    cleanup()
    document.body.innerHTML = ''
    positions.length = 0
    window.matchMedia = originalMatchMedia
  })

  it('marks its box with the slot class index.css orders it by', () => {
    setCoarse(false)
    const button = show('camera', 'fullscreen')
    const box = button.closest('.maplibregl-ctrl-group')
    expect(box).toHaveClass('maplibregl-ctrl', 'pdl-ctrl-fullscreen')
  })

  it('opens the tooltips of the camera column to the right on a fine pointer', () => {
    setCoarse(false)
    show('camera', 'fullscreen')
    expect(positions).toEqual(['top-left'])
    expect(screen.getByTestId('tooltip')).toHaveAttribute('data-position', 'right')
  })

  it('opens the tooltips of the display column to the left on a fine pointer', () => {
    setCoarse(false)
    show('display', 'style')
    expect(positions).toEqual(['top-right'])
    expect(screen.getByTestId('tooltip')).toHaveAttribute('data-position', 'left')
  })

  it('puts both zones bottom-right, tooltips to the left, on a coarse pointer', () => {
    setCoarse(true)
    show('camera', 'fullscreen')
    expect(positions).toEqual(['bottom-right'])
    expect(screen.getByTestId('tooltip')).toHaveAttribute('data-position', 'left')
  })
})
