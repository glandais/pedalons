import { request, type APIRequestContext, type BrowserContext } from '@playwright/test'
import type {
  AdminDomainAliasDto,
  AdminDomainDto,
  AdminDomainListResponse,
  AdminUserDto,
  AssignPlatformRoleRequest,
  CreateDomainAliasRequest,
  CreateDomainRequest,
  TeamDetailDto,
  UpdateDomainAliasRequest,
} from '../../src/api/dto'
import { ApiError, apiGet, apiPost, apiPut, expectOk, type AuthResponse } from './api'
import { roleSession, SESSION_MAX_AGE_MS, teamRequest } from './data'
import { linkTokenIn, mailbox, waitForNewMail } from './mailpit'
import { keepRotatedSession, type RawDocument } from './ssr'
import { stack } from './stack'

/**
 * Other sites than `localhost` on the one e2e stack (multi-tenancy.e2e.ts, pinned-host.e2e.ts).
 *
 * The backend picks the tenant from the request's host (`DomainResolver`: `X-Forwarded-Host`, then
 * `Host`), and traefik routes every host to the app — so a second site needs no change to the
 * stack, only a `Domain` (or a `DomainAlias`) row, created through the platform admin's API:
 *
 * - `autre.localhost` — a second, independent domain: its own users, teams and content.
 * - `pin-e2e.localhost` — an alias of `localhost` pinned to one team: same users and content as
 *   `localhost`, but the app roots on that team and drops the `/equipes/<slug>` prefix.
 *
 * Both outlive a run, like the seed: every helper here is get-or-create, and safe when the desktop
 * and mobile projects race to create them. Chromium resolves every `*.localhost` to the loopback on
 * its own; Node does not, so API calls go to the stack's address with a `Host` header instead.
 */

const { port, protocol } = new URL(stack.baseURL)

export const OTHER_HOST = 'autre.localhost'
export const OTHER_NAME = 'Autre E2E'
export const PINNED_HOST = 'pin-e2e.localhost'
export const PINNED_NAME = 'Épinglé E2E'
/** The team the alias is pinned to — a public team of `localhost`, owned by the platform admin. */
const PINNED_TEAM = { name: 'Pin E2E', slug: 'pin-e2e' }

/** `host` with the stack's port — what a browser sends as `Host`. */
export const hostHeader = (host: string) => (port ? `${host}:${port}` : host)

/** The origin a browser opens for `host`, e.g. `http://autre.localhost:8190`. */
export const originOf = (host: string) => `${protocol}//${hostHeader(host)}`

/**
 * A request context reaching the stack as `host`, signed in with `accessToken` or anonymous. No
 * cookie jar is shared with anyone (see api.ts's apiContext).
 */
export function hostContext(host: string, accessToken?: string): Promise<APIRequestContext> {
  return request.newContext({
    baseURL: stack.baseURL,
    extraHTTPHeaders: {
      Host: hostHeader(host),
      ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
    },
  })
}

/** Runs `run` with a {@link hostContext}, disposed of afterwards. */
export async function onHost<T>(
  host: string,
  who: Pick<AuthResponse, 'accessToken'> | undefined,
  run: (api: APIRequestContext) => Promise<T>
): Promise<T> {
  const api = await hostContext(host, who?.accessToken)
  try {
    return await run(api)
  } finally {
    await api.dispose()
  }
}

export const hostGet = <T>(
  host: string,
  who: Pick<AuthResponse, 'accessToken'> | undefined,
  path: string
) => onHost(host, who, async (api) => expectOk<T>(await api.get(path)))

export const hostPost = <T>(
  host: string,
  who: Pick<AuthResponse, 'accessToken'> | undefined,
  path: string,
  data?: unknown
) => onHost(host, who, async (api) => expectOk<T>(await api.post(path, { data })))

export const hostPut = <T>(
  host: string,
  who: Pick<AuthResponse, 'accessToken'> | undefined,
  path: string,
  data: unknown
) => onHost(host, who, async (api) => expectOk<T>(await api.put(path, { data })))

