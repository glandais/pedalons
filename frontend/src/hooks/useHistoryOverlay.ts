import { useCallback, useEffect, useId, useRef, useState } from 'react'

/** Key of the marker an overlay leaves in `history.state`. */
const STATE_KEY = 'plannerFullscreen'

function currentMarker(): unknown {
  const state: unknown = window.history.state
  return state && typeof state === 'object' ? (state as Record<string, unknown>)[STATE_KEY] : null
}

/**
 * An overlay with no URL of its own (the planner's fullscreen editor) that the browser's back
 * button closes.
 *
 * Opening pushes a history entry with the same URL and the current `history.state` copied (React
 * Router keeps its `key`, `idx` and `usr` there, so on the way back it sees a pop to the very
 * location it is already on). Closing consumes that entry with `history.back()`; the overlay
 * itself follows `popstate`, so back closes it and forward reopens it.
 *
 * It deliberately does not go through the router's `navigate()`: that would be a PUSH with a fresh
 * location key, which scrolls to the top (`useScrollRestoration`) and counts a page view.
 *
 * Nothing here touches `window` while rendering — only handlers and effects — so it is safe to
 * server-render.
 */
export function useHistoryOverlay() {
  const instanceId = useId()
  const [opened, setOpened] = useState(false)
  // One token per opening, kept in history.state: a marker left by a previous page load (or by an
  // earlier opening) never matches, so it can not reopen anything.
  const token = useRef<string | null>(null)

  const isOurEntry = useCallback(
    () => token.current !== null && currentMarker() === token.current,
    []
  )

  const open = useCallback(() => {
    if (isOurEntry()) return
    token.current = `${instanceId}:${Date.now()}`
    window.history.pushState({ ...window.history.state, [STATE_KEY]: token.current }, '')
    setOpened(true)
  }, [instanceId, isOurEntry])

  const close = useCallback(() => {
    if (isOurEntry()) {
      // The closing arrives through popstate.
      window.history.back()
    } else {
      setOpened(false)
    }
  }, [isOurEntry])

  const mounted = useRef(false)
  useEffect(() => {
    mounted.current = true
    // A marker that is not ours (page reloaded, or left by an earlier instance) is dead: strip it,
    // so that it is never mistaken for an open overlay. The entry itself stays in the history: a
    // reload while the overlay was open leaves one back step that lands on the same page, a
    // limitation accepted rather than rewriting the history the router owns.
    if (!isOurEntry() && currentMarker()) {
      window.history.replaceState(
        { ...(window.history.state as Record<string, unknown>), [STATE_KEY]: undefined },
        ''
      )
    }
    const onPopState = () => setOpened(isOurEntry())
    window.addEventListener('popstate', onPopState)
    return () => {
      mounted.current = false
      window.removeEventListener('popstate', onPopState)
      // Unmounted while open on our own entry (the form closed by code): consume the entry.
      // After a navigation the current entry is another one, and there is nothing to undo.
      // Deferred a tick: React's development remount (StrictMode) runs this cleanup and mounts
      // again at once, which must not close an overlay opened during the first mount.
      setTimeout(() => {
        if (!mounted.current && isOurEntry()) window.history.back()
      }, 0)
    }
  }, [isOurEntry])

  return { opened, open, close }
}
