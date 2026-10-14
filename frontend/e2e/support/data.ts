import { readFileSync } from 'node:fs'
import type { BrowserContext } from '@playwright/test'
import type {
  AddMemberRequest,
  AdminTeamAttributesRequest,
  AdminTeamDto,
  TeamDetailDto,
  TeamPageDto,
  TeamPageRequest,
  TeamRequest,
  TeamRole,
} from '../../src/api/dto'
import {
  apiGet,
  apiPatch,
  apiPost,
  apiPut,
  loginWithPassword,
  register,
  type AuthResponse,
} from './api'
import { seedPath, stack, type Role } from './stack'

/**
 * What most tests need before they open a page: a session for a seeded role, a fresh user, a team
 * of their own. Everything goes through the REST API, typed with the generated DTOs.
 */

/** Access tokens live 15 minutes: a cached one is replaced once it is older than this. */
export const SESSION_MAX_AGE_MS = 10 * 60_000

const sessions = new Map<Role, { auth: Promise<AuthResponse & Credentials>; at: number }>()

/** What signs a role in, as global-setup left it (seed.json). */
interface Credentials {
  password: string
}

/** A fresh session of `role`, by password: its own, shared with no other test nor context. */
export async function loginAs(role: Role): Promise<AuthResponse & Credentials> {
  const seed = JSON.parse(readFileSync(seedPath, 'utf8')) as Record<
    Role,
    { email: string; password: string }
  >
  const { email, password } = seed[role]
  return { ...(await loginWithPassword(email, password)), password }
}

/**
 * A fresh access token for a role global-setup prepared (admin, rider). Cached per worker process
 * and shared by concurrent callers, so a worker signs a role in once per 10 minutes rather than
 * once per test. Its session is the worker's: a browser signed in with it gets one of its own
 * (signIn), since the refresh token rotates (docs/LEDGER_*.md SEC-27).
 */
export function roleSession(role: Role): Promise<AuthResponse & Credentials> {
  const cached = sessions.get(role)
  if (cached && Date.now() - cached.at < SESSION_MAX_AGE_MS) return cached.auth
  const auth = loginAs(role)
  sessions.set(role, { auth, at: Date.now() })
  // A failure is not cached: the next caller tries again.
  auth.catch(() => {
    if (sessions.get(role)?.auth === auth) sessions.delete(role)
  })
  return auth
}

/**
 * Signs a browser context in as `auth`: the refresh_token cookie the backend would have set. Call it
 * before the first navigation — the SSR server and the app read it on the first request.
 *
 * The browser gets **a session of its own** whenever `auth` carries its password (newUser(),
 * roleSession()): the refresh token rotates at every refresh (docs/LEDGER_*.md SEC-27), and the
 * browser refreshes on every document — a token the test keeps using meanwhile would, once
 * presented again, take the chain over and get the browser refused (API-94). Without a password the browser takes over `auth`'s session,
 * which the test must then no longer refresh.
 */
export async function signIn(context: BrowserContext, auth: AuthResponse & Partial<Credentials>) {
  const { hostname } = new URL(stack.baseURL)
  const refreshToken = auth.password
    ? (await loginWithPassword(auth.user.email, auth.password)).refreshToken
    : auth.refreshToken
  await context.addCookies([
    {
      name: 'refresh_token',
      value: refreshToken,
      domain: hostname,
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'Lax',
    },
  ])
}

/** A per-process unique, lowercase, address-safe tag for `label`. */
let tagCounter = 0
/**
 * The local part of an address nobody else uses. The label is cut to 30 characters: an e-mail local
 * part may not exceed 64 (RFC 5321, enforced by the backend's @Email), and callers often pass a
 * `unique(...)` name, already long, whose uniqueness the suffix here makes redundant anyway.
 */
function uniqueTag(label: string): string {
  tagCounter += 1
  const slug = label
    .toLowerCase()
    .replace(/[^a-z0-9-]/g, '-')
    .slice(0, 30)
  return `${slug}-${process.pid}-${tagCounter}-${Date.now().toString(36)}`
}

/** A verified account nobody else uses, signed up through the real register + e-mail link flow. */
export async function newUser(label: string): Promise<AuthResponse & { password: string }> {
  const password = 'e2e-password'
  const auth = await register({
    email: `${uniqueTag(label)}@e2e.test`,
    displayName: label,
    password,
  })
  return { ...auth, password }
}

