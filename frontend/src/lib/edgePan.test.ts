import { describe, expect, it } from 'vitest'
import { EDGE_PAN_MAX_SPEED_PX_S as MAX, edgePanVelocity } from './edgePan'

const SIZE = { width: 800, height: 600 }

describe('edgePanVelocity', () => {
  it('is zero from 40 px of the edge inwards', () => {
    expect(edgePanVelocity({ x: 40, y: 300 }, SIZE)).toEqual({ vx: 0, vy: 0 })
    expect(edgePanVelocity({ x: 400, y: 300 }, SIZE)).toEqual({ vx: 0, vy: 0 })
    expect(edgePanVelocity({ x: 760, y: 300 }, SIZE)).toEqual({ vx: 0, vy: 0 })
  })

  it('is maximal on the edge and beyond', () => {
    expect(edgePanVelocity({ x: 0, y: 300 }, SIZE).vx).toBe(-MAX)
    expect(edgePanVelocity({ x: -25, y: 300 }, SIZE).vx).toBe(-MAX)
    expect(edgePanVelocity({ x: 825, y: 300 }, SIZE).vx).toBe(MAX)
  })

  it('is half the maximum at 20 px', () => {
    expect(edgePanVelocity({ x: 20, y: 300 }, SIZE).vx).toBeCloseTo(-MAX / 2)
  })

  it('points the right way at the four edges', () => {
    expect(edgePanVelocity({ x: 790, y: 300 }, SIZE).vx).toBeGreaterThan(0)
    expect(edgePanVelocity({ x: 10, y: 300 }, SIZE).vx).toBeLessThan(0)
    expect(edgePanVelocity({ x: 400, y: 10 }, SIZE).vy).toBeLessThan(0)
    expect(edgePanVelocity({ x: 400, y: 590 }, SIZE).vy).toBeGreaterThan(0)
  })

  it('scrolls on both axes in a corner', () => {
    const v = edgePanVelocity({ x: 5, y: 595 }, SIZE)
    expect(v.vx).toBeLessThan(0)
    expect(v.vy).toBeGreaterThan(0)
  })

  it('shrinks the zone to a quarter of a small map', () => {
    const small = { width: 120, height: 600 }
    // zone = 30: the centre and 30 px in are free
    expect(edgePanVelocity({ x: 60, y: 300 }, small).vx).toBe(0)
    expect(edgePanVelocity({ x: 30, y: 300 }, small).vx).toBe(0)
    expect(edgePanVelocity({ x: 15, y: 300 }, small).vx).toBeCloseTo(-MAX / 2)
  })
})
