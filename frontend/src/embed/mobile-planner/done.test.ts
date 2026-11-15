import { describe, expect, it } from 'vitest'
import type { PlannerState, WaypointRequest } from '@/api/dto'
import type { PlannerSnapshot } from '@/hooks/useRoutePlanner'
import { decode2 } from '@/lib/polyline'
import { doneMessage } from './done'

const STATE = { version: 1 } as PlannerState
const POINTS = [
  { lng: 5, lat: 45 },
  { lng: 5.1, lat: 45.2 },
]
const snapshot = (over: Partial<PlannerSnapshot>): PlannerSnapshot => ({
  dirty: true,
  plannerState: STATE,
  points: POINTS,
  ...over,
})
const done = (over: Partial<PlannerSnapshot>, create: boolean, nameSuggestion?: string) =>
  doneMessage({
    snapshot: snapshot(over),
    create,
    distance: 18_000,
    ascend: 240,
    pointCount: 2,
    dirty: over.dirty ?? true,
    nameSuggestion,
  })

describe('doneMessage', () => {
  it('creation: the planner state', () => {
    expect(done({}, true).payload).toEqual({ plannerState: STATE })
  })

  it('creation past the bounds of the state: the points, without a notice', () => {
    const message = done({ plannerState: null }, true)
    expect(message.payload).toEqual({ points: POINTS })
    expect(message.notice).toBeUndefined()
  })

  it('modification of an untouched route: an empty payload, the app sends no track', () => {
    const message = done({ dirty: false }, false)
    expect(message.payload).toEqual({})
    expect(message.dirty).toBe(false)
  })

  it('modification past the bounds: the points and the notice the app shows once saved', () => {
    const message = done({ plannerState: null }, false)
    expect(message.payload).toEqual({ points: POINTS })
    expect(message.notice).toBe('tooLarge')
  })

  it('an untouched import: a flag, the file itself stays in the app', () => {
    const file = new File(['<gpx/>'], 'tour.gpx')
    const message = done({ file }, true)
    expect(message.payload).toEqual({ file: true })
    expect(JSON.stringify(message)).not.toContain('gpx/')
  })

  it('the route points ride along only when touched', () => {
    const waypoints = [{ name: 'Col' }] as WaypointRequest[]
    expect(done({ waypoints }, true).payload).toEqual({ plannerState: STATE, waypoints })
    expect(done({ dirty: false, waypoints }, false).payload).toEqual({ waypoints })
  })

  it('carries what the preview card of the app shows', () => {
    const message = done({}, true, 'Tour du lac')
    expect(message.stats).toMatchObject({ distance: 18_000, ascend: 240, pointCount: 2 })
    expect(decode2(message.stats.line)).toEqual([
      [5, 45],
      [5.1, 45.2],
    ])
    expect(message.nameSuggestion).toBe('Tour du lac')
    expect(done({}, true).nameSuggestion).toBeUndefined()
  })

  it('crosses the bridge as JSON', () => {
    const message = done({}, true)
    expect(JSON.parse(JSON.stringify(message))).toEqual(message)
  })
})
