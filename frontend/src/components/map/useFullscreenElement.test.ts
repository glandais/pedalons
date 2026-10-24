import { describe, it, expect, afterEach } from 'vitest'
import { act, renderHook } from '@testing-library/react'
import { useFullscreenElement } from './useFullscreenElement'

function setFullscreenElement(element: Element | null) {
  Object.defineProperty(document, 'fullscreenElement', { value: element, configurable: true })
  document.dispatchEvent(new Event('fullscreenchange'))
}

describe('useFullscreenElement', () => {
  afterEach(() => setFullscreenElement(null))

  it('follows the element the browser shows in fullscreen, and lets go when it leaves', () => {
    const map = document.createElement('div')
    const { result } = renderHook(() => useFullscreenElement())
    expect(result.current).toBeUndefined()

    act(() => setFullscreenElement(map))
    expect(result.current).toBe(map)

    act(() => setFullscreenElement(null))
    expect(result.current).toBeUndefined()
  })
})
