/**
 * Whether a ride group leaves at another time than its ride (docs/LEDGER_*.md API-60).
 *
 * `RideGroupDto.startAt` is always set — it equals `RideDto.dateTime` for a group that leaves with
 * the ride — and `time` is deprecated, so the rule « no time of its own, nothing shown » compares
 * the two **instants**, never the strings (one instant has many spellings) nor `time` (an editor
 * may have stored the ride's own time in it). Mobile's `groupLeavesAtOwnTime` is the same rule.
 */
export function groupLeavesAtOwnTime(
  startAt: string | null | undefined,
  rideDateTime: string | null | undefined
): boolean {
  if (!startAt || !rideDateTime) return false
  const start = Date.parse(startAt)
  const ride = Date.parse(rideDateTime)
  return Number.isFinite(start) && Number.isFinite(ride) && start !== ride
}

export type GroupStartRelation = 'before' | 'with' | 'after'

/**
 * When a group leaves compared with its ride: before, with or after it — the mention next to a
 * group's departure on its page. Same comparison of instants as {@link groupLeavesAtOwnTime}; an
 * unreadable value reads as « with », which the page then words like a group without a time of
 * its own. Mobile's `groupStartRelation` is the same rule.
 */
export function groupStartRelation(
  startAt: string | null | undefined,
  rideDateTime: string | null | undefined
): GroupStartRelation {
  if (!groupLeavesAtOwnTime(startAt, rideDateTime)) return 'with'
  return Date.parse(startAt!) < Date.parse(rideDateTime!) ? 'before' : 'after'
}

interface RideStartSource {
  dateTime: string
  registeredGroup?: { startAt?: string | null } | null
  registeredGroupId?: string | null
  groups?: ReadonlyArray<{ id: string; startAt?: string | null }> | null
}

/**
 * The group the caller joined: `registeredGroup`, which list rows carry although `groups` is empty
 * there, else the matching entry of `groups`. Undefined when not registered.
 */
export function registeredGroupOf<R extends RideStartSource>(
  ride: R
): NonNullable<R['registeredGroup']> | NonNullable<R['groups']>[number] | undefined {
  if (ride.registeredGroup) return ride.registeredGroup as NonNullable<R['registeredGroup']>
  if (!ride.registeredGroupId) return undefined
  return ride.groups?.find((g) => g.id === ride.registeredGroupId)
}

/**
 * The departure that concerns the reader (docs/LEDGER_*.md WEB-135): their group's `startAt` when
 * they joined one, else the ride's `dateTime` — read in the ride's zone. `group` defaults to the
 * caller's registered group; pass `null` to ask for the ride's own departure. An unreadable
 * `startAt` falls back on the ride. Mobile's `myStartAt` (group_start.dart) is the same rule.
 */
export function startFor(
  ride: RideStartSource,
  group: { startAt?: string | null } | null | undefined = registeredGroupOf(ride)
): string {
  const startAt = group?.startAt
  return startAt && Number.isFinite(Date.parse(startAt)) ? startAt : ride.dateTime
}
