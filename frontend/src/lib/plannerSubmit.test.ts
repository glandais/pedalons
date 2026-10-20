import { describe, expect, it } from 'vitest'
import type { PlannerState } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'
import { plannerPayload } from './plannerSubmit'

const STATE = { version: 1 } as PlannerState
const POINTS = [
  { lng: 5, lat: 45 },
  { lng: 5.1, lat: 45 },
]
const snapshot = (over: Partial<PlannerSnapshot>): PlannerSnapshot => ({
  dirty: true,
  plannerState: STATE,
  points: POINTS,
  ...over,
})

describe('plannerPayload', () => {
  it('creation: the state, the points when the state is past the bounds', () => {
    expect(plannerPayload(snapshot({ dirty: false }), true)).toEqual({ plannerState: STATE })
    expect(plannerPayload(snapshot({ plannerState: null }), true)).toEqual({
      points: POINTS,
      tooLarge: false,
    })
  })

  it('modification of an untouched route: nothing, so that the track and its state stay', () => {
    expect(plannerPayload(snapshot({ dirty: false }), false)).toEqual({})
  })

  it('modification of a route emptied below two points: nothing', () => {
    expect(plannerPayload(snapshot({ plannerState: null, points: [] }), false)).toEqual({})
    expect(plannerPayload(undefined, false)).toEqual({})
  })

  it('modification of a changed route: the state, or the points and a notice past the bounds', () => {
    expect(plannerPayload(snapshot({}), false)).toEqual({ plannerState: STATE })
    expect(plannerPayload(snapshot({ plannerState: null }), false)).toEqual({
      points: POINTS,
      tooLarge: true,
    })
  })

  it('never sends both', () => {
    for (const create of [true, false]) {
      const payload = plannerPayload(snapshot({}), create)
      expect(payload.points !== undefined && payload.plannerState !== undefined).toBe(false)
    }
  })

  it('an untouched import: the file alone, on creation and on modification', () => {
    const file = new File(['<gpx/>'], 'a.gpx')
    expect(plannerPayload(snapshot({ file }), true)).toEqual({ file })
    expect(plannerPayload(snapshot({ file }), false)).toEqual({ file })
  })
})

describe('plannerPayload and the route points (C3e)', () => {
  const LIST = [{ position: { lng: 5.05, lat: 45 }, type: 'CAFE', name: 'Café' }] as never

  it('modification, route untouched, points touched: the list alone, so that the track stays', () => {
    expect(plannerPayload(snapshot({ dirty: false, waypoints: LIST }), false)).toEqual({
      waypoints: LIST,
    })
  })

  it('rides along the state, the points past the bounds and an untouched import', () => {
    expect(plannerPayload(snapshot({ waypoints: LIST }), false)).toEqual({
      plannerState: STATE,
      waypoints: LIST,
    })
    expect(plannerPayload(snapshot({ plannerState: null, waypoints: LIST }), false)).toEqual({
      points: POINTS,
      tooLarge: true,
      waypoints: LIST,
    })
    const file = new File(['<gpx/>'], 'a.gpx')
    expect(plannerPayload(snapshot({ file, waypoints: LIST }), true)).toEqual({
      file,
      waypoints: LIST,
    })
    expect(plannerPayload(snapshot({ waypoints: LIST }), true)).toEqual({
      plannerState: STATE,
      waypoints: LIST,
    })
  })

  it('is absent when the user did not touch the list', () => {
    for (const create of [true, false]) {
      expect('waypoints' in plannerPayload(snapshot({}), create)).toBe(false)
    }
  })

  it('sends nothing at all below two points, the list included', () => {
    expect(plannerPayload(snapshot({ points: [], waypoints: LIST }), false)).toEqual({})
  })
})
