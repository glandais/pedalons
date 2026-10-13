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
