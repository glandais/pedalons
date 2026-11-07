import { useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'

/** What the reader does to take the scroll back: the settle window ends at the first of them. */
const USER_SCROLL_EVENTS = ['wheel', 'touchstart', 'keydown', 'pointerdown'] as const

export interface ScrollToAnchorOptions {
  /**
   * For how long (ms) the anchor is scrolled to again whenever the page above it changes size — a
   * lazy map replacing its skeleton, pictures loading — until the reader scrolls. Off by default.
   */
  settleMs?: number
}

/**
 * Scrolls once to `#anchor` when the URL carries it and the section exists (`ready`): a section
 * rendered after the data is read appears after the browser gave up looking for it. The weather's
 * `#meteo` on a group's page (WEB-77) and on a ride's (WEB-79). With `settleMs`, it follows the
 * layout while it settles, as iOS Safari has no scroll anchoring (docs/LEDGER_*.md WEB-134).
 */
export function useScrollToAnchor(
  anchor: string,
  ready: boolean,
  { settleMs = 0 }: ScrollToAnchorOptions = {}
): void {
  const location = useLocation()
  const scrolledRef = useRef(false)
  const stopRef = useRef<(() => void) | null>(null)

  useEffect(() => {
    if (scrolledRef.current || !ready || location.hash !== `#${anchor}`) return
    scrolledRef.current = true
    const scroll = () => document.getElementById(anchor)?.scrollIntoView?.({ block: 'start' })
    scroll()
    if (settleMs <= 0 || typeof ResizeObserver === 'undefined') return

    const observer = new ResizeObserver(() => scroll())
    observer.observe(document.body)
    const stop = () => {
      observer.disconnect()
      clearTimeout(timer)
      USER_SCROLL_EVENTS.forEach((type) => window.removeEventListener(type, stop))
      stopRef.current = null
    }
    const timer = setTimeout(stop, settleMs)
    USER_SCROLL_EVENTS.forEach((type) => window.addEventListener(type, stop, { passive: true }))
    stopRef.current = stop
  }, [anchor, ready, location.hash, settleMs])

  // Only on unmount: the effect above re-runs on every `ready` change and must not end the window.
  useEffect(() => () => stopRef.current?.(), [])
}
