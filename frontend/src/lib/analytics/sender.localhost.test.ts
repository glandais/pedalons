// @vitest-environment-options { "url": "http://localhost:5173/" }
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { ConfigDto } from '@/api/dto'
import { seedAppConfig } from '@/config/appConfig'
import { sendPageView } from './sender'

// A workstation never counts, even with the flag set (docs/LEDGER_*.md WEB-90).
describe('sendPageView on a loopback host', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    seedAppConfig({} as ConfigDto)
  })

  it('sends nothing on localhost', () => {
    const fetchMock = vi.fn()
    vi.stubGlobal('fetch', fetchMock)
    seedAppConfig({ analytics: { countPath: '/count' } } as unknown as ConfigDto)
    sendPageView({ p: '/localhost:5173', t: 'home · public' })
    expect(fetchMock).not.toHaveBeenCalled()
  })
})
