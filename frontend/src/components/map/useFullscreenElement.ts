import { useSyncExternalStore } from 'react'

function subscribe(onChange: () => void) {
  document.addEventListener('fullscreenchange', onChange)
  return () => document.removeEventListener('fullscreenchange', onChange)
}

/**
 * The element shown in browser fullscreen (MapLibre's `FullscreenControl`), or `undefined`.
 *
 * In fullscreen the browser renders that element alone: a portal into `<body>` — a map panel, a
 * tooltip — is still in the DOM but never on screen. Passing this as the portal's `target` keeps it
 * inside the fullscreen map, and back in `<body>` (`undefined`) once the map leaves fullscreen.
 */
export function useFullscreenElement(): HTMLElement | undefined {
  return useSyncExternalStore(
    subscribe,
    () => (document.fullscreenElement as HTMLElement | null) ?? undefined,
    () => undefined
  )
}
