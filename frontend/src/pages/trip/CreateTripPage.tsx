import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Container, Stack, Title, Text } from '@mantine/core'
import { useCreateTrip } from '../../api/endpoints/trips/trips'
import { invalidateTeamPublications } from '@/lib/teamDashboardCache'
import { Status, TripRequest } from '@/api/dto'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TripEditor } from '../../components/trip/TripEditor'
import { defaultMedia } from '@/lib/apiUtils'
import { useCreateTripFormData } from './tripFormData'
import { nextWeekdayWallTime } from '@/utils/wallTime'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function CreateTripPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { team: teamQuery } = useCreateTripFormData(teamSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery

  const createMutation = useCreateTrip()

  useCanonicalPath(team ? paths.tripNew(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enableTrips || !team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canCreate = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canCreate) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  // Next Saturday at 08:00 (trips often start on weekends), a wall time of the team's zone: the SSR
  // server and the browser compute the same string (docs/LEDGER_*.md API-60).
  const tripStartDate = nextWeekdayWallTime(6, 8, team.timezone)

  // Prepare initial values for create mode
  const initialValues: TripRequest = {
    name: '',
    media: defaultMedia(),
    dateTime: tripStartDate,
    visibility: team.visibility,
    status: Status.DRAFT,
    publishAt: undefined,
    routeSlug: undefined,
    stages: [
      {
        name: t('trips.create.form.stages.defaultName', { number: 1 }),
        dateTime: tripStartDate,
        routeSlug: undefined,
        startPlaceId: undefined,
        endPlaceId: undefined,
        media: defaultMedia(),
      },
    ],
  }

  const handleSubmit = (data: TripRequest) => {
    createMutation.mutate(
      {
        teamSlug: teamSlug!,
        data,
      },
      {
        onSuccess: (trip) => {
          invalidateTeamPublications(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('trips.notifications.created'), color: 'green' })
          navigate(paths.trip(teamSlug!, trip.slug))
        },
      }
    )
  }

  return (
    <Container size="sm" py="xl">
      <Stack gap="xs">
        <Title order={1}>{t('trips.create.title')}</Title>
        <Text c="dimmed">{t('trips.create.subtitle', { teamName: team.name })}</Text>
      </Stack>

      <TripEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.team(teamSlug!))}
        isPending={createMutation.isPending}
        submitButtonText={t('trips.create.button')}
      />
    </Container>
  )
}
