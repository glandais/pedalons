import { describe, expect, it } from 'vitest'
import { RouterProfile } from '@/api/dto'
import {
  avoidMainRoadsOf,
  defaultHillsStep,
  defaultTrafficStep,
  hillsStepOf,
  sanitizeStore,
  sanitizeTuning,
  snapToStep,
  toRouterSettings,
  trafficStepOf,
} from './routerTuning'

describe('routerTuning', () => {
  it('drops a stored value equal to the profile', () => {
    expect(
      sanitizeTuning({ FASTBIKE: { useRoads: 1, useHills: 0 } }, RouterProfile.FASTBIKE)
    ).toEqual({ useHills: 0 })
    expect(sanitizeStore({ BIKE: { useHills: 0.25 } })).toEqual({})
  })

  it('reads back what was stored, at the nearest step', () => {
    expect(sanitizeTuning({ BIKE: { useHills: 0.75 } }, RouterProfile.BIKE)).toEqual({
      useHills: 1,
    })
    expect(sanitizeTuning({ BIKE: { useHills: 0 } }, RouterProfile.BIKE)).toEqual({ useHills: 0 })
    expect(sanitizeTuning({ BIKE: { useHills: 0.5 } }, RouterProfile.BIKE)).toEqual({}) // limit
  })

  it('reads a stored 0 of Circulation as calm, which is the default', () => {
    expect(sanitizeTuning({ BIKE: { useRoads: 0 } }, RouterProfile.BIKE)).toEqual({})
  })

  describe('snapToStep', () => {
    it.each([
      ['useRoads', 0.25, 0.25],
      ['useRoads', 0.5, 0.5],
      ['useRoads', 1, 1],
      ['useRoads', 0, 0.25],
      ['useRoads', 0.6, 0.5],
      ['useRoads', 0.75, 1],
      ['useHills', 0, 0],
      ['useHills', 0.25, 0.25],
      ['useHills', 1, 1],
      ['useHills', 0.5, 0.25],
      ['useHills', 0.75, 1],
    ] as const)('%s %s gives %s', (key, value, expected) => {
      expect(snapToStep(key, value)).toBe(expected)
    })
  })

  describe('steps', () => {
    it('reads the step of a stored value, else of the profile', () => {
      expect(trafficStepOf(RouterProfile.BIKE, {})).toBe('calm')
      expect(trafficStepOf(RouterProfile.BIKE, { useRoads: 0.5 })).toBe('balanced')
      expect(trafficStepOf(RouterProfile.BIKE, { useRoads: 0.75 })).toBe('direct')
      expect(hillsStepOf(RouterProfile.GRAVEL, {})).toBe('limit')
      expect(hillsStepOf(RouterProfile.GRAVEL, { useHills: 0 })).toBe('avoid')
      expect(hillsStepOf(RouterProfile.GRAVEL, { useHills: 0.75 })).toBe('any')
    })

    it('has the defaults of the backend profiles', () => {
      expect(defaultTrafficStep(RouterProfile.FASTBIKE)).toBe('direct')
      for (const p of [RouterProfile.BIKE, RouterProfile.GRAVEL, RouterProfile.MTB]) {
        expect(defaultTrafficStep(p)).toBe('calm')
      }
      for (const p of [
        RouterProfile.BIKE,
        RouterProfile.FASTBIKE,
        RouterProfile.GRAVEL,
        RouterProfile.MTB,
      ]) {
        expect(defaultHillsStep(p)).toBe('limit')
      }
    })

    it('avoids main roads from Circulation, for bicycle profiles only', () => {
      expect(avoidMainRoadsOf(RouterProfile.BIKE, {})).toBe(true)
      expect(avoidMainRoadsOf(RouterProfile.BIKE, { useRoads: 0.5 })).toBe(true)
      expect(avoidMainRoadsOf(RouterProfile.FASTBIKE, {})).toBe(false)
      expect(avoidMainRoadsOf(RouterProfile.BIKE, { useRoads: 1 })).toBe(false)
      expect(avoidMainRoadsOf(RouterProfile.RUN_HIKE, {})).toBe(false)
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
