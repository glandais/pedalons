import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import {
  getGetRideParticipantsQueryKey,
  getGetRideQueryKey,
  useJoinGroup,
  useLeaveGroup,
} from '@/api/endpoints/rides/rides'
import type { RideDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { invalidateRideRegistration } from '@/lib/rideRegistration'

/** Why the last join/leave on one group failed. Persists until the next attempt. */
export interface GroupMembershipError {
  groupId: string
  message: string
}

/**
 * Joining and leaving a ride's groups, for the ride page and a group's own page alike.
 *
 * The cache is flipped optimistically (`registered` on the ride and on the group, the group's
 * count with it, so a card does not show « 8/20 » next to a freshly-added avatar) and rolled back
 * on failure. The failure is kept per group rather than toasted: a toast fires far from the
 * button, then vanishes, leaving the card unchanged.
 *
 * One group per ride: the server refuses a second join (409 `ALREADY_REGISTERED`) and never moves
 * anyone from one group to another — callers offer « Rejoindre » only to a reader in no group.
 */
export function useRideGroupMembership(teamSlug: string, rideSlug: string) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const joinMutation = useJoinGroup()
  const leaveMutation = useLeaveGroup()
  const [error, setError] = useState<GroupMembershipError | null>(null)
  const rideQueryKey = getGetRideQueryKey(teamSlug, rideSlug)

  const applyOptimisticMembership = (groupId: string, joining: boolean) => {
    const previous = queryClient.getQueryData<RideDto>(rideQueryKey)
    if (!previous) return previous

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

  const mutateMembership = (groupId: string, joining: boolean) => {
    setError(null)
    const previous = applyOptimisticMembership(groupId, joining)
    const mutation = joining ? joinMutation : leaveMutation

    mutation.mutate(
      { teamSlug, rideSlug, groupId },
      {
        onSuccess: () => {
          notifications.show({
            message: t(joining ? 'rides.notifications.joined' : 'rides.notifications.left'),
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
          invalidateRideRegistration(queryClient, teamSlug)
        },
      }
    )
  }

  return {
    join: (groupId: string) => mutateMembership(groupId, true),
    leave: (groupId: string) => mutateMembership(groupId, false),
    // Every group, not only the one acted on: the optimistic update shows the other groups
    // joinable before the server has let go of the first one, and a join sent then is refused.
    isPending: joinMutation.isPending || leaveMutation.isPending,
    error,
  }
}
