import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import {
  getGetRideParticipantsQueryKey,
  getGetRideQueryKey,
  useJoinGroup,
  useLeaveGroup,
  useSwitchGroup,
} from '@/api/endpoints/rides/rides'
import type { RideDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { invalidateRegistration } from '@/lib/registration'

/** What a call does to the reader's registration: join a group, leave it, or move to another. */
type MembershipChange = 'join' | 'leave' | 'switch'

/** Why the last join/leave/switch on one group failed. Persists until the next attempt. */
export interface GroupMembershipError {
  groupId: string
  message: string
}

/**
 * Joining, leaving and switching a ride's groups, for the ride page and a group's own page alike.
 *
 * The cache is flipped optimistically (`registered` on the ride and on the group, the group's
 * count with it, so a card does not show « 8/20 » next to a freshly-added avatar — a switch moves
 * one place from the group left to the group joined) and rolled back
 * on failure. The failure is kept per group rather than toasted: a toast fires far from the
 * button, then vanishes, leaving the card unchanged.
 *
 * One group per ride: the server refuses a second join (409 `ALREADY_REGISTERED`) — callers offer
 * « Rejoindre » only to a reader in no group, and « Changer pour {groupe} » to a reader in another:
 * one call to the `switch` endpoint (ledger API-171), which moves the registration in one
 * transaction and leaves it where it was on any refusal. None of the three is confirmed: each is
 * undone by another (KIT §9).
 */
export function useRideGroupMembership(teamSlug: string, rideSlug: string) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const joinMutation = useJoinGroup()
  const leaveMutation = useLeaveGroup()
  const switchMutation = useSwitchGroup()
  const [error, setError] = useState<GroupMembershipError | null>(null)
  const rideQueryKey = getGetRideQueryKey(teamSlug, rideSlug)

  const applyOptimisticMembership = (groupId: string, change: MembershipChange) => {
    const previous = queryClient.getQueryData<RideDto>(rideQueryKey)
    if (!previous) return previous

    const joining = change !== 'leave'
    // The group a switch leaves: the one the reader was registered in, if another.
    const leftGroupId =
      change === 'switch' && previous.registeredGroupId !== groupId
        ? previous.registeredGroupId
        : undefined
    queryClient.setQueryData<RideDto>(rideQueryKey, {
      ...previous,
      registered: joining,
      registeredGroupId: joining ? groupId : undefined,
      groups: previous.groups?.map((group) =>
        group.id === groupId
          ? {
              ...group,
              registered: joining,
              countParticipants: group.countParticipants + (joining ? 1 : -1),
            }
          : leftGroupId && group.id === leftGroupId
            ? { ...group, registered: false, countParticipants: group.countParticipants - 1 }
            : group
      ),
    })
    return previous
  }

  const describeGroupError = (cause: unknown) => {
    const code = cause instanceof ApiClientError ? cause.error.code : undefined
    // Codes are open-ended, so a generic fallback is mandatory rather than optional.
    return code
      ? t(`errors.api.${code}`, { defaultValue: t('rides.detail.groups.actionFailed') })
      : t('rides.detail.groups.actionFailed')
  }

  const mutateMembership = (groupId: string, change: MembershipChange) => {
    setError(null)
    const previous = applyOptimisticMembership(groupId, change)
    const mutation =
      change === 'join' ? joinMutation : change === 'leave' ? leaveMutation : switchMutation

    mutation.mutate(
      { teamSlug, rideSlug, groupId },
      {
        onSuccess: () => {
          notifications.show({
            message: t(
              change === 'join'
                ? 'rides.notifications.joined'
                : change === 'leave'
                  ? 'rides.notifications.left'
                  : 'rides.notifications.switched'
            ),
            color: 'green',
          })
        },
        onError: (cause) => {
          if (previous) queryClient.setQueryData(rideQueryKey, previous)
          setError({ groupId, message: describeGroupError(cause) })
        },
        onSettled: () => {
          void queryClient.invalidateQueries({ queryKey: rideQueryKey })
          // The group page lists its riders: every page and search of the ride's lists.
          void queryClient.invalidateQueries({
            queryKey: getGetRideParticipantsQueryKey(teamSlug, rideSlug),
          })
          invalidateRegistration(queryClient, teamSlug)
        },
      }
    )
  }

  return {
    join: (groupId: string) => mutateMembership(groupId, 'join'),
    leave: (groupId: string) => mutateMembership(groupId, 'leave'),
    switchTo: (groupId: string) => mutateMembership(groupId, 'switch'),
    // Every group, not only the one acted on: the optimistic update shows the other groups
    // joinable before the server has let go of the first one, and a join sent then is refused.
    isPending: joinMutation.isPending || leaveMutation.isPending || switchMutation.isPending,
    error,
  }
}
