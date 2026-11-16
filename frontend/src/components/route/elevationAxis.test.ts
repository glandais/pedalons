import { describe, expect, it } from 'vitest'
import { elevationTicks, niceStep } from './elevationAxis'

const M_TO_FT = 3.28084

describe('niceStep', () => {
  it('rounds up to 1, 2 or 5 × 10ⁿ', () => {
    expect(niceStep(0.8)).toBe(1)
    expect(niceStep(13)).toBe(20)
    expect(niceStep(31)).toBe(50)
    expect(niceStep(70)).toBe(100)
  })
})

describe('elevationTicks', () => {
  it('places round feet, in metres, strictly inside the bounds (WEB-187)', () => {
    // A 4 001 ft route rolling between 6 and 105 m: 20…330 ft
    const ticks = elevationTicks(6, 105, M_TO_FT, 5)
    const feet = ticks.map((m) => Math.round(m * M_TO_FT * 1000) / 1000)
    expect(feet).toEqual([100, 200, 300])
    ticks.forEach((m) => {
      expect(m).toBeGreaterThan(6)
      expect(m).toBeLessThan(105)
    })
  })

  it('gives nothing for a flat or inverted range', () => {
    expect(elevationTicks(50, 50, M_TO_FT, 5)).toEqual([])
    expect(elevationTicks(60, 50, M_TO_FT, 5)).toEqual([])
  })
})
