import {
  RouterEngine,
  type RouterEngineOffer,
  type RouterEngineOption,
  RouterProfile,
} from '@/api/dto'

/** Where the choice is kept, per device, beside the profile and the tuning knobs. */
export const ROUTER_ENGINE_STORAGE_KEY = 'pedalons-router-engine'

/**
 * What the planner uses until the user picks the other one: the Pédalons engine, wherever it is on
 * offer for the profile (owner's decision, 2026-11-23). Where it is not, no `engine` is sent and
 * Stadia answers, as before.
 */
export const DEFAULT_ROUTER_ENGINE: RouterEngine = RouterEngine.PEDALONS

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

/** Where « avoid main roads » is kept, per device. Off until the user turns it on. */
export const ROUTER_AVOID_MAIN_ROADS_STORAGE_KEY = 'pedalons-router-avoid-main-roads'

/** True when the offers list that option for the engine: its control is drawn only then. */
export function isOptionOffered(
  offers: readonly RouterEngineOffer[] | undefined,
  engine: RouterEngine,
  option: RouterEngineOption
): boolean {
  return offers?.some((o) => o.engine === engine && (o.options ?? []).includes(option)) ?? false
}

/** What `RouterProfileSelector` needs to draw the choice; absent when it is not on offer. */
export interface EngineChoice {
  value: RouterEngine
  onChange: (engine: RouterEngine) => void
  /** The planner belongs to a team: « Routes de l'équipe » instead of « Pédalons ». */
  team: boolean
  /** « Avoid main roads », absent when the engine on offer does not accept it. */
  avoidMainRoads?: { value: boolean; onChange: (on: boolean) => void }
}
