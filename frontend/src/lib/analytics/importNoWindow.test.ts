import { afterEach, describe, expect, it, vi } from 'vitest'

// App.tsx imports lib/analytics, and App.tsx is in the SSR bundle: importing the module must touch
// no browser global (docs/plans/2026-10-15-web-analytics.md §4.3, docs/LEDGER_*.md WEB-90). The
// shared test setup needs a DOM, so the browser globals are removed here instead, before a fresh
// import: a read of any of them at import would throw.
describe('lib/analytics without a browser', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    vi.resetModules()
  })

  it('imports without window, navigator, document nor localStorage', async () => {
    vi.resetModules()
    for (const name of ['window', 'navigator', 'document', 'localStorage', 'screen']) {
      vi.stubGlobal(name, undefined)
    }
    expect(typeof window).toBe('undefined')
    expect(typeof navigator).toBe('undefined')

    const analytics = await import('./index')
    const hooks = await import('./useAnalyticsOptOut')
    expect(typeof analytics.installPageViewCounter).toBe('function')
    expect(typeof hooks.useAnalyticsOptedOut).toBe('function')
  }, 60_000) // a fresh import pulls the whole route table in: slower than 5 s on a cold cache
})
