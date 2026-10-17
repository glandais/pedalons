import { describe, expect, it } from 'vitest'
import { trackSilhouette } from './trackSilhouette'

describe('trackSilhouette', () => {
  it('is null for fewer than two vertices and for a single repeated point', () => {
    expect(trackSilhouette([])).toBeNull()
    expect(trackSilhouette([[2, 45]])).toBeNull()
    expect(
      trackSilhouette([
        [2, 45],
        [2, 45],
      ])
    ).toBeNull()
  })

  it('keeps north up and fits the longest side of the box', () => {
    const s = trackSilhouette([
      [0, 0],
      [0, 1],
    ])!
    const [first, last] = s.points.split(' ').map((p) => p.split(',').map(Number))
    // Going north is going up: y decreases.
    expect(last[1]).toBeLessThan(first[1])
    expect(s.height).toBeCloseTo(100)
    expect(s.width).toBeCloseTo(12)
  })

  it('caps the number of vertices and keeps the last one', () => {
    const coords = Array.from({ length: 5000 }, (_, i) => [i / 1000, Math.sin(i / 100)])
    const s = trackSilhouette(coords)!
    expect(s.points.split(' ').length).toBeLessThanOrEqual(251)
  })
})
