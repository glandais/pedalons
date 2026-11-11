import type {
  MemberListResponse,
  TeamListResponse,
  TeamPageDto,
  TeamPageSummaryDto,
  TeamWebhookDto,
} from '../../src/api/dto'
import { apiGet, withApi, type AuthResponse } from './api'
import { newTeam, setTeamAttributes } from './data'

/** The team journey's reads (flow-team.e2e.ts): what the team screens saved, through the API. */

/** The team's whole roster, as `who` (an admin of the team). */
export const rosterOf = (who: AuthResponse, slug: string) =>
  apiGet<MemberListResponse>(who, `/api/teams/${slug}/members`, { size: 100 })

/** The teams GET /api/teams lists for `who` (anonymous when undefined) under `search`. */
export const listedTeams = (who: AuthResponse | undefined, search: string) =>
  apiGet<TeamListResponse>(who, '/api/teams', { search, size: 50 })

export const pagesOf = (who: AuthResponse, slug: string) =>
  apiGet<TeamPageSummaryDto[]>(who, `/api/teams/${slug}/pages`)

export const pageOf = (who: AuthResponse, slug: string, pageSlug: string) =>
  apiGet<TeamPageDto>(who, `/api/teams/${slug}/pages/${pageSlug}`)

/**
 * A PUBLIC team owned by `owner`, open to join requests from any user of the domain or not
 * (`joinable`: an admin-only attribute, born false, which the platform admin sets).
 */
export async function publicTeam(owner: AuthResponse, name: string, joinable: boolean) {
  const team = await newTeam(owner, name, { visibility: 'PUBLIC' })
  // Born joinable since BILL-10: set either way, so `false` is a team the platform admin closed.
  if (joinable !== team.joinable) await setTeamAttributes(team, { joinable })
  return { ...team, joinable }
}

/** POST /api/teams/{slug}/members/join as `who`: the HTTP status, whatever it is. */
export const joinStatus = (who: AuthResponse, slug: string) =>
  withApi(who, async (api) => (await api.post(`/api/teams/${slug}/members/join`)).status())

/** GET /api/teams/{slug}/webhook as `who` (a team admin): the webhook, its URL masked. */
export const webhookOf = (who: AuthResponse, slug: string) =>
  apiGet<TeamWebhookDto>(who, `/api/teams/${slug}/webhook`)

/**
 * A Discord webhook URL nobody else uses — its shape only: nothing is ever posted to it (the tests
 * never publish in the team nor press « Envoyer un message de test »). `token` is the secret part,
 * the one the masked form must never reveal beyond its last four characters.
 */
export function discordWebhook() {
  const token = `e2e${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}Zq9x`
  return { url: `https://discord.com/api/webhooks/123456789012345678/${token}`, token }
}
