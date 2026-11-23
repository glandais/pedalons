import { describe, expect, it } from 'vitest'
import { RouterEngine, RouterProfile } from '@/api/dto'
import { definedSettings } from '@/lib/planner'
import { effectiveEngine, isEngineOffered, sanitizeEngine } from './routerEngine'

const BIKES = [RouterProfile.BIKE, RouterProfile.FASTBIKE, RouterProfile.GRAVEL, RouterProfile.MTB]
const OFFERS = [
  { engine: RouterEngine.STADIA, profiles: Object.values(RouterProfile), options: [] },
  { engine: RouterEngine.PEDALONS, profiles: BIKES, options: [] },
]

describe('sanitizeEngine', () => {
  it('keeps a known engine', () => {
    expect(sanitizeEngine('PEDALONS')).toBe(RouterEngine.PEDALONS)
    expect(sanitizeEngine('STADIA')).toBe(RouterEngine.STADIA)
  })

  it.each([null, undefined, 'valhalla', 'pedalons', 3, {}, []])('falls back on %j', (raw) => {
    expect(sanitizeEngine(raw)).toBe(RouterEngine.PEDALONS)
  })
})

describe('effectiveEngine', () => {
  it.each(BIKES)('sends PEDALONS for %s when chosen and on offer', (profile) => {
    expect(effectiveEngine(RouterEngine.PEDALONS, profile, OFFERS)).toBe(RouterEngine.PEDALONS)
  })

  it.each([RouterProfile.RUN_HIKE, RouterProfile.MOTORCYCLE])(
    'sends nothing for %s, which the engine does not offer',
    (profile) => {
      expect(effectiveEngine(RouterEngine.PEDALONS, profile, OFFERS)).toBeUndefined()
    }
  )

  it('sends nothing when STADIA is chosen', () => {
    expect(effectiveEngine(RouterEngine.STADIA, RouterProfile.BIKE, OFFERS)).toBeUndefined()
  })

  it('sends nothing when the engine is off, unknown or the call failed', () => {
    expect(effectiveEngine(RouterEngine.PEDALONS, RouterProfile.BIKE, [OFFERS[0]])).toBeUndefined()
    expect(effectiveEngine(RouterEngine.PEDALONS, RouterProfile.BIKE, [])).toBeUndefined()
    expect(effectiveEngine(RouterEngine.PEDALONS, RouterProfile.BIKE, undefined)).toBeUndefined()
  })

  it('reads the profiles of the offer, not of the list', () => {
    const offers = [{ engine: RouterEngine.PEDALONS, profiles: [RouterProfile.MTB], options: [] }]
    expect(isEngineOffered(offers, RouterEngine.PEDALONS, RouterProfile.MTB)).toBe(true)
    expect(isEngineOffered(offers, RouterEngine.PEDALONS, RouterProfile.BIKE)).toBe(false)
  })
})

describe('definedSettings', () => {
  it('sends the avoidance only when true and with PEDALONS', () => {
    const profile = RouterProfile.BIKE
    expect(
      definedSettings({ profile, engine: RouterEngine.PEDALONS, avoidMainRoads: true })
    ).toEqual({ profile, engine: 'PEDALONS', avoidMainRoads: true })
    expect(
      definedSettings({ profile, engine: RouterEngine.PEDALONS, avoidMainRoads: false })
    ).toEqual({ profile, engine: 'PEDALONS' })
    expect(definedSettings({ profile, avoidMainRoads: true })).toEqual({ profile })
  })

  it('sends the engine only when it is PEDALONS', () => {
    const profile = RouterProfile.BIKE
    expect(definedSettings({ profile, engine: RouterEngine.PEDALONS })).toEqual({
      profile,
      engine: 'PEDALONS',
    })
    expect(definedSettings({ profile, engine: RouterEngine.STADIA })).toEqual({ profile })
    expect(definedSettings({ profile })).toEqual({ profile })
  })
})
