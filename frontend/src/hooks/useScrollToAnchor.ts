import { useEffect, useRef } from 'react'
import { useLocation } from 'react-router-dom'

/**
 * Scrolls once to `#anchor` when the URL carries it and the section exists (`ready`): a section
 * rendered after the data is read appears after the browser gave up looking for it. The weather's
 * `#meteo` on a group's page (WEB-77) and on a ride's (WEB-79).
 */
export function useScrollToAnchor(anchor: string, ready: boolean): void {
  const location = useLocation()
  const scrolledRef = useRef(false)
  useEffect(() => {
    if (scrolledRef.current || !ready || location.hash !== `#${anchor}`) return
    scrolledRef.current = true
    document.getElementById(anchor)?.scrollIntoView?.({ block: 'start' })
  }, [anchor, ready, location.hash])
}