/** The HTTP status `host` answers `path` with, as `who` (anonymous when undefined). */
export const hostStatus = (
  host: string,
  who: Pick<AuthResponse, 'accessToken'> | undefined,
  path: string
) => onHost(host, who, async (api) => (await api.get(path)).status())

/**
 * Sign-up on `host`, as the app does it there: register, then follow the verification link from the
 * mail. The account belongs to that host's domain only — the same address may hold another one on
 * every other domain.
 */
export async function registerOn(
  host: string,
  account: { email: string; displayName: string; password: string }
): Promise<AuthResponse & { password: string }> {
  const { password, ...signUp } = account
  const seen = await mailbox(account.email)
  await hostPost(host, undefined, '/api/auth/register', { ...signUp, acceptTerms: true })
  const token = linkTokenIn(await waitForNewMail(account.email, seen))
  const auth = await hostPost<AuthResponse>(host, undefined, '/api/auth/verify-email', {
    token,
    password,
  })
  return { ...auth, password }
}

export const loginOn = (host: string, email: string, password: string) =>
  hostPost<AuthResponse>(host, undefined, '/api/auth/login', { email, password })

/**
 * A fresh access token for `refreshToken`, asked of `host` — null when that host refuses it (4xx).
 */
export const refreshOn = (host: string, refreshToken: string) =>
  onHost(host, undefined, async (api) => {
    const response = await api.post('/api/auth/refresh', {
      headers: { 'X-Refresh-Token': refreshToken },
    })
    if (response.ok()) {
      // Rotated (docs/LEDGER_*.md SEC-27): the token to use next, or the same one inside the grace.
      const auth = (await response.json()) as AuthResponse
      return { ...auth, refreshToken: auth.refreshToken ?? refreshToken }
    }
    if (response.status() < 500) return null
    throw new Error(`POST /api/auth/refresh on ${host} → ${response.status()}`)
  })

/**
 * Signs a browser context in on `host`: the refresh_token cookie the backend would have set there.
 * Cookies are host-only, so a session on one host never travels to another.
 *
 * Like data.ts signIn(), the browser gets a session of its own when `auth` carries its password —
 * logged in on `host`: the token rotates at every refresh (docs/LEDGER_*.md SEC-27). A session
 * carried to a host that is not its own is handed over as it is — that host refuses it, which is
 * what such a test checks — even when the same address and password open another account there.
 */
export async function signInOn(
  context: BrowserContext,
  host: string,
  auth: AuthResponse & { password?: string }
) {
  const login = auth.password
    ? await loginOn(host, auth.user.email, auth.password).catch((e: unknown) => {
        if (e instanceof ApiError && e.status === 400) return undefined
        throw e
      })
    : undefined
  const own = login?.user.id === auth.user.id ? login : undefined
  await context.addCookies([
    {
      name: 'refresh_token',
      value: (own ?? auth).refreshToken,
      domain: host,
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'Lax',
    },
  ])
}

/** Get-or-create, tolerant of a concurrent creator: on a failed create, the winner's row is read. */
async function getOrCreate<T>(find: () => Promise<T | undefined>, create: () => Promise<T>) {
  const existing = await find()
  if (existing) return existing
  try {
    return await create()
  } catch (e) {
    const raced = await find()
    if (raced) return raced
    throw e
  }
}

async function findDomain(admin: AuthResponse, host: string) {
  const list = await apiGet<AdminDomainListResponse>(admin, '/api/admin/domains', { size: 100 })
  return list.domains.find((domain) => domain.domain === host)
}

/** The `autre.localhost` domain, created by the platform admin of `localhost` on first use. */
export async function otherDomain(): Promise<AdminDomainDto> {
  const admin = await roleSession('admin')
  const domain = await getOrCreate(
    () => findDomain(admin, OTHER_HOST),
    () =>
      apiPost<AdminDomainDto>(admin, '/api/admin/domains', {
        domain: OTHER_HOST,
        name: OTHER_NAME,
        baseUrl: originOf(OTHER_HOST),
        singleTeam: false,
        enableGpxPlanner: false,
      } satisfies CreateDomainRequest)
  )
  if (!domain.active) throw new Error(`${OTHER_HOST} exists but is disabled — re-enable it`)
  return domain
}

