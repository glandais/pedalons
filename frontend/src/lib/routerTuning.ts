import { RouterProfile } from '@/api/dto'
import type { RouterSettings } from '@/lib/planner'

/** The two knobs the planner lets the user turn, for the bicycle profiles. */
export type TuningKey = 'useHills' | 'useRoads'

/** A knob setting per profile; an absent key is « the profile's value ». */
export type RouterTuning = Partial<Record<TuningKey, number>>
export type RouterTuningStore = Partial<Record<RouterProfile, RouterTuning>>

export const TUNING_KEYS: TuningKey[] = ['useHills', 'useRoads']

/**
 * What Valhalla uses when a bicycle profile does not say (0.25), and what the profile says when it
 * does (use_roads 1 for FASTBIKE). Mirrors `RouterProfile.java` in the backend: change both together.
 * Profiles absent from this table take no knob (the backend ignores them anyway).
 */
export const PROFILE_DEFAULTS: Partial<Record<RouterProfile, Record<TuningKey, number>>> = {
  [RouterProfile.BIKE]: { useHills: 0.25, useRoads: 0.25 },
  [RouterProfile.FASTBIKE]: { useHills: 0.25, useRoads: 1 },
  [RouterProfile.GRAVEL]: { useHills: 0.25, useRoads: 0.25 },
  [RouterProfile.MTB]: { useHills: 0.25, useRoads: 0.25 },
}

export function isTunable(profile: RouterProfile): boolean {
  return PROFILE_DEFAULTS[profile] !== undefined
}

/**
 * The steps the planner offers for each knob (WEB-202). Storage stays numeric, per profile: a step
 * is a named value, and a stored number is read at the nearest one.
 *
 * Circulation: « Au calme » and « Équilibré » also ask the engine to avoid main roads; « Direct »
 * does not. That is the only place avoidance is decided (the old standalone switch is gone).
 */
export type TrafficStep = 'calm' | 'balanced' | 'direct'
export const TRAFFIC_STEPS: readonly TrafficStep[] = ['calm', 'balanced', 'direct']
export const TRAFFIC_STEP_VALUES: Record<
  TrafficStep,
  { useRoads: number; avoidMainRoads: boolean }
> = {
  calm: { useRoads: 0.25, avoidMainRoads: true },
  balanced: { useRoads: 0.5, avoidMainRoads: true },
  direct: { useRoads: 1, avoidMainRoads: false },
}

/** Côtes: avoid the climbs, limit them, or do not care. */
export type HillsStep = 'avoid' | 'limit' | 'any'
export const HILLS_STEPS: readonly HillsStep[] = ['avoid', 'limit', 'any']
export const HILLS_STEP_VALUES: Record<HillsStep, number> = { avoid: 0, limit: 0.25, any: 1 }

const STEP_VALUES: Record<TuningKey, readonly number[]> = {
  useRoads: TRAFFIC_STEPS.map((step) => TRAFFIC_STEP_VALUES[step].useRoads),
  useHills: HILLS_STEPS.map((step) => HILLS_STEP_VALUES[step]),
}

/** The nearest step value of the knob; a tie goes to the higher step (0.75 gives 1). */
export function snapToStep(key: TuningKey, value: number): number {
  let best = STEP_VALUES[key][0]
  for (const candidate of STEP_VALUES[key]) {
    if (Math.abs(candidate - value) <= Math.abs(best - value)) best = candidate
  }
  return best
}

function isUnit(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1
}

/** A stored value is untrusted (stale, hand-edited): anything that is not a number in [0, 1] is dropped. */
export function sanitizeTuning(raw: unknown, profile: RouterProfile): RouterTuning {
  if (!isTunable(profile) || typeof raw !== 'object' || raw === null) return {}
  const entry = (raw as Record<string, unknown>)[profile]
  if (typeof entry !== 'object' || entry === null) return {}
  const tuning: RouterTuning = {}
  for (const key of TUNING_KEYS) {
    const value = (entry as Record<string, unknown>)[key]
    if (!isUnit(value)) continue
    // Values stored by the old five-step sliders (0, 0.25, 0.5, 0.75, 1) are read at the nearest
    // step of the new controls; nothing is written back to storage on read.
    const snapped = snapToStep(key, value)
    if (snapped !== PROFILE_DEFAULTS[profile]?.[key]) tuning[key] = snapped
  }
  return tuning
}

/** The request settings: the profile, and its knobs only when it is a bicycle one and they are set. */
export function toRouterSettings(profile: RouterProfile, tuning: RouterTuning): RouterSettings {
  if (!isTunable(profile)) return { profile }
  return { profile, useHills: tuning.useHills, useRoads: tuning.useRoads }
}

/** The knob's value for display: the user's, else the profile's. */
export function displayedValue(profile: RouterProfile, tuning: RouterTuning, key: TuningKey) {
  return tuning[key] ?? PROFILE_DEFAULTS[profile]?.[key] ?? 0.25
}

function stepOfValue<S extends string>(
  steps: readonly S[],
  values: (step: S) => number,
  value: number
): S {
  return steps.find((step) => values(step) === value) ?? steps[0]
}

/** The Circulation step shown for the profile: the user's value, else the profile's, snapped. */
export function trafficStepOf(profile: RouterProfile, tuning: RouterTuning): TrafficStep {
  const value = snapToStep('useRoads', displayedValue(profile, tuning, 'useRoads'))
  return stepOfValue(TRAFFIC_STEPS, (step) => TRAFFIC_STEP_VALUES[step].useRoads, value)
}

/** The Côtes step shown for the profile: the user's value, else the profile's, snapped. */
export function hillsStepOf(profile: RouterProfile, tuning: RouterTuning): HillsStep {
  const value = snapToStep('useHills', displayedValue(profile, tuning, 'useHills'))
  return stepOfValue(HILLS_STEPS, (step) => HILLS_STEP_VALUES[step], value)
}

export function defaultTrafficStep(profile: RouterProfile): TrafficStep {
  return trafficStepOf(profile, {})
}

export function defaultHillsStep(profile: RouterProfile): HillsStep {
  return hillsStepOf(profile, {})
}

/** Whether the engine is asked to avoid main roads: decided by the Circulation step, bicycle profiles only. */
export function avoidMainRoadsOf(profile: RouterProfile, tuning: RouterTuning): boolean {
  if (!isTunable(profile)) return false
  return TRAFFIC_STEP_VALUES[trafficStepOf(profile, tuning)].avoidMainRoads
}

/** True when a knob differs from the profile (a stored value equal to it is never kept). */
export function isCustomTuning(tuning: RouterTuning): boolean {
  return TUNING_KEYS.some((key) => tuning[key] !== undefined)
}

/** The whole stored object, cleaned profile by profile; empty entries are dropped. */
export function sanitizeStore(raw: unknown): RouterTuningStore {
  const store: RouterTuningStore = {}
  for (const profile of Object.values(RouterProfile)) {
    const tuning = sanitizeTuning(raw, profile)
    if (isCustomTuning(tuning)) store[profile] = tuning
  }
  return store
}
