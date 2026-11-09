import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import type { TripDto } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { invalidateRegistration } from '@/lib/registration'
import { invalidateTripWeather } from '@/pages/trip/tripDetailData'
import {
  getGetTripParticipantsQueryKey,
  getGetTripQueryKey,
  useJoinTrip,
  useLeaveTrip,
} from '@/api/endpoints/trips/trips'

/**
 * Joining and leaving a trip — the trip counterpart of `useRideGroupMembership`, on the same
 * terms (docs/LEDGER_*.md WEB-155): the cache flips optimistically (`registered` and the count) and
 * rolls back on failure, the failure is kept for the page to show beside the button rather than
 * toasted, and everything that shows whether the reader rides is invalidated — the trip, its
 * participants, its weather, the feeds, the calendars and the dashboard.
 *
 * The server refuses a trip that is over (409 `TRIP_FINISHED`): callers offer « Rejoindre » only
 * while `trip.finished` is false.
 */
export function useTripMembership(teamSlug: string, tripSlug: string) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const joinMutation = useJoinTrip()
  const leaveMutation = useLeaveTrip()
  const [error, setError] = useState<string | null>(null)
  const tripQueryKey = getGetTripQueryKey(teamSlug, tripSlug)

  const applyOptimisticMembership = (joining: boolean) => {
    const previous = queryClient.getQueryData<TripDto>(tripQueryKey)
    if (!previous) return previous
    queryClient.setQueryData<TripDto>(tripQueryKey, {
      ...previous,
      registered: joining,
      participantCount: Math.max(0, previous.participantCount + (joining ? 1 : -1)),
    })
    return previous
  }

  const describeError = (cause: unknown) => {
    const code = cause instanceof ApiClientError ? cause.error.code : undefined
    // Codes are open-ended, so a generic fallback is mandatory rather than optional.
    return code
      ? t(`errors.api.${code}`, { defaultValue: t('trips.detail.actionFailed') })
      : t('trips.detail.actionFailed')
  }

  const mutateMembership = (joining: boolean) => {
    setError(null)
    const previous = applyOptimisticMembership(joining)
    const mutation = joining ? joinMutation : leaveMutation
    mutation.mutate(
      { teamSlug, tripSlug },
      {
        onSuccess: () => {
          notifications.show({
            message: t(joining ? 'trips.notifications.joined' : 'trips.notifications.left'),
            color: 'green',
          })
        },
        onError: (cause) => {
          if (previous) queryClient.setQueryData(tripQueryKey, previous)
          setError(describeError(cause))
        },
        onSettled: () => {
          void queryClient.invalidateQueries({ queryKey: tripQueryKey })
          void queryClient.invalidateQueries({
            queryKey: getGetTripParticipantsQueryKey(teamSlug, tripSlug),
          })
          void invalidateTripWeather(queryClient, teamSlug, tripSlug)
          invalidateRegistration(queryClient, teamSlug)
        },
      }
    )
  }

  return {
    join: () => mutateMembership(true),
    leave: () => mutateMembership(false),
    isPending: joinMutation.isPending || leaveMutation.isPending,
    error,
  }
}
