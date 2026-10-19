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
    if (isUnit(value) && value !== PROFILE_DEFAULTS[profile]?.[key]) tuning[key] = value
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
