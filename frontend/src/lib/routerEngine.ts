import { RouterEngine, type RouterEngineOffer, RouterProfile } from '@/api/dto'

/** Where the choice is kept, per device, beside the profile and the tuning knobs. */
export const ROUTER_ENGINE_STORAGE_KEY = 'pedalons-router-engine'

/** What the planner uses until the user picks the other one. */
export const DEFAULT_ROUTER_ENGINE: RouterEngine = RouterEngine.STADIA

/** A stored value is untrusted (stale, hand-edited): anything but a known engine is the default. */
export function sanitizeEngine(raw: unknown): RouterEngine {
  return Object.values(RouterEngine).includes(raw as RouterEngine)
    ? (raw as RouterEngine)
    : DEFAULT_ROUTER_ENGINE
}

/** True when the offers list the engine for that profile. */
export function isEngineOffered(
  offers: readonly RouterEngineOffer[] | undefined,
  engine: RouterEngine,
  profile: RouterProfile
): boolean {
  return offers?.some((o) => o.engine === engine && o.profiles.includes(profile)) ?? false
}

/**
 * The engine a leg is asked of: PEDALONS only when it is the user's choice AND it is on offer for
 * the current profile; otherwise undefined, and the request carries no `engine` (the server's
 * default, Stadia).
 */
export function effectiveEngine(
  choice: RouterEngine,
  profile: RouterProfile,
  offers: readonly RouterEngineOffer[] | undefined
): RouterEngine | undefined {
  return choice === RouterEngine.PEDALONS && isEngineOffered(offers, RouterEngine.PEDALONS, profile)
    ? RouterEngine.PEDALONS
    : undefined
}

/** What `RouterProfileSelector` needs to draw the choice; absent when it is not on offer. */
export interface EngineChoice {
  value: RouterEngine
  onChange: (engine: RouterEngine) => void
  /** The planner belongs to a team: « Routes de l'équipe » instead of « Pédalons ». */
  team: boolean
}