/** An address no account holds and no other test uses (an invitee without an account, say). */
export function freshAddress(label: string): string {
  return `${uniqueTag(label)}@e2e.test`
}

/** The `media` of a request body: `markdown`, and no picture nor attachment. */
export const markdownMedia = (markdown = ''): TeamRequest['media'] => ({
  markdown,
  assets: { images: [], attachments: [] },
})

export function teamRequest(name: string, overrides: Partial<TeamRequest> = {}): TeamRequest {
  return {
    name,
    visibility: 'TEAM',
    media: markdownMedia(),
    enableTrips: true,
    enableAds: true,
    enablePosts: true,
    enableRides: true,
    enableRoutes: true,
    enableMemberDirectory: true,
    ...overrides,
  }
}

export interface NewTeamOptions extends Partial<TeamRequest> {
  /**
   * Lets the team's own admins add members and send invitations. Born false, and an admin-only
   * attribute: the seeded platform admin sets it.
   */
  addMemberAllowed?: boolean
}

/**
 * A team owned by `owner` (its ADMIN), with the settings of `teamRequest(name, overrides)`.
 * POST /api/teams always creates a TEAM-visible team; any other visibility is applied afterwards
 * with a PUT sent as the seeded platform admin — the only one who may change a team's visibility
 * while `visibilityEditable` is off (its owner gets INVALID_VISIBILITY).
 */
export async function newTeam(
  owner: AuthResponse,
  name: string,
  { addMemberAllowed, ...overrides }: NewTeamOptions = {}
): Promise<TeamDetailDto> {
  const request = teamRequest(name, overrides)
  let team = await apiPost<TeamDetailDto>(owner, '/api/teams', { ...request, visibility: 'TEAM' })
  if (request.visibility !== 'TEAM')
    team = await apiPut<TeamDetailDto>(
      await roleSession('admin'),
      `/api/teams/${team.slug}`,
      request
    )
  if (addMemberAllowed) await setTeamAttributes(team, { addMemberAllowed })
  return team
}

/** GET /api/teams/{slug}, as `who` — its `role` is the caller's own role in the team. */
export const getTeam = (who: AuthResponse, slug: string) =>
  apiGet<TeamDetailDto>(who, `/api/teams/${slug}`)

/** Changes the admin-only attributes of a team, as the platform admin. */
export async function setTeamAttributes(
  team: TeamDetailDto,
  changes: Partial<AdminTeamAttributesRequest>
) {
  const admin = await roleSession('admin')
  const current = await apiGet<AdminTeamDto>(admin, `/api/admin/teams/${team.id}`)
  const attributes: AdminTeamAttributesRequest = {
    visibilityEditable: current.visibilityEditable,
    joinable: current.joinable,
    addMemberAllowed: current.addMemberAllowed,
    enableRoutePlanner: current.enableRoutePlanner,
    ...changes,
  }
  await apiPatch(admin, `/api/admin/teams/${team.id}/attributes`, attributes)
}

/**
 * Adds `member` to the team, as `by`.
 *
 * A team is born with addMemberAllowed=false, and then only the platform admin may add a member
 * directly — its own admins get TEAM_ADD_MEMBER_NOT_ALLOWED. So pass `roleSession('admin')` as
 * `by`, or create the team with `newTeam(…, { addMemberAllowed: true })`. The platform admin does
 * not become a member by adding one.
 */
export async function addMember(
  by: AuthResponse,
  teamSlug: string,
  member: AuthResponse,
  role: TeamRole = 'MEMBER'
) {
  const request: AddMemberRequest = { userId: member.user.id, role }
  await apiPost(by, `/api/teams/${teamSlug}/members`, request)
}

/** A custom page of the team (a tab of its own), members-only unless `overrides` say otherwise. */
export const newTeamPage = (
  by: AuthResponse,
  teamSlug: string,
  title: string,
  markdown: string,
  overrides: Partial<TeamPageRequest> = {}
) =>
  apiPost<TeamPageDto>(by, `/api/teams/${teamSlug}/pages`, {
    title,
    visibility: 'TEAM',
    media: markdownMedia(markdown),
    ...overrides,
  } satisfies TeamPageRequest)
