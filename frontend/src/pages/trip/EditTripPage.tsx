import { useVisibilityAlignment } from '@/components/visibility/useVisibilityAlignment'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import type { IncompatibleRouteDto } from '@/api/dto'
import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Container, Stack, Title, Text } from '@mantine/core'
import {
  useUpdateTrip,
  useChangeTripSlug,
  getGetTripQueryKey,
} from '../../api/endpoints/trips/trips'
import { invalidateTeamPublications } from '@/lib/teamDashboardCache'
import { invalidateTripWeather } from '@/pages/trip/tripDetailData'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TripEditor } from '../../components/trip/TripEditor'
import { TripRequest } from '@/api/dto'
import { useEditTripFormData, tripToRequest, tripStageTimezones } from './tripFormData'
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'

export function EditTripPage() {
  const { t } = useTranslation()
  const { teamSlug, tripSlug } = useParams<{ teamSlug: string; tripSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery, trip: tripQuery } = useEditTripFormData(teamSlug, tripSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: trip, isLoading: isLoadingTrip } = tripQuery

  const updateMutation = useUpdateTrip()
  const changeSlugMutation = useChangeTripSlug()
  const alignment = useVisibilityAlignment('trip', updateMutation.isPending)

  useCanonicalPath(team && trip ? paths.tripEdit(team.slug, trip.slug) : undefined)

  if (isLoadingTeam || isLoadingTrip) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team || !trip || !team.enableTrips || !team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  // The backend's answer for this trip (docs/LEDGER_*.md WEB-166, decision D7).
  const canEdit = trip.permissions.canEdit

  if (!canEdit) {
    return <Navigate to={paths.trip(teamSlug!, tripSlug!)} replace />
  }

  const save = (data: TripRequest, aligned?: IncompatibleRouteDto[]) => {
    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        tripSlug: tripSlug!,
        data: { ...data, alignVisibility: aligned ? true : undefined },
      },
      {
        // A trip opened outside the team on « Équipe » routes: confirm, then raise them (D5).
        onError: (error) => alignment.offer(error, (routes) => save(data, routes)),
        onSuccess: () => {
          aligned?.forEach((route) => invalidateRouteQueries(queryClient, teamSlug!, route.slug))
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          invalidateTeamPublications(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('trips.notifications.updated'), color: 'green' })
          navigate(paths.trip(teamSlug!, tripSlug!))
        },
      }
    )
  }

  const handleSubmit = (data: TripRequest) => save(data)

  const handleSlugChange = async (newSlug: string) => {
    await changeSlugMutation.mutateAsync(
      { teamSlug: teamSlug!, tripSlug: tripSlug!, data: { slug: newSlug } },
      {
        onSuccess: (updatedTrip) => {
          invalidateTeamPublications(queryClient, teamSlug!)
          queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug!, tripSlug!) })
          void invalidateTripWeather(queryClient, teamSlug!, tripSlug!)
          navigate(paths.tripEdit(teamSlug!, updatedTrip.slug), { replace: true })
        },
      }
    )
  }

  const initialValues = tripToRequest(trip)

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('trips.edit.title')}</Title>
        <Text c="dimmed">{t('trips.edit.subtitle', { teamName: team.name })}</Text>
      </Stack>

      <TripEditor
        team={team}
        allowedVisibilities={allowedVisibilitiesFor(team, 'trip', trip.permissions)}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        timezone={trip.timezone}
        stageTimezones={tripStageTimezones(trip)}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.trip(teamSlug!, tripSlug!))}
        isPending={updateMutation.isPending}
        submitButtonText={t('actions.save')}
        currentSlug={tripSlug!}
        onSlugChange={handleSlugChange}
        canEditSlug={canEdit}
      />
      {alignment.dialog}
    </Container>
  )
}
