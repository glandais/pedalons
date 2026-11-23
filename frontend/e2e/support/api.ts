import { mkdirSync, renameSync, writeFileSync } from 'node:fs'
import { dirname } from 'node:path'
import { request, type APIRequestContext, type APIResponse } from '@playwright/test'
import { linkTokenIn, mailbox, otpCodeIn, waitForNewMail } from './mailpit'
import { stack } from './stack'

/**
 * Talks to the real REST API from Node, to log in and seed data without going through the UI.
 *
 * Logins go through the same endpoints as the app — OTP read from mailpit, e-mail verification link
 * read from mailpit — so there is no test-only backdoor in the backend.
 */

export interface AuthResponse {
  accessToken: string
  refreshToken: string
  user: { id: string; email: string; displayName: string }
}

/**
 * A request context with no cookie jar shared with anyone: the backend reads the refresh_token
 * cookie before the X-Refresh-Token header, so a jar that saw another user's login would refresh as
 * that user.
 */
export async function apiContext(accessToken?: string): Promise<APIRequestContext> {
  return request.newContext({
    baseURL: stack.baseURL,
    extraHTTPHeaders: accessToken ? { Authorization: `Bearer ${accessToken}` } : {},
  })
}

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | undefined,
    message: string
  ) {
    super(message)
  }
}

export async function expectOk<T>(response: APIResponse): Promise<T> {
  if (response.ok()) {
    const text = await response.text()
    return (text ? JSON.parse(text) : undefined) as T
  }
  const body = await response.text()
  let code: string | undefined
  try {
    code = (JSON.parse(body) as { code?: string }).code
  } catch {
    // not JSON — keep the raw body in the message
  }
  throw new ApiError(response.status(), code, `${response.url()} → ${response.status()} ${body}`)
}

/** Whoever an API call is made as: a session, or nobody (an anonymous visitor). */
export type Caller = Pick<AuthResponse, 'accessToken'> | undefined

/** Runs `run` with a fresh request context signed in as `who`, and disposes of it afterwards. */
export async function withApi<T>(who: Caller, run: (api: APIRequestContext) => Promise<T>) {
  const api = await apiContext(who?.accessToken)
  try {
    return await run(api)
  } finally {
    await api.dispose()
  }
}

type Params = Record<string, string | number | boolean>

/** GET as `who`; the parsed body, or an ApiError. */
export const apiGet = <T>(who: Caller, path: string, params?: Params) =>
  withApi(who, async (api) => expectOk<T>(await api.get(path, { params })))

/** GET as `who`; the parsed body, or null when the API answers 404 (a deleted or unknown entity). */
export const apiGetOrNull = <T>(who: Caller, path: string, params?: Params) =>
  withApi(who, async (api) => {
    const response = await api.get(path, { params })
    return response.status() === 404 ? null : expectOk<T>(response)
  })

export const apiPost = <T>(who: Caller, path: string, data?: unknown) =>
  withApi(who, async (api) => expectOk<T>(await api.post(path, { data })))

export const apiPut = <T>(who: Caller, path: string, data: unknown) =>
  withApi(who, async (api) => expectOk<T>(await api.put(path, { data })))

export const apiPatch = <T>(who: Caller, path: string, data: unknown) =>
  withApi(who, async (api) => expectOk<T>(await api.patch(path, { data })))

export const apiDelete = (who: Caller, path: string) =>
  withApi(who, async (api) => expectOk(await api.delete(path)))

/** OTP login. Rate-limited to 3 requests per 5 minutes per address — don't call it per test. */
export async function loginWithOtp(email: string): Promise<AuthResponse> {
  const seen = await mailbox(email)
  await apiPost(undefined, '/api/auth/otp', { email })
  const code = otpCodeIn(await waitForNewMail(email, seen))
  return apiPost<AuthResponse>(undefined, '/api/auth/otp/verify', { email, code })
}

export const loginWithPassword = (email: string, password: string) =>
  retryOn429(() => apiPost<AuthResponse>(undefined, '/api/auth/login', { email, password }))

/**
 * Runs a password login again while it gets 429. The password throttle counts an admitted login as
 * a failure until it succeeds (docs/LEDGER_*.md SEC-36): past five logins in flight for one address,
 * the next is refused although none fails — and every worker signs the seeded admin in at once
 * (roleSession) when the suite starts. A refused login records nothing, so it is simply tried again
 * a moment later; any other error is thrown. No test expects a password login's 429: the throttle
 * itself is covered by the backend's tests.
 */
