/**
 * Imported first by the entry. The planner's stores read `localStorage` when their module loads
 * (remembered basemap, routing profile, folded profile strip); a WebView whose DOM storage is off,
 * or which refuses it to a page loaded from a file, would fail the whole page there. With no
 * usable storage the choices last the session, in memory.
 */
function usable(): boolean {
  try {
    window.localStorage.getItem('pedalons-probe')
    return true
  } catch {
    return false
  }
}

if (!usable()) {
  const entries = new Map<string, string>()
  const memory: Storage = {
    get length() {
      return entries.size
    },
    clear: () => entries.clear(),
    getItem: (key) => entries.get(key) ?? null,
    key: (index) => [...entries.keys()][index] ?? null,
    removeItem: (key) => {
      entries.delete(key)
    },
    setItem: (key, value) => {
      entries.set(key, String(value))
    },
  }
  Object.defineProperty(window, 'localStorage', { value: memory, configurable: true })
}
