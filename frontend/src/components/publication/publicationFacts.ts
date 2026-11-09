import type { RideDto, TripDto } from '@/api/dto'

/** A value, or the span of the values of a ride's groups: equal ends print once. */
export interface FactRange {
  min: number
  max: number
}

/** What the facts line under a ride's or a trip's departure says (docs/LEDGER_*.md WEB-155). */
export interface PublicationFacts {
  /** Groups of a ride, stages of a trip. */
  childCount: number
  participantCount: number
  distance?: FactRange
  elevationGain?: FactRange
}

function rangeOf(values: (number | undefined)[]): FactRange | undefined {
  const known = values.filter((v): v is number => v !== undefined)
  if (known.length === 0) return undefined
  return { min: Math.min(...known), max: Math.max(...known) }
}

/**
 * A ride's facts: its groups ride different routes, so its distance and climb are the span over its
 * groups (« 62 à 92 km », « D+ : 700 à 1 350 m »); without a group carrying one, the ride's own.
 */
export function rideFacts(ride: RideDto): PublicationFacts {
  const groups = ride.groups ?? []
  const single = (value: number | undefined) =>
    value === undefined ? undefined : { min: value, max: value }
  return {
    childCount: groups.length,
    participantCount: ride.participantCount,
    distance: rangeOf(groups.map((g) => g.distance)) ?? single(ride.distance),
    elevationGain: rangeOf(groups.map((g) => g.elevationGain)) ?? single(ride.elevationGain),
  }
}

/** A trip's facts: its stages ride one after the other, so its totals add up. */
export function tripFacts(trip: TripDto): PublicationFacts {
  const total = (value: number | undefined) =>
    value === undefined ? undefined : { min: value, max: value }
  return {
    childCount: trip.stageCount,
    participantCount: trip.participantCount,
    distance: total(trip.totalDistance),
    elevationGain: total(trip.totalElevationGain),
  }
}
