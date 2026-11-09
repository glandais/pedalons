import { describe, expect, it } from 'vitest'
import type { RideDto, RideGroupDto, TripDto } from '@/api/dto'
import { rideFacts, tripFacts } from './publicationFacts'

const group = (distance?: number, elevationGain?: number) =>
  ({ id: `g${distance}`, distance, elevationGain }) as RideGroupDto

const ride = (groups: RideGroupDto[], own: Partial<RideDto> = {}) =>
  ({ groups, participantCount: 34, ...own }) as RideDto

describe('rideFacts', () => {
  it('spans the distance and the climb of the groups (« 62 à 92 km »)', () => {
    const facts = rideFacts(
      ride([group(92_000, 1_350), group(78_000, 1_050), group(62_000, 700)], {
        distance: 92_000,
      })
    )
    expect(facts).toEqual({
      childCount: 3,
      participantCount: 34,
      distance: { min: 62_000, max: 92_000 },
      elevationGain: { min: 700, max: 1_350 },
    })
  })

  it('skips the groups that ride no route', () => {
    const facts = rideFacts(ride([group(80_000, 900), group(undefined, undefined)]))
    expect(facts.distance).toEqual({ min: 80_000, max: 80_000 })
    expect(facts.elevationGain).toEqual({ min: 900, max: 900 })
  })

  it("falls back on the ride's own route when no group carries one", () => {
    const facts = rideFacts(ride([], { distance: 50_000, elevationGain: 400 }))
    expect(facts.childCount).toBe(0)
    expect(facts.distance).toEqual({ min: 50_000, max: 50_000 })
    expect(facts.elevationGain).toEqual({ min: 400, max: 400 })
  })

  it('says nothing of a distance nobody knows', () => {
    const facts = rideFacts(ride([group()]))
    expect(facts.distance).toBeUndefined()
    expect(facts.elevationGain).toBeUndefined()
  })
})

describe('tripFacts', () => {
  it('gives the totals of the stages', () => {
    const facts = tripFacts({
      stageCount: 3,
      participantCount: 18,
      totalDistance: 214_000,
      totalElevationGain: 3_900,
    } as TripDto)
    expect(facts).toEqual({
      childCount: 3,
      participantCount: 18,
      distance: { min: 214_000, max: 214_000 },
      elevationGain: { min: 3_900, max: 3_900 },
    })
  })
})
