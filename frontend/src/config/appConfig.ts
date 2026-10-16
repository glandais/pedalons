import { ConfigDto } from '@/api/dto'
import { getSSRConfig } from '@/lib/ssrContext'

let cachedConfig: ConfigDto | null = null
let configPromise: Promise<ConfigDto> | null = null

export async function fetchAppConfig(): Promise<ConfigDto> {
  if (cachedConfig) {
    return cachedConfig
  }

  if (configPromise) {
    return configPromise
  }

  configPromise = (async () => {
    const response = await fetch('/api/config')
    if (!response.ok) {
      throw new Error(`Failed to fetch app config: ${response.status}`)
    }
    cachedConfig = await response.json()
    return cachedConfig!
  })()

  return configPromise
}

/**
 * Synchronous config reader. During SSR the per-request config (from ssrContext) wins, so
 * concurrent requests on different domains never share state. Off-server it falls back to the
 * module cache populated by fetchAppConfig()/seedAppConfig().
 */
export function getAppConfig(): ConfigDto | null {
  return getSSRConfig() ?? cachedConfig
}

/**
 * Seed the module cache from dehydrated state (used by entry-client to avoid an extra /api/config
 * fetch on hydration). No-op protection is unnecessary — the latest config always wins.
 */
export function seedAppConfig(config: ConfigDto): void {
  cachedConfig = config
}

/**
 * When the site is served on a dedicated hostname (domain alias) pinned to a single team, returns
 * that team's slug. The app then roots on this team instead of showing the multi-team landing.
 * Returns null on a regular multi-team domain.
 */
export function getPinnedTeamSlug(): string | null {
  return getAppConfig()?.pinnedTeamSlug ?? null
}

/**
 * True when the site hosts a single team: either the domain is flagged single-team, or the request
 * came in on a hostname pinned to one team. Team browsing and team creation are then irrelevant.
 */
export function isSingleTeam(): boolean {
  return getAppConfig()?.singleTeam ?? false
}

/**
 * True when the domain opens the interactive planner in the team-independent GPX tools. Off by
 * default and platform-admin controlled; uploading a .gpx to the tools stays available either way,
 * so this only governs drawing from scratch. The team-scoped equivalent is
 * `TeamDetailDto.enableRoutePlanner`.
 */
export function isGpxPlannerEnabled(): boolean {
  return getAppConfig()?.enableGpxPlanner ?? false
}

/**
 * True when the deployment sends the routes of a member's rides to their GPS services on its own
 * (docs/LEDGER_*.md API-120). Off, the profile offers no switch: it would promise a sending that
 * never happens.
 */
export function isGpsAutoSyncEnabled(): boolean {
  return getAppConfig()?.gpsAutoSyncEnabled ?? false
}
