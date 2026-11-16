import type { RouteGeneratorOverlayRefreshItem } from './routeGeneratorOverlayRefreshItem.ts'

/**
 * What the pass over the teams' overlays did, or would do (dry run)
 */
export interface RouteGeneratorOverlayRefreshResponse {
  /** False when nothing started: the generator is off or unconfigured, or a pass is already running */
  started: boolean
  /** Identity of the graph the engine serves */
  graphId?: string
  /** One entry per team that is deposited, deleted, or kept (dry run only: a started pass answers 202 with no entries, it runs in the background) */
  items: RouteGeneratorOverlayRefreshItem[]
}
