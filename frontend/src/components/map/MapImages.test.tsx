import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, render } from '@testing-library/react'

const map = vi.hoisted(() => ({
  style: {},
  setMissingStyleImageResolver: vi.fn(),
  hasImage: vi.fn(() => false),
  addImage: vi.fn(),
}))
vi.mock('react-map-gl/maplibre', () => ({
  useMap: () => ({ current: { getMap: () => map } }),
}))

import { MapImages } from './MapImages'

describe('MapImages', () => {
  afterEach(() => {
    cleanup()
    vi.clearAllMocks()
  })

  it('sets the map one resolver, and removes it on unmount', () => {
    const { unmount } = render(<MapImages />)
    expect(map.setMissingStyleImageResolver).toHaveBeenCalledTimes(1)
    expect(map.setMissingStyleImageResolver.mock.calls[0][0]).toBeTypeOf('function')
    unmount()
    expect(map.setMissingStyleImageResolver).toHaveBeenLastCalledWith(null)
  })
})
