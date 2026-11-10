import { afterEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MantineProvider } from '@mantine/core'

vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))

// A toolbar's panel is not a control of the map: it must never ask MapLibre for a column box.
const useControl = vi.hoisted(() => vi.fn())
vi.mock('react-map-gl/maplibre', () => ({ useControl }))

import { MapPanel } from './MapPanel'
import { panelJustDismissed } from './mapPanelState'

function show() {
  render(
    <MantineProvider>
      <MapPanel id="help" trigger="toolbar" label="Aide" title="Gestes" icon={null}>
        <p>Contenu du panneau</p>
      </MapPanel>
    </MantineProvider>
  )
  return screen.getByRole('button', { name: 'Aide' })
}

describe('MapPanel trigger="toolbar"', () => {
  afterEach(cleanup)

  it('is a plain button out of any control column, opening a popover', async () => {
    const button = show()
    expect(useControl).not.toHaveBeenCalled()
    expect(button.closest('.maplibregl-ctrl')).toBeNull()
    expect(button).toHaveClass('map-toolbar-button')
    expect(button).toHaveAttribute('aria-pressed', 'false')

    fireEvent.click(button)
    expect(await screen.findByText('Contenu du panneau')).toBeInTheDocument()
    expect(button).toHaveAttribute('aria-pressed', 'true')
    // A popover, not the bottom sheet of a finger
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('closes on Escape while the focus stays on its button', async () => {
    const button = show()
    fireEvent.click(button)
    await screen.findByText('Contenu du panneau')
    act(() => {
      button.focus()
    })
    fireEvent.keyDown(window, { key: 'Escape' })
    await waitFor(() => expect(button).toHaveAttribute('aria-pressed', 'false'))
  })

  it('marks a dismissal by an outside press, so the map drops the click that follows', async () => {
    const button = show()
    fireEvent.click(button)
    await screen.findByText('Contenu du panneau')
    // Mantine's Popover listens for the press itself (mousedown) outside its target and dropdown
    fireEvent.mouseDown(document.body)
    fireEvent.touchStart(document.body)
    await waitFor(() => expect(button).toHaveAttribute('aria-pressed', 'false'))
    expect(panelJustDismissed()).toBe(true)
  })
})
