import { describe, expect, it } from 'vitest'
import { markerRole } from './plannerMarker'

describe('markerRole', () => {
  it('has only a start for a single point', () => {
    expect(markerRole(0, 1)).toBe('start')
  })
  it('has a start and an end for two points', () => {
    expect(markerRole(0, 2)).toBe('start')
    expect(markerRole(1, 2)).toBe('end')
  })
  it('has a via point between the two for three', () => {
    expect([0, 1, 2].map((i) => markerRole(i, 3))).toEqual(['start', 'via', 'end'])
  })
})
