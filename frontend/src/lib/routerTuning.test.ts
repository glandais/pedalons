import { describe, expect, it } from 'vitest'
import { RouterProfile } from '@/api/dto'
import { sanitizeStore, sanitizeTuning, toRouterSettings } from './routerTuning'

describe('routerTuning', () => {
  it('drops a stored value equal to the profile', () => {
    expect(
      sanitizeTuning({ FASTBIKE: { useRoads: 1, useHills: 0 } }, RouterProfile.FASTBIKE)
    ).toEqual({ useHills: 0 })
    expect(sanitizeStore({ BIKE: { useHills: 0.25 } })).toEqual({})
  })

  it('reads back what was stored', () => {
    expect(sanitizeTuning({ BIKE: { useHills: 0.75 } }, RouterProfile.BIKE)).toEqual({
      useHills: 0.75,
    })
  })

  it.each([1.5, -0.1, 'x', null, NaN, Infinity, {}])('drops the stored value %s', (bad) => {
    expect(sanitizeTuning({ BIKE: { useHills: bad, useRoads: 1 } }, RouterProfile.BIKE)).toEqual({
      useRoads: 1,
    })
  })

  it.each([null, 'x', 3, [], { BIKE: 'x' }, { BIKE: null }])('survives a stored %j', (raw) => {
    expect(sanitizeTuning(raw, RouterProfile.BIKE)).toEqual({})
    expect(sanitizeStore(raw)).toEqual({})
  })

  it('ignores the knobs of a profile that takes none', () => {
    const raw = { RUN_HIKE: { useHills: 0 }, MOTORCYCLE: { useRoads: 0 } }
    expect(sanitizeTuning(raw, RouterProfile.RUN_HIKE)).toEqual({})
    expect(sanitizeStore(raw)).toEqual({})
    expect(toRouterSettings(RouterProfile.RUN_HIKE, { useHills: 0 })).toEqual({
      profile: RouterProfile.RUN_HIKE,
    })
  })

  it('sends the knobs of a bicycle profile', () => {
    expect(toRouterSettings(RouterProfile.MTB, { useHills: 0 })).toEqual({
      profile: RouterProfile.MTB,
      useHills: 0,
      useRoads: undefined,
    })
  })
})
