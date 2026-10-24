import { useParams, useNavigate, Navigate } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Alert, Box, Skeleton, Stack, Text, Title } from '@mantine/core'
import { useUpdateRoute, useChangeRouteSlug } from '@/api/endpoints/routes/routes'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { SurfaceType, RouteRequest } from '@/api/dto'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { RouteEditor } from '@/components/route/RouteEditor'
import { suggestSurfaceType } from '@/lib/trackSurface'
import { useEditRouteFormData } from './routeFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function EditRoutePage() {
  const { teamSlug, routeSlug } = useParams<{ teamSlug: string; routeSlug: string }>()
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const {
    team: teamQuery,
    route: routeQuery,
    plannerState: plannerStateQuery,
  } = useEditRouteFormData(teamSlug, routeSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: route, isLoading } = routeQuery
  const updateRouteMutation = useUpdateRoute()
  const changeSlugMutation = useChangeRouteSlug()

  useCanonicalPath(team && route ? paths.routeEdit(team.slug, route.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('routes.create.title')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const canEdit = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canEdit) {
    return <Navigate to={paths.routes(teamSlug!)} replace />
  }

  // The planner takes its initial state once, on mounting: the editor waits for the saved state
  if (isLoading || plannerStateQuery.isLoading) {
    return (
      <Box maw={768} mx="auto" px="md" py="xl">
        <Stack>
          <Skeleton height={32} width="25%" />
          <Skeleton height={16} width="50%" />
          <Stack>
            {[...Array(5)].map((_, i) => (
              <Stack key={i} gap="xs">
                <Skeleton height={16} width="25%" />
                <Skeleton height={40} />
              </Stack>
            ))}
          </Stack>
        </Stack>
      </Box>
    )
  }

  if (!route) {
    return <Navigate to={paths.routes(teamSlug!)} replace />
  }

  // Prepare initial values from fetched route data
  const initialValues = {
    name: route.name,
    media: route.media,
    surfaceType: route.surfaceType || SurfaceType.ROAD,
    visibility: route.visibility,
    tagIds: route.tags.map((tag) => tag.id),
  }

  // Check if route has a single track (required for planner mode)
  const isSingleTrack = route.tracks.length === 1
  const initialTrack = isSingleTrack ? route.tracks[0].line.coordinates : undefined

  const handleSubmit = async (data: RouteRequest, gpxFile?: File) => {
    await updateRouteMutation.mutateAsync(
      {
        teamSlug: teamSlug!,
        routeSlug: routeSlug!,
        data: {
          route: data,
          gpxFile,
        },
      },
      {
        onSuccess: () => {
          invalidateRouteQueries(queryClient, teamSlug!, routeSlug!)
          notifications.show({ message: i18next.t('routes.notifications.updated'), color: 'green' })
        },
      }
    )
    navigate(paths.route(teamSlug!, routeSlug!))
  }

  const handleSlugChange = async (newSlug: string) => {
    await changeSlugMutation.mutateAsync(
      { teamSlug: teamSlug!, routeSlug: routeSlug!, data: { slug: newSlug } },
      {
        onSuccess: (updatedRoute) => {
          invalidateRouteQueries(queryClient, teamSlug!, routeSlug!)
          navigate(paths.routeEdit(teamSlug!, updatedRoute.slug), { replace: true })
        },
      }
    )
  }

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('routes.edit.title')}</Title>
        <Text c="dimmed">{t('routes.edit.subtitle')}</Text>
      </Stack>

      {plannerStateQuery.isError && (
        <Alert color="yellow" variant="light">
          {t('planner.state.readFailed')}
        </Alert>
      )}

      <RouteEditor
        team={team}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        initialTrack={initialTrack}
        initialAscend={route.elevationGain}
        initialPlannerState={plannerStateQuery.data?.state}
        initialWaypoints={route.waypoints}
        initialDistance={route.distance}
        suggestedSurfaceType={suggestSurfaceType(route.tracks)}
        onSubmit={handleSubmit}
        onCancel={() => navigate(paths.route(teamSlug!, routeSlug!))}
        isPending={updateRouteMutation.isPending}
        error={updateRouteMutation.error}
        submitButtonText={t('actions.save')}
        currentSlug={routeSlug!}
        onSlugChange={handleSlugChange}
        canEditSlug={canEdit}
      />
    </Stack>
  )
}
