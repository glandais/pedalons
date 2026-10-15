import type { AnalyticsConfigDto } from './analyticsConfigDto.ts'
import type { MapCenterDto } from './mapCenterDto.ts'
import type { MapStyleDto } from './mapStyleDto.ts'
import type { MapTerrainDto } from './mapTerrainDto.ts'
import type { WebPushConfigDto } from './webPushConfigDto.ts'

/**
 * Application configuration
 */
export interface ConfigDto {
  /** WebAuthn Relying Party ID (effective host) */
  webAuthnRpId: string
  /** Application name */
  appName: string
  /** Single team mode - team creation disabled */
  singleTeam: boolean
  /** Whether the interactive planner is open in the team-independent GPX tools. When false the tools still accept a .gpx upload, only drawing from scratch is closed. Platform-admin only, per domain. */
  enableGpxPlanner: boolean
  /** Slug of the team the site is pinned to (dedicated hostname / alias). Null on a regular multi-team domain. When set, the app roots on this team. */
  pinnedTeamSlug?: string
  /** Basemaps the clients may offer, in switcher order. Served rather than compiled in, so a tile provider can change without a client release. */
  mapStyles: MapStyleDto[]
  /** Public base URL of the tile host, for a client that builds its own style, sprite or glyph URLs. */
  tileServerBaseUrl: string
  /** Where a map opens before it knows what it is showing. On a site rooted on one team this is that team's location; otherwise the deployment default. */
  defaultCenter: MapCenterDto
  /** The elevation source the clients may shade the relief with. Null when the deployment configures none — the clients then offer no relief at all rather than falling back to a provider of their own. */
  terrain?: MapTerrainDto
  /** Oldest mobile build this server still serves, as a semver string. Null when no floor is enforced; a client older than this should tell the user to update. */
  minSupportedAppVersion?: string
  /** How the site subscribes a browser to push notifications. Null when the push channel is unavailable or the deployment configures no web app — the site then offers no notification on this device. */
  webPush?: WebPushConfigDto
  /** Where the site counts its page views. Null when the deployment measures no audience — the site then sends nothing. The mobile app ignores it. */
  analytics?: AnalyticsConfigDto
}
