import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { Container, Stack, Title, Text } from '@mantine/core'
import {
  useUpdateRide,
  useChangeRideSlug,
  getGetRideQueryKey,
} from '../../api/endpoints/rides/rides'
import { useEditRideFormData, rideToRequest } from '@/pages/ride/rideFormData'
import { invalidateTeamPublications } from '@/lib/teamDashboardCache'
import { invalidateRideWeather } from '@/pages/ride/rideDetailData'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { RideEditor } from '../../components/ride/RideEditor'
import { paths } from '@/config/paths'
import { RideRequest } from '@/api/dto'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function EditRidePage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, rideSlug } = useParams<{ teamSlug: string; rideSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery, ride: rideQuery } = useEditRideFormData(teamSlug, rideSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: ride, isLoading: isLoadingRide } = rideQuery

  const updateMutation = useUpdateRide()
  const changeSlugMutation = useChangeRideSlug()

  useCanonicalPath(team && ride ? paths.rideEdit(team.slug, ride.slug) : undefined)

  if (isLoadingTeam || isLoadingRide) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team || !ride) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  if (!team.enableRides || !team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canEdit = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canEdit) {
    return <Navigate to={paths.ride(teamSlug!, rideSlug!)} replace />
  }

  const handleSubmit = (data: RideRequest) => {
    const filteredGroups = data.groups.filter((g) => g.name.trim())

    updateMutation.mutate(
      {
        teamSlug: teamSlug!,
        rideSlug: rideSlug!,
        data: {
          ...data,
          groups: filteredGroups,
        },
      },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetRideQueryKey(teamSlug!, rideSlug!) })
          invalidateTeamPublications(queryClient, teamSlug!)
          // Time, groups, speeds or route may have moved: the passages read other hours.
          void invalidateRideWeather(queryClient, teamSlug!, rideSlug!)
          notifications.show({ message: i18next.t('rides.notifications.updated'), color: 'green' })
          navigate(paths.ride(teamSlug!, rideSlug!))
        },
      }
    )
  }

  const handleSlugChange = async (newSlug: string) => {
    await changeSlugMutation.mutateAsync(
      { teamSlug: teamSlug!, rideSlug: rideSlug!, data: { slug: newSlug } },
      {
        onSuccess: (updatedRide) => {
          invalidateTeamPublications(queryClient, teamSlug!)
          queryClient.invalidateQueries({ queryKey: getGetRideQueryKey(teamSlug!, rideSlug!) })
          navigate(paths.rideEdit(teamSlug!, updatedRide.slug), { replace: true })
        },
      }
    )
  }

  const initialValues = rideToRequest(ride)

  const initialLeaders = Object.fromEntries(
    (ride.groups ?? [])
      .map((group) => group.leader)
      .filter((leader): leader is NonNullable<typeof leader> => !!leader)
      .map((leader) => [leader.id, leader])
  )

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('rides.edit.title')}</Title>
        <Text c="dimmed">{t('rides.edit.subtitle', { teamName: team.name })}</Text>
      </Stack>

      <RideEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        timezone={ride.timezone}
        initialLeaders={initialLeaders}
        participantCounts={Object.fromEntries(
          ride.groups.map((group) => [group.id, group.countParticipants])
        )}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.ride(teamSlug!, rideSlug!))}
        isPending={updateMutation.isPending}
        submitButtonText={t('actions.save')}
        currentSlug={rideSlug!}
        onSlugChange={handleSlugChange}
        canEditSlug={canEdit}
      />
    </Container>
  )
}
