/**
 * Which team overlays of the route generator to prepare now: the nightly pass, by hand. Without force, only the teams whose overlay is absent, stale, changed or about to expire.
 */
export interface RouteGeneratorOverlayRefreshRequest {
  /** Only this team (default: every team of every domain) */
  teamId?: string
  /** Deposit every team again, whatever its overlay: after a key rotation or a new graph */
  force: boolean
  /** Say what would be done, without depositing or deleting anything */
  dryRun: boolean
}