export async function retryOn429<T>(login: () => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await login()
    } catch (e) {
      if (!(e instanceof ApiError) || e.status !== 429 || attempt === 8) throw e
      await new Promise((resolve) => setTimeout(resolve, 250 * attempt))
    }
  }
}

/**
 * Sign-up as the app does it: register, then follow the verification link from the mail and choose
 * the password there — sign-up itself takes none (SEC-24).
 */
export async function register(account: {
  email: string
  displayName: string
  password: string
}): Promise<AuthResponse> {
  const { password, ...signUp } = account
  const seen = await mailbox(account.email)
  await apiPost(undefined, '/api/auth/register', { ...signUp, acceptTerms: true })
  const token = linkTokenIn(await waitForNewMail(account.email, seen))
  return apiPost<AuthResponse>(undefined, '/api/auth/verify-email', { token, password })
}

/**
 * Sets the password of an account through the mailed reset link, as a member who forgot it would.
 * The reset ends every session of the account.
 */
export async function resetPassword(email: string, newPassword: string): Promise<void> {
  const seen = await mailbox(email)
  await apiPost(undefined, '/api/auth/forgot-password', { email })
  const token = linkTokenIn(await waitForNewMail(email, seen))
  await apiPost(undefined, '/api/auth/reset-password', { token, newPassword })
}

/**
 * A fresh access token for a session, or null once the session is gone (stack reset, revocation:
 * the backend answers 4xx). Any other failure throws — concurrent refreshes of one session used to
 * answer 500 (optimistic lock on User, fixed 2026-09-25) and auth.e2e.ts pins that they no longer do,
 * so there is nothing to retry.
 *
 * **The refresh rotates the token** (docs/LEDGER_*.md SEC-27): `refreshToken` of the result is the
 * one to use next — the one passed in only survives a minute, and presented after that it revokes
 * the session. Within that minute, or when a concurrent refresh already rotated it, the backend
 * sends no new token and the one passed in is given back. A session is therefore held by one
 * owner: the test (an AuthResponse), or a browser context (its cookie), never both — see signIn().
 */
export async function refresh(refreshToken: string): Promise<AuthResponse | null> {
  return withApi(undefined, async (api) => {
    const response = await api.post('/api/auth/refresh', {
      headers: { 'X-Refresh-Token': refreshToken },
    })
    if (response.ok()) {
      const auth = (await response.json()) as Omit<AuthResponse, 'refreshToken'> & {
        refreshToken?: string | null
      }
      return { ...auth, refreshToken: auth.refreshToken ?? refreshToken }
    }
    if (response.status() < 500) return null
    throw new Error(`POST /api/auth/refresh → ${response.status()}: ${await response.text()}`)
  })
}

/**
 * Refreshes the session `holder` owns and keeps the rotated token in it, so that the next refresh
 * through the same holder presents the current token rather than a replay.
 */
export async function refreshHeld(holder: { refreshToken: string }): Promise<AuthResponse | null> {
  const auth = await refresh(holder.refreshToken)
  if (auth) holder.refreshToken = auth.refreshToken
  return auth
}

/**
 * Writes a Playwright storageState holding the session cookie, exactly as the backend sets it
 * (RefreshTokenCookieFactory): path=/, httpOnly, SameSite=Lax, Secure — Chromium sends Secure
 * cookies to http://localhost, which counts as a secure context.
 */
export function writeStorageState(path: string, refreshToken: string) {
  writeFileAtomic(path, JSON.stringify(storageStateOf(refreshToken), null, 2))
}

/** The same storageState as an object, for a `storageState` fixture. */
export function storageStateOf(refreshToken: string) {
  const { hostname } = new URL(stack.baseURL)
  return {
    cookies: [
      {
        name: 'refresh_token',
        value: refreshToken,
        domain: hostname,
        path: '/',
        expires: Math.floor(Date.now() / 1000) + 30 * 24 * 3600,
        httpOnly: true,
        secure: true,
        sameSite: 'Lax' as const,
      },
    ],
    origins: [],
  }
}

/**
 * Several Playwright runs may share one stack, each running global-setup: a reader must never see a
 * half-written session or seed file.
 */
export function writeFileAtomic(path: string, content: string) {
  mkdirSync(dirname(path), { recursive: true })
  const tmp = `${path}.${process.pid}.tmp`
  writeFileSync(tmp, content)
  renameSync(tmp, path)
}