/** The platform admin of `autre.localhost` — a password account, so it never spends an OTP. */
const OTHER_ADMIN = {
  email: 'admin-autre@e2e.test',
  displayName: 'Admin Autre E2E',
  password: 'e2e-autre-admin-password',
}

let otherAdminSession: { auth: Promise<AuthResponse>; at: number } | undefined

/**
 * Runs `call` again (up to three times, after a short random pause) when it fails with a 500.
 *
 * Only for the other admin's promotion. global-setup runs it once per run, but two runs may share a
 * stack (writeFileAtomic): concurrent updates of one `User` row lose the optimistic lock on all but
 * one transaction. (Concurrent logins no longer do: since 6ba4d460 a login records `lastLoginAt`
 * without bumping the user's version.)
 */
async function retryOn500<T>(call: () => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    try {
      return await call()
    } catch (e) {
      if (!(e instanceof ApiError) || e.status !== 500 || attempt === 3) throw e
      await new Promise((resolve) => setTimeout(resolve, 200 + Math.random() * 800))
    }
  }
}

const logInOtherAdmin = () => loginOn(OTHER_HOST, OTHER_ADMIN.email, OTHER_ADMIN.password)

/**
 * Creates `autre.localhost` and its platform admin — signed up there, then promoted by the admin of
 * `localhost`, whose admin API reaches every domain's users. Run **once, by global-setup**, before
 * any worker starts.
 *
 * Not per worker: finding out whether the account exists takes a password login, and on a fresh
 * stack that login fails. Every failure counts towards the password throttle (docs/LEDGER_*.md
 * SEC-7, unknown addresses included): all the workers of both projects probing at once closed the
 * address for 15 minutes at the fifth, and the next ones got 429 LOGIN_RATE_LIMITED. Here, serially,
 * the one failed probe of a fresh stack is wiped by the login that follows.
 */
export async function ensureOtherAdmin(): Promise<void> {
  await otherDomain()
  let auth: AuthResponse
  try {
    auth = await logInOtherAdmin()
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 400) throw e
    auth = await registerOn(OTHER_HOST, OTHER_ADMIN)
  }
  const admin = await roleSession('admin')
  const user = `/api/admin/users/${auth.user.id}`
  if ((await apiGet<AdminUserDto>(admin, user)).platformRole !== 'PLATFORM_ADMIN')
    await retryOn500(() =>
      apiPut(admin, `${user}/platform-role`, {
        role: 'PLATFORM_ADMIN',
      } satisfies AssignPlatformRoleRequest)
    )
}

/**
 * A platform admin of `autre.localhost`, which global-setup created (ensureOtherAdmin): signed in by
 * password, cached per worker for {@link SESSION_MAX_AGE_MS} like roleSession() — a login per worker, never a session saved between runs, whose token
 * would rotate under every worker that refreshed it (docs/LEDGER_*.md SEC-27). Needed for anything
 * only a platform admin may do on that domain (a public team, say).
 */
export function otherAdmin(): Promise<AuthResponse> {
  // Renewed like roleSession(): the access token lives 15 minutes, and a worker that signed in for
  // multi-tenancy.e2e.ts reaches ssr-session.e2e.ts long after — a token cached for good gets a 401.
  if (otherAdminSession && Date.now() - otherAdminSession.at < SESSION_MAX_AGE_MS)
    return otherAdminSession.auth
  const auth = logInOtherAdmin()
  const entry = { auth, at: Date.now() }
  otherAdminSession = entry
  // A failure is not cached: the next caller tries again.
  auth.catch(() => {
    if (otherAdminSession === entry) otherAdminSession = undefined
  })
  return auth
}

/**
 * A team on `host`, owned by `owner`; made PUBLIC afterwards by `admin` (a platform admin of that
 * domain) when asked — POST always creates a TEAM-visible team, as on `localhost` (data.ts newTeam).
 */
