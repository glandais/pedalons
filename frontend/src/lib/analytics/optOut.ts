/**
 * The visitor's opposition to the audience measurement, kept in this browser's storage for this
 * site only (docs/plans/2026-10-15-web-analytics.md §4.4, docs/LEDGER_*.md WEB-90).
 *
 * Deliberately NOT stored on the account: that would tie the measurement to a person, which the
 * CNIL exemption rules out. A `localStorage` key belongs to one origin, so every club domain, every
 * alias and every browser needs its own — the switch's label says so. Do Not Track and Global
 * Privacy Control are the only signals that hold for every site at once.
 *
 * Touches no browser global at import: the SSR bundle imports it.
 */

/** Listed in §8 of the privacy policy: rename it there too. */
export const OPT_OUT_KEY = 'pedalons-analytics-optout'

const listeners = new Set<() => void>()

/** True when this browser opposed the measurement on this site. Read again at every send. */
export function isAnalyticsOptedOut(): boolean {
  try {
    return localStorage.getItem(OPT_OUT_KEY) === '1'
  } catch {
    return false
  }
}

export function setAnalyticsOptedOut(optedOut: boolean): void {
  try {
    if (optedOut) localStorage.setItem(OPT_OUT_KEY, '1')
    else localStorage.removeItem(OPT_OUT_KEY)
  } catch {
    // Storage refused (private mode, quota): nothing to keep, and the switch says what was asked.
  }
  for (const listener of listeners) listener()
}

/**
 * `useSyncExternalStore` subscription: this tab's changes, and another tab's through the `storage`
 * event — both switches (profile and privacy page) follow either.
 */
export function subscribeAnalyticsOptOut(listener: () => void): () => void {
  listeners.add(listener)
  const onStorage = (event: StorageEvent) => {
    if (event.key === OPT_OUT_KEY || event.key === null) listener()
  }
  window.addEventListener('storage', onStorage)
  return () => {
    listeners.delete(listener)
    window.removeEventListener('storage', onStorage)
  }
}
