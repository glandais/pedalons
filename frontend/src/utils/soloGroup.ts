import type { RideDto, RideGroupDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'

/**
 * A « solo » ride has exactly one group: its page is also its group's page (ledger WEB-79) — no
 * separate group page, no group picker, no « Voir le groupe » link. A ride with several groups
 * keeps one card per group, each linking to the group's own page (WEB-77).
 *
 * The one predicate, written once for the web client: the ride page, its prefetch, the weather
 * block and the group route's redirect all read it.
 */
export function soloGroup(ride: RideDto | undefined): RideGroupDto | undefined {
  const groups = ride?.groups ?? []
  return groups.length === 1 ? groups[0] : undefined
}

/**
 * Whether a group page of this ride leaves for the ride's page: a solo ride (its page *is* the
 * group's), and a ride without groups (a group link there can only be stale — the ride itself is
 * more useful than « Ce groupe n'existe plus »). With several groups, an unknown id keeps its empty
 * state. A redirect, never permanent: a second group added later makes the group's URL a real page
 * again.
 */
export function leavesGroupPage(ride: RideDto): boolean {
  return (ride.groups?.length ?? 0) <= 1
}

/**
 * The leg of the forecast the ride's page unrolls in full (route, rain, wind, points): the single
 * leg of a ride without groups (no `groupId`, the ride's own route), or the leg of a solo ride's
 * one group (ledger WEB-79) — neither has a group page of its own to show it. With several groups,
 * none: each group's leg is on its page (WEB-77).
 */
export function ownLeg(
  ride: RideDto,
  weather: RideWeatherDto | undefined
): WeatherLegDto | undefined {
  const legs = weather?.legs ?? []
  const solo = soloGroup(ride)
  if (solo) return legs.find((leg) => leg.groupId === solo.id)
  if ((ride.groups?.length ?? 0) > 0) return undefined
  return legs.length === 1 && !legs[0].groupId ? legs[0] : undefined
}
