import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

/** A fresh module per page load: the reload a test asks for starts a new page. */
async function newPage() {
  vi.resetModules()
  return import('./staleChunk')
}

describe('staleChunk', () => {
  const reload = vi.fn()

  beforeEach(() => {
    sessionStorage.clear()
    reload.mockClear()
    vi.stubGlobal('location', { ...window.location, reload })
  })

  afterEach(() => {
    vi.unstubAllGlobals()
    vi.useRealTimers()
  })

  it('recognises a lazy chunk the deploy removed, in each browser wording', async () => {
    const { isStaleChunkError } = await newPage()
    expect(
      isStaleChunkError(
        new TypeError(
          'Failed to fetch dynamically imported module: https://www.pedalons.fr/assets/UserProfilePage-DXThapHx.js'
        )
      )
    ).toBe(true)
    expect(isStaleChunkError(new TypeError('Importing a module script failed.'))).toBe(true)
    expect(isStaleChunkError(new TypeError('error loading dynamically imported module'))).toBe(true)
    expect(isStaleChunkError(new TypeError('x is undefined'))).toBe(false)
  })

  it('keeps every failure of the page that asked for the reload quiet, reloading once', async () => {
    // The hovered link's prefetch fails first, then the click's import (feedback #10, #12, #13).
    const { reloadForStaleChunk } = await newPage()
    expect(reloadForStaleChunk()).toBe(true)
    expect(reloadForStaleChunk()).toBe(true)
    expect(reload).toHaveBeenCalledTimes(1)
  })

  it('lets the error show if the chunk still fails right after the reload', async () => {
    vi.useFakeTimers()
    expect((await newPage()).reloadForStaleChunk()).toBe(true)

    const reloaded = await newPage()
    expect(reloaded.reloadForStaleChunk()).toBe(false)
    expect(reload).toHaveBeenCalledTimes(1)

    vi.advanceTimersByTime(31_000)
    expect(reloaded.reloadForStaleChunk()).toBe(true)
    expect(reload).toHaveBeenCalledTimes(2)
  })
})
