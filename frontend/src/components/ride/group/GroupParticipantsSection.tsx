import type { RideDto, RideGroupDto } from '@/api/dto'
import { ParticipantsSection } from '@/components/publication/ParticipantsSection'

/**
 * Everyone riding with the group — or, without `group`, with the whole ride (a ride page with
 * several groups): the shared `ParticipantsSection` (docs/LEDGER_*.md WEB-155) on the ride's
 * source, under the key `prefetchRideGroup` and, for a solo ride, `prefetchRideDetail` fill
 * through `groupParticipantsParams` (`participantsPageParams` for the whole ride).
 */
export function GroupParticipantsSection({
  teamSlug,
  ride,
  group,
  titleId = 'group-participants-title',
  canSeeParticipants = true,
}: {
  teamSlug: string
  ride: RideDto
  /** Absent: the whole ride's participants. */
  group?: RideGroupDto
  /** The heading's id, which names the section. */
  titleId?: string
  /** Members and platform admins only: the names are never sent to anyone else (API-144). */
  canSeeParticipants?: boolean
}) {
  return (
    <ParticipantsSection
      source={{
        kind: 'ride',
        teamSlug,
        rideSlug: ride.slug,
        groupId: group?.id,
        teamName: ride.team.name,
      }}
      count={group ? group.countParticipants : ride.participantCount}
      leaderId={group?.leader?.id}
      titleId={titleId}
      canSeeParticipants={canSeeParticipants}
    />
  )
}
