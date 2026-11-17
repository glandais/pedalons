import type { MemberListResponse, TeamDetailDto } from '../../src/api/dto'
import { apiContext, expectOk, type AuthResponse } from './api'
import { addMember, newTeam, newUser, teamRequest } from './data'
import { unique } from './fixtures'

/**
 * A team with one account per role that matters to the member directory — none of them a platform
 * admin, whose rights short-circuit the access checker and would hide the very rules under test.
 */
export interface DirectoryTeam {
  team: TeamDetailDto
  /** Team ADMIN (the creator). */
  admin: AuthResponse
  organizer: AuthResponse
  member: AuthResponse
  /** A second plain member, the one the others look up. */
  teammate: AuthResponse
}

export async function directoryTeam(enableMemberDirectory: boolean): Promise<DirectoryTeam> {
  const [admin, organizer, member, teammate] = await Promise.all([
    newUser(unique('Dir Admin')),
    newUser(unique('Dir Orga')),
    newUser(unique('Dir Membre')),
    newUser(unique('Dir Coequipier')),
  ])
  const team = await newTeam(admin, unique('Trombi'), { enableMemberDirectory })
  if (team.enableMemberDirectory !== enableMemberDirectory)
    throw new Error(`enableMemberDirectory is not ${enableMemberDirectory} on ${team.slug}`)
  // Only the platform admin may add members to a new team (see addMember) — which does not make it
  // a member of the team.
  await addMember(team.slug, organizer, 'ORGANIZER')
  await addMember(team.slug, member, 'MEMBER')
  await addMember(team.slug, teammate, 'MEMBER')
  return { team, admin, organizer, member, teammate }
}

/** Flips the team's enableMemberDirectory setting, as its admin, through the settings endpoint. */
export async function setMemberDirectory(
  admin: AuthResponse,
  team: TeamDetailDto,
  enableMemberDirectory: boolean
) {
  const api = await apiContext(admin.accessToken)
  try {
    const updated = await expectOk<TeamDetailDto>(
      await api.put(`/api/teams/${team.slug}`, {
        data: teamRequest(team.name, { enableMemberDirectory }),
      })
    )
    if (updated.enableMemberDirectory !== enableMemberDirectory)
      throw new Error(`enableMemberDirectory did not change on ${team.slug}`)
  } finally {
    await api.dispose()
  }
}

/** GET /api/teams/{slug}/members as `who`: the status, and the body when it is a 200. */
export async function listMembers(
  who: AuthResponse,
  teamSlug: string,
  search?: string
): Promise<{ status: number; body?: MemberListResponse }> {
  const api = await apiContext(who.accessToken)
  try {
    const response = await api.get(`/api/teams/${teamSlug}/members`, {
      params: search === undefined ? { size: 100 } : { size: 100, search },
    })
    if (!response.ok()) return { status: response.status() }
    return { status: response.status(), body: (await response.json()) as MemberListResponse }
  } finally {
    await api.dispose()
  }
}
