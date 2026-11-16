import type { RideDto, RideGroupDto } from '@/api/dto'
import { StatsCard } from '@/components/publication/StatsCard'

/**
 * Departure, pace, distance and climb of a group — each one only when the group has it: the shared
 * `StatsCard` (docs/LEDGER_*.md WEB-155). On a group's page (WEB-77) and on a solo ride's (WEB-79).
 */
export function GroupStats({
  ride,
  group,
  arrival,
  showDeparture = true,
}: {
  ride: RideDto
  group: RideGroupDto
  /** The estimated arrival of the group's leg, when the forecast gives one. */
  arrival: string | undefined
  /**
   * The « Départ » tile — off on a group's page, whose departure block above already gives it
   * (docs/BRANDING.md §7.8).
   */
  showDeparture?: boolean
}) {
  return (
    <StatsCard
      timezone={ride.timezone}
      departure={showDeparture ? group.startAt : undefined}
      averageSpeed={group.averageSpeed}
      distance={group.distance ?? ridesRoute(ride, group, ride.distance)}
      elevationGain={group.elevationGain ?? ridesRoute(ride, group, ride.elevationGain)}
      arrival={arrival}
      testId="group-stats"
    />
  )
}

/**
 * A group without a route of its own rides the ride's, which its page maps: its figures then
 * (WEB-188). Only when the ride has a route of its own — `ride.distance` otherwise falls back on
 * its first group's route, which may be another one.
 */
function ridesRoute(ride: RideDto, group: RideGroupDto, value: number | undefined) {
  return !group.routeSlug && ride.routeSlug ? value : undefined
}
