import type { AddMemberRequest, TeamDetailDto } from '../src/api/dto'
import {
  ApiError,
  apiContext,
  expectOk,
  loginWithPassword,
  register,
  resetPassword,
  writeFileAtomic,
  type AuthResponse,
} from './support/api'
import { teamRequest } from './support/data'
import { ensureOtherAdmin } from './support/domains'
import { seedPath, stack } from './support/stack'
import type { Seed } from './support/fixtures'

/**
 * Brings the e2e stack to a known state before the suite: a password for each role, and the shared
 * data every test may rely on.
 *
 * No session is saved for the tests to share: the refresh token rotates at every refresh
 * (docs/LEDGER_*.md SEC-27), and with a token shared by several tests, the one that refreshes last
 * takes the chain over (API-94): the others are refused at their next refresh. Each browser context and each worker signs in on
 * its own instead (fixtures.ts `as`, data.ts `roleSession`), by password, which nothing rate-limits
 * but failures; hence a password for the admin too, whom the bootstrap creates without one.
 *
 * Idempotent: on a stack that already went through it, the logins succeed and nothing is redone.
 * Tests create their own data on top of this; nothing here is meant to be modified by a test.
 */

const RIDER = {
  email: 'rider@e2e.test',
  displayName: 'Rider E2E',
  password: 'e2e-rider-password',
}

const ADMIN_PASSWORD = 'e2e-admin-password'

// `slug` is what the backend derives from `name` — how an earlier, interrupted run's team is found.
const TEAM = { name: 'Peloton E2E', slug: 'peloton-e2e' }

export default async function globalSetup() {
  await assertStackUp()

  // The bootstrap admin has no password: it gets one, once per stack, through the mailed reset link.
  const admin = await passwordSession(stack.adminEmail, ADMIN_PASSWORD, () =>
    resetPassword(stack.adminEmail, ADMIN_PASSWORD)
  )
  const rider = await passwordSession(RIDER.email, RIDER.password, async () => {
    await register(RIDER)
  })

  const team = await ensureTeam(admin)
  await ensureMember(admin, rider, team.slug)

  const seed: Seed = {
    admin: {
      email: stack.adminEmail,
      displayName: admin.user.displayName,
      password: ADMIN_PASSWORD,
    },
    rider: { email: RIDER.email, displayName: RIDER.displayName, password: RIDER.password },
    team,
  }
  writeFileAtomic(seedPath, JSON.stringify(seed, null, 2))

  // After the seed: it signs the admin in (roleSession reads the seed). Before the workers: see
  // ensureOtherAdmin for why not in each of them.
  await ensureOtherAdmin()
}

async function assertStackUp() {
  try {
    const response = await fetch(`${stack.baseURL}/api/config`)
    if (response.ok) return
    throw new Error(`answered ${response.status}`)
  } catch (e) {
    throw new Error(
      `e2e stack not reachable at ${stack.baseURL} (${(e as Error).message}) — start it with ` +
        '`scripts/e2e.sh up` from the repository root',
      { cause: e }
    )
  }
}

/** A password login, once `prepare` has made it possible if it was not yet (a wrong password: 400). */
async function passwordSession(
  email: string,
  password: string,
  prepare: () => Promise<void>
): Promise<AuthResponse> {
  try {
    return await loginWithPassword(email, password)
  } catch (e) {
    if (!(e instanceof ApiError) || e.status !== 400) throw e
  }
  await prepare()
  return loginWithPassword(email, password)
}

async function ensureTeam(admin: AuthResponse): Promise<Seed['team']> {
  const api = await apiContext(admin.accessToken)
  try {
    // A team is always born TEAM-visible; only a platform admin may then open it to the public.
    // The PUT runs on every setup, so a team whose creation was interrupted is still made public.
    const request = teamRequest(TEAM.name)
    const existing = await api.get(`/api/teams/${TEAM.slug}`)
    const slug = existing.ok()
      ? TEAM.slug
      : (await expectOk<TeamDetailDto>(await api.post('/api/teams', { data: request }))).slug
    const team = await expectOk<TeamDetailDto>(
      await api.put(`/api/teams/${slug}`, { data: { ...request, visibility: 'PUBLIC' } })
    )
    return { slug: team.slug, name: team.name }
  } finally {
    await api.dispose()
  }
}

/**
 * Added by the platform admin rather than through `join`: joining needs the team to be marked
 * joinable, an admin-only setting a test would then depend on for no reason.
 */
async function ensureMember(admin: AuthResponse, member: AuthResponse, teamSlug: string) {
  const api = await apiContext(admin.accessToken)
  try {
    const request: AddMemberRequest = { userId: member.user.id, role: 'MEMBER' }
    await expectOk(await api.post(`/api/teams/${teamSlug}/members`, { data: request }))
  } catch (e) {
    if (!(e instanceof ApiError) || e.code !== 'ALREADY_REGISTERED') throw e
  } finally {
    await api.dispose()
  }
}
