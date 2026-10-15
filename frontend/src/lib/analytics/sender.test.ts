// @vitest-environment-options { "url": "https://club-exemple.fr/equipes/equipe-privee?token=SECRET#frag" }
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { ConfigDto } from '@/api/dto'
import { seedAppConfig } from '@/config/appConfig'
import { OPT_OUT_KEY, setAnalyticsOptedOut } from './optOut'
import { COUNT_FETCH_OPTIONS, buildCountUrl, screenSizeCategory, sendPageView } from './sender'
import type { CountHit } from './countHit'

/** What the sender may put on the wire (docs/plans/2026-10-15-web-analytics.md §4.3, WEB-90). */

const HIT: CountHit = {
  p: '/club-exemple.fr/equipes/equipe-privee/sorties/:rideSlug',
  t: 'ride-detail · public',
  r: 'https://www.google.fr',
}

const config = (analytics: ConfigDto['analytics']) => ({ analytics }) as unknown as ConfigDto

let fetchMock: ReturnType<typeof vi.fn>
let beacon: ReturnType<typeof vi.fn>

function setNavigator(name: string, value: unknown) {
  Object.defineProperty(navigator, name, { value, configurable: true })
}

/** The shared setup mocks localStorage with no memory: the opposition needs a real one here. */
function memoryStorage(): Storage {
  const items = new Map<string, string>()
  return {
    get length() {
      return items.size
    },
    clear: () => items.clear(),
    getItem: (key) => items.get(key) ?? null,
    key: (index) => [...items.keys()][index] ?? null,
    removeItem: (key) => void items.delete(key),
    setItem: (key, value) => void items.set(key, String(value)),
  }
}
const storage = memoryStorage()

beforeEach(() => {
  fetchMock = vi.fn(() => Promise.resolve(new Response(null, { status: 200 })))
  vi.stubGlobal('fetch', fetchMock)
  beacon = vi.fn(() => true)
  setNavigator('sendBeacon', beacon)
  setNavigator('doNotTrack', null)
  setNavigator('globalPrivacyControl', undefined)
  setNavigator('webdriver', false)
  vi.stubGlobal('localStorage', storage)
  storage.clear()
  vi.stubGlobal('screen', { width: 390 })
  seedAppConfig(config({ countPath: '/count' }))
})

afterEach(() => {
  vi.unstubAllGlobals()
  seedAppConfig(config(undefined))
})

function sentParams(): URLSearchParams {
  expect(fetchMock).toHaveBeenCalledTimes(1)
  const [url] = fetchMock.mock.calls[0] as [string, RequestInit]
  expect(url.startsWith('/count?')).toBe(true)
  return new URL(url, 'https://club-exemple.fr').searchParams
}

describe('buildCountUrl', () => {
  it('sends p, t, r, a size category s and rnd — never q, b nor e', () => {
    const url = buildCountUrl('/count', HIT, 390.6, 'abcde')
    const params = new URL(url, 'https://x.test').searchParams
    expect([...params.keys()].sort()).toEqual(['p', 'r', 's', 't', 'rnd'].sort())
    expect(params.get('p')).toBe(HIT.p)
    expect(params.get('t')).toBe(HIT.t)
    expect(params.get('r')).toBe('https://www.google.fr')
    expect(params.get('s')).toBe('600')
    for (const name of ['q', 'b', 'e']) expect(params.has(name)).toBe(false)
  })

  it('leaves r out when the hit has none, and s when the width is unknown', () => {
    const params = new URL(
      buildCountUrl('/count', { p: '/h', t: 'home · public' }, 0, 'abcde'),
      'https://x.test'
    ).searchParams
    expect(params.has('r')).toBe(false)
    expect(params.has('s')).toBe(false)
  })
})

describe('screenSizeCategory', () => {
  it.each([
    [320, 600],
    [390.6, 600],
    [600, 600],
    [601, 1000],
    [1000, 1000],
    [1366, 1920],
    [1920, 1920],
    [1921, 2560],
    [5120, 2560],
  ])('sends %s px as the bucket bound %s, never the width itself', (width, category) => {
    expect(screenSizeCategory(width)).toBe(category)
  })

  it('is undefined for an unknown width', () => {
    for (const width of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
      expect(screenSizeCategory(width)).toBeUndefined()
    }
  })
})

describe('sendPageView', () => {
  it('fetches the same-origin counter without cookie, Referer nor cache, never by beacon', () => {
    sendPageView(HIT)
    const [, options] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(options).toEqual({
      keepalive: true,
      credentials: 'omit',
      referrerPolicy: 'no-referrer',
      cache: 'no-store',
    })
    expect(options).toBe(COUNT_FETCH_OPTIONS)
    expect(beacon).not.toHaveBeenCalled()
  })

  it('sends the hit and nothing of the page URL', () => {
    sendPageView(HIT)
    const params = sentParams()
    expect(params.get('p')).toBe(HIT.p)
    expect(params.get('s')).toBe('600')
    const [url] = fetchMock.mock.calls[0] as [string]
    expect(url).not.toContain('SECRET')
    expect(url).not.toContain('frag')
    for (const name of ['q', 'b', 'e']) expect(params.has(name)).toBe(false)
  })

  it('sends nothing without the analytics config', () => {
    seedAppConfig(config(undefined))
    sendPageView(HIT)
    seedAppConfig({} as ConfigDto)
    sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('sends nothing under Do Not Track', () => {
    setNavigator('doNotTrack', '1')
    sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('sends nothing under Global Privacy Control', () => {
    setNavigator('globalPrivacyControl', true)
    sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('sends nothing once opted out, and again once the opposition is withdrawn', () => {
    setAnalyticsOptedOut(true)
    expect(localStorage.getItem(OPT_OUT_KEY)).toBe('1')
    sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
    setAnalyticsOptedOut(false)
    sendPageView(HIT)
    expect(fetchMock).toHaveBeenCalledTimes(1)
  })

  it('keeps the opposition across a reload of the module', async () => {
    setAnalyticsOptedOut(true)
    vi.resetModules()
    const fresh = await import('./sender')
    const freshConfig = await import('@/config/appConfig')
    freshConfig.seedAppConfig(config({ countPath: '/count' }))
    fresh.sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('sends nothing from a driven browser', () => {
    setNavigator('webdriver', true)
    sendPageView(HIT)
    expect(fetchMock).not.toHaveBeenCalled()
  })

  it('sends nothing from a prerendered page', () => {
    Object.defineProperty(document, 'prerendering', { value: true, configurable: true })
    try {
      sendPageView(HIT)
      expect(fetchMock).not.toHaveBeenCalled()
    } finally {
      Object.defineProperty(document, 'prerendering', { value: false, configurable: true })
    }
  })

  it('survives a refused fetch', async () => {
    fetchMock.mockImplementation(() => Promise.reject(new TypeError('blocked')))
    expect(() => sendPageView(HIT)).not.toThrow()
    fetchMock.mockImplementation(() => {
      throw new TypeError('keepalive quota')
    })
    expect(() => sendPageView(HIT)).not.toThrow()
  })
})
