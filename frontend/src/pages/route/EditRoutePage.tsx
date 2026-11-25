import { useParams, useNavigate, Navigate, useLocation } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Alert, Box, Skeleton, Stack, Text, Title } from '@mantine/core'
import { useUpdateRoute, useChangeRouteSlug } from '@/api/endpoints/routes/routes'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { invalidatePlannerQuota } from '@/lib/plannerQuota'
import { SurfaceType, RouteRequest } from '@/api/dto'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { RouteEditor } from '@/components/route/RouteEditor'
import { suggestSurfaceType } from '@/lib/trackSurface'
import { useEditRouteFormData } from './routeFormData'
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'
import { useRouteUsagesRefusal } from '@/components/visibility/useVisibilityAlignment'
import { readGeneratedHandoff } from '@/lib/routeGenerator'

function readGpxFileHandoff(state: unknown): File | undefined {
  const file = (state as { gpxFile?: unknown } | null | undefined)?.gpxFile
  return typeof File !== 'undefined' && file instanceof File ? file : undefined
}

export function EditRoutePage() {
  const { teamSlug, routeSlug } = useParams<{ teamSlug: string; routeSlug: string }>()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  // A retouch chosen with « Modifier » on the route's page (ledger WEB-203): it replaces the track
  const location = useLocation()
  const generated = readGeneratedHandoff(location.state)
  // « Remplacer le fichier GPX » on the route's page: the chosen file, waiting for « Enregistrer »
  const gpxFile = readGpxFileHandoff(location.state)

  const {
    team: teamQuery,
    route: routeQuery,
    plannerState: plannerStateQuery,
  } = useEditRouteFormData(teamSlug, routeSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: route, isLoading } = routeQuery
  const updateRouteMutation = useUpdateRoute()
  const changeSlugMutation = useChangeRouteSlug()
  // A route used by a ride or a trip seen outside the team cannot go « Équipe » (decision D6).
  const usagesRefusal = useRouteUsagesRefusal(teamSlug!)

  useCanonicalPath(team && route ? paths.routeEdit(team.slug, route.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('routes.edit.title')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!team.enableRoutes) {
    return <Navigate to={paths.team(teamSlug!)} replace />
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

  // The backend's answer for this route (docs/LEDGER_*.md WEB-166, decision D7).
  const canEdit = route.permissions.canEdit

  if (!canEdit) {
    return <Navigate to={paths.routes(teamSlug!)} replace />
  }

  // Prepare initial values from fetched route data
  const initialValues = {
    name: route.name,
    media: route.media,
    surfaceType: route.surfaceType || SurfaceType.ROAD,
    visibility: route.visibility,
    tagIds: route.tags.map((tag) => tag.id),
    excludedFromGenerator: route.excludedFromGenerator ?? false,
  }

  // Check if route has a single track (required for planner mode)
  const isSingleTrack = route.tracks.length === 1
  const initialTrack = isSingleTrack ? route.tracks[0].line.coordinates : undefined

  const handleSubmit = async (data: RouteRequest, gpxFile?: File) => {
    try {
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
            // A redrawn track counted against the team's quota
            invalidatePlannerQuota(queryClient, teamSlug!)
            notifications.show({
              message: i18next.t('routes.notifications.updated'),
              color: 'green',
            })
          },
        }
      )
    } catch (error) {
      // Its dialog lists the rides and trips in the way; anything else goes on as before.
      // Not saved: RouteEditor must not report what a save would have dropped.
      if (usagesRefusal.offer(error, () => {})) return false
      throw error
    }
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
        allowedVisibilities={allowedVisibilitiesFor(team, 'route', route.permissions)}
        teamSlug={teamSlug!}
        initialValues={initialValues}
        initialTrack={initialTrack}
        initialAscend={route.elevationGain}
        initialPlannerState={plannerStateQuery.data?.state}
        initialWaypoints={route.waypoints}
        initialDistance={route.distance}
        initialGenerated={generated}
        initialGpxFile={gpxFile}
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
      {usagesRefusal.dialog}
    </Stack>
  )
}
