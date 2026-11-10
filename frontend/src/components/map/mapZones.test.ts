import { afterEach, describe, expect, it, vi } from 'vitest'
import { renderHook } from '@testing-library/react'
import { openingSide, readMapZones, useMapZones } from './mapZones'

const originalMatchMedia = window.matchMedia

function setCoarse(coarse: boolean) {
  window.matchMedia = vi.fn().mockImplementation((query: string) => ({
    matches: query.includes('pointer: coarse') ? coarse : false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
  })) as unknown as typeof window.matchMedia
}

describe('mapZones', () => {
  afterEach(() => {
    window.matchMedia = originalMatchMedia
  })

  it('puts the camera top-left and the display top-right on a fine pointer', () => {
    setCoarse(false)
    expect(readMapZones()).toEqual({
      camera: 'top-left',
      display: 'top-right',
      side: { camera: 'right', display: 'left' },
    })
  })

  it('gathers both zones bottom-right, opening to the left, on a coarse pointer', () => {
    setCoarse(true)
    expect(readMapZones()).toEqual({
      camera: 'bottom-right',
      display: 'bottom-right',
      side: { camera: 'left', display: 'left' },
    })
  })

  it('opens away from the edge the column stands on', () => {
    expect(openingSide('top-left')).toBe('right')
    expect(openingSide('bottom-left')).toBe('right')
    expect(openingSide('top-right')).toBe('left')
    expect(openingSide('bottom-right')).toBe('left')
  })

  it('keeps the zones read at mount, as MapLibre keeps a control where it was added', () => {
    setCoarse(false)
    const { result, rerender } = renderHook(() => useMapZones())
    expect(result.current.camera).toBe('top-left')
    setCoarse(true)
    rerender()
    expect(result.current.camera).toBe('top-left')
  })
})
