import { describe, it, expect } from 'vitest'
import { pointsInDistanceRange, visibleDistanceRange } from './trackDistanceRange'

// A straight eastward track along the equator, 1 km between vertices (0.01° ≈ 1.1 km — the
// distances are what the API sends, not recomputed): x = 0, 0.01, 0.02, 0.03 at 0, 1000, 2000, 3000 m.
const track = [
  [0, 0, 10, 0],
  [0.01, 0, 20, 1000],
  [0.02, 0, 30, 2000],
  [0.03, 0, 40, 3000],
]
const box = (west: number, east: number) => ({ west, east, south: -1, north: 1 })

describe('visibleDistanceRange', () => {
  it('clips the segments crossing the edges instead of stopping at the last vertex inside', () => {
    const range = visibleDistanceRange([track], box(0.005, 0.025))
    expect(range?.min).toBeCloseTo(500)
    expect(range?.max).toBeCloseTo(2500)
  })

  it('sees a segment crossing the view with no vertex inside it', () => {
    const range = visibleDistanceRange([track], box(0.012, 0.018))
    expect(range?.min).toBeCloseTo(1200)
    expect(range?.max).toBeCloseTo(1800)
  })

  it('returns null when the track is out of view', () => {
    expect(visibleDistanceRange([track], box(1, 2))).toBeNull()
  })

  it('returns the whole track when the view contains it', () => {
    expect(visibleDistanceRange([track], box(-1, 1))).toEqual({ min: 0, max: 3000 })
  })
})

describe('pointsInDistanceRange', () => {
  it('adds the points where the window starts and ends', () => {
    const points = pointsInDistanceRange([track], 500, 2500)
    expect(points.map((p) => p[3])).toEqual([500, 1000, 2000, 2500])
    expect(points[0][0]).toBeCloseTo(0.005)
    expect(points[3][0]).toBeCloseTo(0.025)
  })

  it('frames a window that falls between two vertices', () => {
    const points = pointsInDistanceRange([track], 1200, 1800)
    expect(points.map((p) => p[0])).toEqual([expect.closeTo(0.012), expect.closeTo(0.018)])
  })

  it('takes each track on its own', () => {
    const second = [
      [1, 0, 0, 0],
      [1.01, 0, 0, 1000],
    ]
    const points = pointsInDistanceRange([track, second], 200, 400)
    expect(points.map((p) => p[0])).toEqual([
      expect.closeTo(0.002),
      expect.closeTo(0.004),
      expect.closeTo(1.002),
      expect.closeTo(1.004),
    ])
  })
})
