import { afterEach, describe, expect, it, vi } from 'vitest'
import { ANONYMOUS, resolveSsrSession } from './ssrSession'

function answer(status: number, body: unknown, setCookies: string[] = []): Response {
  const headers = new Headers({ 'Content-Type': 'application/json' })
  for (const cookie of setCookies) headers.append('Set-Cookie', cookie)
  return new Response(JSON.stringify(body), { status, headers })
}

describe('resolveSsrSession', () => {
  afterEach(() => {
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it('hands over the rotated session cookie with the session', async () => {
    const rotated = [
      'refresh_token=; Path=/api; Max-Age=0',
      'refresh_token=next; Path=/; HttpOnly; Secure; SameSite=Lax',
    ]
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => answer(200, { accessToken: 'at', user: null }, rotated))
    )
    const onSetCookie = vi.fn()

    const session = await resolveSsrSession({ cookie: 'refresh_token=previous' }, onSetCookie)

    expect(session?.accessToken).toBe('at')
    expect(onSetCookie).toHaveBeenCalledWith(rotated)
  })

  it('hands over nothing inside the grace of another rotation, where no cookie comes back', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => answer(200, { accessToken: 'at', user: null }))
    )
    const onSetCookie = vi.fn()

    await resolveSsrSession({ cookie: 'refresh_token=previous' }, onSetCookie)

    expect(onSetCookie).not.toHaveBeenCalled()
  })

  it('renders anonymously without a session cookie, and does not call the backend', async () => {
    const fetch = vi.fn()
    vi.stubGlobal('fetch', fetch)

    expect(await resolveSsrSession({ cookie: 'other=1' })).toEqual(ANONYMOUS)
    expect(fetch).not.toHaveBeenCalled()
  })

  // docs/LEDGER_*.md WEB-39: "no session" and "session unknown" are two different answers.
  it.each([401, 403])(
    'renders anonymously when the backend refuses the token (%i)',
    async (status) => {
      vi.stubGlobal(
        'fetch',
        vi.fn(async () => answer(status, { code: 'TOKEN_INVALID' }))
      )

      expect(await resolveSsrSession({ cookie: 'refresh_token=revoked' })).toEqual(ANONYMOUS)
    }
  )

  it.each([500, 502, 503, 429])(
    'leaves the session to the client when the backend fails (%i)',
    async (status) => {
      vi.spyOn(console, 'warn').mockImplementation(() => {})
      vi.stubGlobal(
        'fetch',
        vi.fn(async () => answer(status, {}))
      )

      expect(await resolveSsrSession({ cookie: 'refresh_token=live' })).toBeUndefined()
    }
  )

  it('leaves the session to the client when the refresh times out', async () => {
    vi.spyOn(console, 'error').mockImplementation(() => {})
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new DOMException('The operation was aborted due to timeout', 'TimeoutError')
      })
    )
    const onSetCookie = vi.fn()

    expect(await resolveSsrSession({ cookie: 'refresh_token=live' }, onSetCookie)).toBeUndefined()
    expect(onSetCookie).not.toHaveBeenCalled()
  })
})