export async function newTeamOn(
  host: string,
  owner: AuthResponse,
  name: string,
  { visibility = 'TEAM', admin }: { visibility?: 'TEAM' | 'PUBLIC'; admin?: AuthResponse } = {}
): Promise<TeamDetailDto> {
  const request = teamRequest(name)
  const team = await hostPost<TeamDetailDto>(host, owner, '/api/teams', request)
  if (visibility === 'TEAM') return team
  if (!admin) throw new Error('a PUBLIC team needs a platform admin of the domain')
  return hostPut<TeamDetailDto>(host, admin, `/api/teams/${team.slug}`, {
    ...request,
    visibility,
  })
}

/**
 * The team `pin-e2e.localhost` is pinned to: a PUBLIC team of `localhost`, owned by the platform
 * admin (who is therefore its ADMIN), created on first use. Tests add content of their own to it —
 * uniquely named — and never change the team itself.
 */
export async function pinnedTeam(): Promise<TeamDetailDto> {
  const admin = await roleSession('admin')
  const request = teamRequest(PINNED_TEAM.name)
  const team = await getOrCreate(
    async () => {
      try {
        return await apiGet<TeamDetailDto>(admin, `/api/teams/${PINNED_TEAM.slug}`)
      } catch (e) {
        if (e instanceof ApiError && e.status === 404) return undefined
        throw e
      }
    },
    () => apiPost<TeamDetailDto>(admin, '/api/teams', request)
  )
  if (team.slug !== PINNED_TEAM.slug) throw new Error(`pinned team got slug ${team.slug}`)
  if (team.visibility === 'PUBLIC') return team
  return apiPut<TeamDetailDto>(admin, `/api/teams/${team.slug}`, {
    ...request,
    visibility: 'PUBLIC',
  })
}

/** The `pin-e2e.localhost` alias of `localhost`, pinned to {@link pinnedTeam}, created on first use. */
export async function pinnedAlias(): Promise<AdminDomainAliasDto> {
  const admin = await roleSession('admin')
  const team = await pinnedTeam()
  const domain = await findDomain(admin, new URL(stack.baseURL).hostname)
  if (!domain) throw new Error('the e2e stack has no localhost domain')
  const aliases = `/api/admin/domains/${domain.id}/aliases`
  const alias = await getOrCreate(
    async () =>
      (await apiGet<AdminDomainAliasDto[]>(admin, aliases)).find((a) => a.hostname === PINNED_HOST),
    () =>
      apiPost<AdminDomainAliasDto>(admin, aliases, {
        hostname: PINNED_HOST,
        teamSlug: team.slug,
        name: PINNED_NAME,
        baseUrl: originOf(PINNED_HOST),
      } satisfies CreateDomainAliasRequest)
  )
  if (alias.pinnedTeamSlug !== team.slug)
    return apiPut<AdminDomainAliasDto>(admin, `${aliases}/${alias.id}`, {
      teamSlug: team.slug,
      name: PINNED_NAME,
      baseUrl: originOf(PINNED_HOST),
    } satisfies UpdateDomainAliasRequest)
  if (!alias.active) throw new Error(`${PINNED_HOST} exists but is disabled — re-enable it`)
  return alias
}

/**
 * The server-rendered document of `path` on `host`, as ssr.ts's rawDocument reads it on
 * `localhost`: one GET, no JavaScript, redirects not followed, anonymous unless `cookie` is given.
 */
export const hostDocument = (host: string, path: string, { cookie }: { cookie?: string } = {}) =>
  onHost(host, undefined, async (api): Promise<RawDocument> => {
    const response = await api.get(path, {
      maxRedirects: 0,
      headers: {
        Accept: 'text/html',
        'Accept-Language': 'fr-FR',
        ...(cookie ? { Cookie: cookie } : {}),
      },
    })
    keepRotatedSession(cookie, response.headersArray())
    return { status: response.status(), headers: response.headers(), html: await response.text() }
  })

/**
 * The planner's site (gpx-planner.e2e.ts): `planner-e2e.localhost`, a domain of its own with the
 * GPX tools' planner open (`enableGpxPlanner` — a domain flag, which `localhost` keeps off), and
 * `planner-pin-e2e.localhost`, an alias of it pinned to a team located in Paris — so that the
 * planner opens on Paris at the team zoom (ConfigService.defaultCenter), not on all of France.
 * Like the others, created on first use and kept between runs.
 */
