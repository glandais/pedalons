import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { renderHook } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import type { ReactNode } from 'react'
import { useScrollToAnchor } from './useScrollToAnchor'

// docs/LEDGER_*.md WEB-134: below md, the map and pictures above `#meteo` load after the first
// scroll; with `settleMs` the anchor is scrolled to again until the reader scrolls.
describe('useScrollToAnchor', () => {
  let resize: (() => void) | undefined
  const scrollIntoView = vi.fn()
  let target: HTMLElement

  beforeEach(() => {
    vi.useFakeTimers()
    resize = undefined
    scrollIntoView.mockClear()
    vi.stubGlobal(
      'ResizeObserver',
      class {
        constructor(callback: () => void) {
          resize = callback
        }
        observe() {}
        disconnect() {
          resize = undefined
        }
      }
    )
    target = document.createElement('div')
    target.id = 'meteo'
    target.scrollIntoView = scrollIntoView
    document.body.appendChild(target)
  })

  afterEach(() => {
    target.remove()
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  const wrapper = ({ children }: { children: ReactNode }) => (
    <MemoryRouter initialEntries={['/sortie#meteo']}>{children}</MemoryRouter>
  )

  it('scrolls once, and not again on a resize, without settleMs', () => {
    renderHook(() => useScrollToAnchor('meteo', true), { wrapper })
    expect(scrollIntoView).toHaveBeenCalledTimes(1)
    expect(resize).toBeUndefined()
  })

  it('scrolls again when the page resizes, until the reader scrolls', () => {
    renderHook(() => useScrollToAnchor('meteo', true, { settleMs: 4000 }), { wrapper })
    expect(scrollIntoView).toHaveBeenCalledTimes(1)
    resize?.() // the lazy map replaced its skeleton
    expect(scrollIntoView).toHaveBeenCalledTimes(2)
    window.dispatchEvent(new Event('wheel'))
    expect(resize).toBeUndefined()
  })

  it('stops following the layout once the window is over', () => {
    renderHook(() => useScrollToAnchor('meteo', true, { settleMs: 4000 }), { wrapper })
    vi.advanceTimersByTime(4000)
    expect(resize).toBeUndefined()
    expect(scrollIntoView).toHaveBeenCalledTimes(1)
  })
})
