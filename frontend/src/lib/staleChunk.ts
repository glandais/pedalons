/**
 * A tab opened before a deploy still runs the previous build, whose lazy chunks
 * (`UserProfilePage-<hash>.js`) the new image no longer serves: the next lazy route fails with
 * « Failed to fetch dynamically imported module ». Reloading the page picks up the new build and
 * its chunks — what the member would have to do by hand on the error screen.
 *
 * At most one reload per {@link RELOAD_WINDOW_MS}: if the chunk still fails right after a reload,
 * the problem is not a stale tab (the server or the network is down), and looping would hide it.
 *
 * Once this page has asked for a reload, every later stale chunk is the same old build: it waits
 * for the reload instead of reaching the error screen and the error reports. A link hovered just
 * before the click prefetches the chunk, so the click's own import used to fail inside the 30 s
 * window and get reported (glandais/pedalons-feedback#10, #12, #13).
 */

const RELOAD_KEY = 'pedalons-stale-chunk-reload'
const RELOAD_WINDOW_MS = 30_000

/** Reset by the reload itself, which starts a new page. */
let reloading = false

/** Chrome, Firefox and Safari word it differently; Vite adds its own for CSS. */
const STALE_CHUNK = [
  /Failed to fetch dynamically imported module/,
  /error loading dynamically imported module/,
  /Importing a module script failed/,
  /Unable to preload CSS/,
]

export function isStaleChunkError(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error)
  return STALE_CHUNK.some((pattern) => pattern.test(message))
}

/** Reloads the page unless it was already reloaded for this reason moments ago. */
export function reloadForStaleChunk(): boolean {
  if (reloading) return true
  try {
    const last = Number(sessionStorage.getItem(RELOAD_KEY) ?? 0)
    if (Date.now() - last < RELOAD_WINDOW_MS) return false
    sessionStorage.setItem(RELOAD_KEY, String(Date.now()))
  } catch {
    // Without sessionStorage there is no loop guard: let the error screen show instead.
    return false
  }
  reloading = true
  window.location.reload()
  return true
}

/** Vite emits `vite:preloadError` when a dynamic import or one of its preloads fails. */
export function installStaleChunkReload(): void {
  if (typeof window === 'undefined') return
  // No preventDefault: Vite would resolve the import with `undefined`, which `lazyPage` turns into
  // an unrelated TypeError. The rethrown error reaches ErrorBoundary or the error capture, which
  // see the pending reload and stay quiet.
  window.addEventListener('vite:preloadError', () => {
    reloadForStaleChunk()
  })
}
