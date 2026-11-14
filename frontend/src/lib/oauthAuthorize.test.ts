import { describe, expect, it } from 'vitest'
import { deniedRedirect, isUsableRedirectUri, parseAuthorizeParams } from './oauthAuthorize'

const CHALLENGE = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM'

function search(overrides: Record<string, string | null> = {}) {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: 'Mon appli',
    redirect_uri: 'https://app.example.org/callback',
    code_challenge: CHALLENGE,
    code_challenge_method: 'S256',
    state: 'abc',
  })
  for (const [key, value] of Object.entries(overrides)) {
    if (value === null) params.delete(key)
    else params.set(key, value)
  }
  return params
}

describe('parseAuthorizeParams', () => {
  it('reads a complete request', () => {
    expect(parseAuthorizeParams(search())).toEqual({
      clientId: 'Mon appli',
      redirectUri: 'https://app.example.org/callback',
      codeChallenge: CHALLENGE,
      state: 'abc',
    })
  })

  it('takes a request without state', () => {
    expect(parseAuthorizeParams(search({ state: null }))?.state).toBeUndefined()
  })

  it.each([
    ['another response type', { response_type: 'token' }],
    ['no client', { client_id: null }],
    ['a blank client', { client_id: '  ' }],
    ['a client name with a bidi override', { client_id: 'app\u202Egpj.exe' }],
    ['no redirect', { redirect_uri: null }],
    ['no challenge', { code_challenge: null }],
    ['a challenge that is not a SHA-256', { code_challenge: 'short' }],
    ['a plain challenge', { code_challenge_method: 'plain' }],
    ['no challenge method', { code_challenge_method: null }],
  ])('refuses %s', (_, overrides) => {
    expect(parseAuthorizeParams(search(overrides))).toBeNull()
  })
})

describe('isUsableRedirectUri', () => {
  it.each([
    'https://app.example.org/callback',
    'http://localhost:8765/cb?x=1',
    'myapp://callback',
    'com.example.app:/oauth',
  ])('accepts %s', (uri) => {
    expect(isUsableRedirectUri(uri)).toBe(true)
  })

  it.each([
    'javascript:alert(1)',
    'JavaScript:alert(1)',
    'data:text/html,x',
    '/relative',
    '//host/path',
    'https://app.example.org/cb#fragment',
    'https://app.example.org/a b',
    'https://pedalons.fr@elsewhere.example/cb',
    'https://app.example.org/\u202Ecb',
  ])('refuses %s', (uri) => {
    expect(isUsableRedirectUri(uri)).toBe(false)
  })
})

describe('deniedRedirect', () => {
  it('appends the error and the state', () => {
    const params = parseAuthorizeParams(search({ state: 'a b&c' }))!
    expect(deniedRedirect(params)).toBe(
      'https://app.example.org/callback?error=access_denied&state=a+b%26c'
    )
  })

  it('keeps an existing query, and a deep link as it is', () => {
    const params = parseAuthorizeParams(search({ redirect_uri: 'myapp://cb?from=x', state: null }))!
    expect(deniedRedirect(params)).toBe('myapp://cb?from=x&error=access_denied')
  })
})
