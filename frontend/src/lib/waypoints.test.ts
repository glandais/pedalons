import { describe, expect, it } from 'vitest'
import type { WaypointDto } from '@/api/dto'
import {
  pointIndexAtDistance,
  sortWaypoints,
  waypointFeatures,
  waypointIconId,
  waypointLabelId,
  waypointTypeOf,
  waypointsNear,
} from './waypoints'

function wp(over: Partial<WaypointDto> & { coordinates?: number[] }): WaypointDto {
  const { coordinates = [3, 45], ...rest } = over
  return {
    name: '',
    type: 'INFO',
    origin: 'AUTHOR',
    geometry: { type: 'Point', coordinates },
    ...rest,
  } as WaypointDto
}

describe('waypointFeatures', () => {
  it('keeps a point whose longitude or latitude is exactly 0 (WEB-108)', () => {
    const features = waypointFeatures(
      [wp({ coordinates: [0, 45], name: 'Greenwich' }), wp({ coordinates: [3, 0] })],
      false
    ).features
    expect(features).toHaveLength(2)
    expect(features[0].geometry.coordinates).toEqual([0, 45])
    expect(features[1].geometry.coordinates).toEqual([3, 0])
  })

  it('numbers features by index and carries icon, label and priority', () => {
    const { features } = waypointFeatures(
      [wp({ type: 'DANGER', name: 'Gravillons', distance: 10 }), wp({ type: 'WATER' })],
      true
    )
    expect(features.map((f) => f.id)).toEqual([0, 1])
    expect(features[0].properties).toMatchObject({
      icon: 'pdl-waypoint:DANGER',
      label: 'pdl-waypoint-label:dark:Gravillons',
      onTrack: true,
    })
    expect(features[1].properties?.label).toBe('')
    expect(features[1].properties?.onTrack).toBe(false)
    expect(features[0].properties?.priority).toBeGreaterThan(features[1].properties?.priority)
  })
})

describe('waypoint types and ids', () => {
  it('reads an unknown type as an information', () => {
    expect(waypointTypeOf('FOO')).toBe('INFO')
    expect(waypointTypeOf('toString')).toBe('INFO')
    expect(waypointIconId('FOO')).toBe('pdl-waypoint:INFO')
    expect(waypointLabelId('A:b', false)).toBe('pdl-waypoint-label:light:A:b')
  })
})

describe('sortWaypoints', () => {
  it('orders along the route, off-track last, stable', () => {
    const a = wp({ name: 'a', distance: 500 })
    const b = wp({ name: 'b' })
    const c = wp({ name: 'c', distance: 100 })
    const d = wp({ name: 'd', distance: 500 })
    const e = wp({ name: 'e' })
    expect(sortWaypoints([a, b, c, d, e]).map((w) => w.name)).toEqual(['c', 'a', 'd', 'b', 'e'])
  })
})

describe('distances on the track', () => {
  const pts = [
    [0, 0, 0, 0],
    [0, 0, 0, 100],
    [0, 0, 0, 300],
    [0, 0, 0, 1000],
  ]
  it('finds the track point closest to a distance', () => {
    expect(pointIndexAtDistance(pts, -5)).toBe(0)
    expect(pointIndexAtDistance(pts, 140)).toBe(1)
    expect(pointIndexAtDistance(pts, 250)).toBe(2)
    expect(pointIndexAtDistance(pts, 5000)).toBe(3)
    expect(pointIndexAtDistance([], 1)).toBe(-1)
  })

  it('lists the waypoints near a distance', () => {
    const near = wp({ name: 'near', distance: 480 })
    const far = wp({ name: 'far', distance: 900 })
    const off = wp({ name: 'off' })
    expect(waypointsNear([near, far, off], 500, 50)).toEqual([near])
  })
})
