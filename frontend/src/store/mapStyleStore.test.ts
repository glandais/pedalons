import { beforeEach, describe, expect, it, vi } from 'vitest'

/** The store reads localStorage when the module is evaluated: each case loads it afresh. */
async function loadStore() {
  vi.resetModules()
  const { useMapStyleStore } = await import('./mapStyleStore')
  return useMapStyleStore
}

describe('mapStyleStore lightInDark', () => {
  // The suite's localStorage is a bare mock (src/test/setup.ts): give it a memory for these cases.
  beforeEach(() => {
    const saved = new Map<string, string>()
    vi.mocked(localStorage.getItem).mockImplementation((key) => saved.get(key) ?? null)
    vi.mocked(localStorage.setItem).mockImplementation((key, value) => {
      saved.set(key, value)
    })
  })

  it('is off by default', async () => {
    expect((await loadStore()).getState().lightInDark).toBe(false)
  })

  it('takes over from a pick remembered as « (clair) » before WEB-177', async () => {
    localStorage.setItem('pedalons-map-style', 'cycling:light')
    expect((await loadStore()).getState().lightInDark).toBe(true)
  })

  it('does not read a former « (sombre) » pick as a wish for a light map', async () => {
    localStorage.setItem('pedalons-map-style', 'cycling:dark')
    expect((await loadStore()).getState().lightInDark).toBe(false)
  })

  it('prefers the switch once it has been touched, and remembers it', async () => {
    localStorage.setItem('pedalons-map-style', 'cycling:light')
    const store = await loadStore()
    store.getState().setLightInDark(false)
    expect(localStorage.getItem('pedalons-map-light-in-dark')).toBe('false')
    expect((await loadStore()).getState().lightInDark).toBe(false)
  })
})
