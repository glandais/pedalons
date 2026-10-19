import { useParams, Navigate, useNavigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Stack, Text, Title } from '@mantine/core'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { RouteEditor } from '../../components/route/RouteEditor'
import { useCreateRoute } from '@/api/endpoints/routes/routes'
import { SurfaceType, RouteRequest } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { useCreateRouteFormData } from './routeFormData'

export function CreateRoutePage() {
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  const { t } = useTranslation()
  const queryClient = useQueryClient()

  const { data: team, isLoading: isLoadingTeam } = useCreateRouteFormData(teamSlug)
  const createRouteMutation = useCreateRoute()

  useCanonicalPath(team ? paths.routeNew(team.slug) : undefined)

  const handleSubmit = async (data: RouteRequest, gpxFile?: File) => {
    // Either gpxFile, planner state or points must be provided
    if (!gpxFile && !data.plannerState && (!data.points || data.points.length < 2)) return

    const route = await createRouteMutation.mutateAsync(
      {
        teamSlug: teamSlug!,
        data: {
          route: data,
          gpxFile,
        },
      },
      {
        onSuccess: () => {
          invalidateRouteQueries(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('routes.notifications.created'), color: 'green' })
        },
      }
    )

    navigate(paths.route(teamSlug!, route.slug))
  }

  const handleCancel = () => {
    navigate(paths.routes(teamSlug!))
  }

  if (isLoadingTeam) {
    return <LoadingPage message={t('routes.create.title')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canCreate = team.role === 'ADMIN' || team.role === 'ORGANIZER'

  if (!canCreate) {
    return <Navigate to={paths.routes(teamSlug!)} replace />
  }

  // Prepare initial values for create mode
  const initialValues = {
    name: '',
    media: defaultMedia(),
    surfaceType: SurfaceType.ROAD,
    visibility: team.visibility,
  }

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('routes.create.title')}</Title>
        <Text c="dimmed">{t('routes.create.subtitle')}</Text>
      </Stack>

      <RouteEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        isCreateMode={true}
        onSubmit={handleSubmit}
        onCancel={handleCancel}
        isPending={createRouteMutation.isPending}
        error={createRouteMutation.error}
        submitButtonText={t('routes.create.submit')}
      />
    </Stack>
  )
}