export const PLANNER_HOST = 'planner-e2e.localhost'
export const PLANNER_PIN_HOST = 'planner-pin-e2e.localhost'
/** The pinned team's location, [longitude, latitude]: the Hôtel de Ville, in Paris. */
export const PLANNER_CENTER: [number, number] = [2.3522, 48.8566]
const PLANNER_TEAM = { name: 'Planner E2E', slug: 'planner-e2e' }

/** The user who owns the pinned team and draws — a password account, so it never spends an OTP. */
const PLANNER_OWNER = {
  email: 'planner@e2e.test',
  displayName: 'Planner E2E',
  password: 'e2e-planner-password',
}

let plannerSession: Promise<{ owner: AuthResponse; team: TeamDetailDto }> | undefined

/** The planner's user, logged in on {@link PLANNER_HOST} — signed up there on first use. */
async function logInPlannerOwner(): Promise<AuthResponse> {
  const login = () => loginOn(PLANNER_HOST, PLANNER_OWNER.email, PLANNER_OWNER.password)
  try {
    return await login()
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 400) throw e
  }
  try {
    return await registerOn(PLANNER_HOST, PLANNER_OWNER)
  } catch (e) {
    if (!(e instanceof ApiError)) throw e
    return login()
  }
}

/**
 * The planner's site, ready (cached per worker): the domain with its planner open, its user, the
 * team located in Paris, and the alias pinned to it.
 */
export function plannerSite(): Promise<{ owner: AuthResponse; team: TeamDetailDto }> {
  plannerSession ??= (async () => {
    const admin = await roleSession('admin')
    const settings = {
      name: 'Planificateur E2E',
      baseUrl: originOf(PLANNER_HOST),
      singleTeam: false,
      enableGpxPlanner: true,
    }
    let domain = await getOrCreate(
      () => findDomain(admin, PLANNER_HOST),
      () =>
        apiPost<AdminDomainDto>(admin, '/api/admin/domains', {
          domain: PLANNER_HOST,
          ...settings,
        } satisfies CreateDomainRequest)
    )
    if (!domain.active) throw new Error(`${PLANNER_HOST} exists but is disabled — re-enable it`)
    if (!domain.enableGpxPlanner)
      domain = await apiPut<AdminDomainDto>(admin, `/api/admin/domains/${domain.id}`, settings)

    const owner = await logInPlannerOwner()
    const team = await getOrCreate(
      async () => {
        try {
          return await hostGet<TeamDetailDto>(
            PLANNER_HOST,
            owner,
            `/api/teams/${PLANNER_TEAM.slug}`
          )
        } catch (e) {
          if (e instanceof ApiError && e.status === 404) return undefined
          throw e
        }
      },
      () =>
        hostPost<TeamDetailDto>(
          PLANNER_HOST,
          owner,
          '/api/teams',
          teamRequest(PLANNER_TEAM.name, {
            geometry: { type: 'Point', coordinates: PLANNER_CENTER },
          })
        )
    )
    if (team.slug !== PLANNER_TEAM.slug) throw new Error(`planner team got slug ${team.slug}`)

    const aliases = `/api/admin/domains/${domain.id}/aliases`
    const alias = await getOrCreate(
      async () =>
        (await apiGet<AdminDomainAliasDto[]>(admin, aliases)).find(
          (a) => a.hostname === PLANNER_PIN_HOST
        ),
      () =>
        apiPost<AdminDomainAliasDto>(admin, aliases, {
          hostname: PLANNER_PIN_HOST,
          teamSlug: team.slug,
          name: 'Planificateur épinglé E2E',
          baseUrl: originOf(PLANNER_PIN_HOST),
        } satisfies CreateDomainAliasRequest)
    )
    if (!alias.active) throw new Error(`${PLANNER_PIN_HOST} exists but is disabled — re-enable it`)
    return { owner, team }
  })()
  plannerSession.catch(() => (plannerSession = undefined))
  return plannerSession
}
