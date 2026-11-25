import { useParams, Navigate, useNavigate, useLocation } from 'react-router-dom'
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
import { invalidatePlannerQuota } from '@/lib/plannerQuota'
import { useCreateRouteFormData } from './routeFormData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'
import { readGeneratedHandoff } from '@/lib/routeGenerator'
import { readDrawHandoff, readGpxFileHandoff } from '@/lib/routeHandoff'
import { useRef } from 'react'
import { useLeaveGuard } from '@/hooks/useLeaveGuard'

export function CreateRoutePage() {
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const navigate = useNavigate()
  // A route proposed by the generator page (ledger WEB-179); ignored when malformed
  const location = useLocation()
  const generated = readGeneratedHandoff(location.state)
  // « Importer des GPX » with one file, « Tracer sur la carte »: the menus' entries (useGpxUpload,
  // useRouteCreateActions)
  const gpxFile = readGpxFileHandoff(location.state)
  const draw = readDrawHandoff(location.state)
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const queryClient = useQueryClient()

  const { data: team, isLoading: isLoadingTeam } = useCreateRouteFormData(teamSlug)
  const createRouteMutation = useCreateRoute()

  useCanonicalPath(team ? paths.routeNew(team.slug) : undefined)

  // A drawing, a file or a proposal is not dropped without asking (docs/LEDGER_*.md WEB-213)
  const dirtyRef = useRef<(() => boolean) | null>(null)
  const leaveGuard = useLeaveGuard(() => dirtyRef.current?.() ?? false)

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
          // A drawn track counted against the team's quota: the editor's option reads it
          invalidatePlannerQuota(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('routes.notifications.created'), color: 'green' })
        },
      }
    )

    leaveGuard.release()
    navigate(paths.route(teamSlug!, route.slug))
  }

  // Back where the form was opened from (the generator and its settings, the dashboard, the home
  // page); the team's routes when it was opened by a link (docs/LEDGER_*.md WEB-213).
  const handleCancel = () => {
    if (location.key !== 'default') navigate(-1)
    else navigate(paths.routes(teamSlug!))
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

  const canCreate = teamAccess(team, isPlatformAdmin).isOrganizer

  if (!canCreate) {
    return <Navigate to={paths.routes(teamSlug!)} replace />
  }

  // Prepare initial values for create mode
  const initialValues = {
    name: '',
    media: defaultMedia(),
    // The generator's type is one of ROAD, GRAVEL, MTB: all SurfaceType values
    surfaceType: generated ? SurfaceType[generated.type] : SurfaceType.ROAD,
    visibility: team.defaultContentVisibility,
    excludedFromGenerator: false,
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
        initialGenerated={generated}
        initialGpxFile={gpxFile}
        initialDraw={draw}
        onSubmit={handleSubmit}
        onCancel={handleCancel}
        isPending={createRouteMutation.isPending}
        error={createRouteMutation.error}
        submitButtonText={t('routes.create.submit')}
        dirtyRef={dirtyRef}
      />
      {leaveGuard.dialog}
    </Stack>
  )
}
