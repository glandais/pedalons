import { useRef, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { Box, Button, Loader, Menu } from '@mantine/core'
import { IconCopy, IconFileUpload } from '@tabler/icons-react'
import {
  useCreatePreviewFromRoute,
  useDeleteRoute,
  useDuplicateRoute,
  useUndeleteRoute,
} from '@/api/endpoints/routes/routes'
import { getListMyPreviewsQueryKey } from '@/api/endpoints/gpx-previews/gpx-previews'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { useRouteDetailData } from './routeDetailData'
import { RouteDetailView } from '../../components/route/RouteDetailView'
import { GpsMenuButton } from '@/components/route/GpsMenuButton'
import { RouteUsages } from '../../components/route/RouteUsages'
import { DuplicateRouteModal } from '../../components/route/DuplicateRouteModal'
import { RouteRetouchButton } from '../../components/routeRetouch/RouteRetouchButton'
import { RouteRetouchMenuItems } from '../../components/routeRetouch/RouteRetouchMenuItems'
import {
  RouteRetouchModal,
  type RetouchMode,
} from '../../components/routeRetouch/RouteRetouchModal'
import { useRouteRetouchOffer } from '../../components/routeRetouch/useRouteRetouchOffer'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { CommentSection } from '../../components/comment'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { DetailHeader } from '@/components/publication/DetailHeader'
import { EditMenuButton } from '@/components/publication/EditMenuButton'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { ReportTargetType } from '@/api/dto'
import { useAuthStore, selectUser } from '@/store/authStore'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuth } from '@/hooks/useAuth'

export function RouteDetailPage() {
  const { teamSlug, routeSlug } = useParams<{ teamSlug: string; routeSlug: string }>()
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const currentUserId = useAuthStore(selectUser)?.id
  const { isAuthenticated } = useAuth()

  const { route: routeQuery, team: teamQuery } = useRouteDetailData(teamSlug, routeSlug)
  const { data: route, isLoading: routeLoading, error, refetch } = routeQuery
  // The route's embedded team: the page never waits for `GET team`, which a reader of a private
  // team's public route by link does not get (docs/LEDGER_*.md WEB-166).
  const team = route?.team
  const deleteRouteMutation = useDeleteRoute()
  const undeleteRouteMutation = useUndeleteRoute()
  const duplicateRouteMutation = useDuplicateRoute()
  const createPreviewMutation = useCreatePreviewFromRoute()

  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [showDuplicate, setShowDuplicate] = useState(false)
  const [retouchMode, setRetouchMode] = useState<RetouchMode | null>(null)
  const gpxInputRef = useRef<HTMLInputElement>(null)

  // Whether the route can be retouched by this reader (ledger API-212): asked of a signed-in
  // reader on a live route, nothing is shown unless the engine can do it
  const retouchOffer = useRouteRetouchOffer(
    teamSlug,
    routeSlug,
    isAuthenticated && !!route && !route.deleted
  ).data

  useCanonicalPath(team && route ? paths.route(team.slug, route.slug) : undefined)

  // The backend's answers for this route (docs/LEDGER_*.md WEB-166, decision D7). Each gates its
  // own items: equal on a route today, nothing here relies on it.
  const canEdit = !!route?.permissions.canEdit
  const canDelete = !!route?.permissions.canDelete
  const canReadComments = !!route?.permissions.canComment

  const handleDelete = async () => {
    if (routeSlug && teamSlug) {
      await deleteRouteMutation.mutateAsync(
        { teamSlug: teamSlug, routeSlug },
        {
          onSuccess: () => {
            invalidateRouteQueries(queryClient, teamSlug, routeSlug)
            notifications.show({
              message: i18next.t('routes.notifications.deleted'),
              color: 'green',
            })
            navigate(paths.routes(teamSlug))
          },
        }
      )
    }
  }

  const handleRestore = async () => {
    if (routeSlug && teamSlug) {
      await undeleteRouteMutation.mutateAsync(
        { teamSlug: teamSlug, routeSlug },
        {
          onSuccess: () => {
            invalidateRouteQueries(queryClient, teamSlug, routeSlug)
            notifications.show({
              message: i18next.t('routes.notifications.restored'),
              color: 'green',
            })
          },
        }
      )
    }
  }

  // An organizer's copy, in the same team: only the name is sent, the API copies the rest and the
  // copy opens in its edit page (docs/LEDGER_*.md WEB-168).
  const handleDuplicate = (name: string) => {
    if (!routeSlug || !teamSlug) return
    duplicateRouteMutation.mutate(
      { teamSlug, routeSlug, data: { name } },
      {
        onSuccess: (copy) => {
          invalidateRouteQueries(queryClient, teamSlug)
          notifications.show({
            message: i18next.t('routes.notifications.duplicated'),
            color: 'green',
          })
          setShowDuplicate(false)
          navigate(paths.routeEdit(teamSlug, copy.slug))
        },
      }
    )
  }

  // A reader who may not edit the route edits a GPX preview of it instead: nothing is created in
  // the team, the preview is the caller's own (docs/LEDGER_*.md WEB-169).
  const handleEditCopy = () => {
    if (!routeSlug || !teamSlug) return
    createPreviewMutation.mutate(
      { teamSlug, routeSlug },
      {
        onSuccess: (preview) => {
          // Refresh "my files": the key prefix matches every paginated variant.
          queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
          notifications.show({
            message: i18next.t('routes.notifications.copyCreated'),
            color: 'green',
          })
          navigate(paths.gpxToolsEdit(preview.id))
        },
      }
    )
  }

  if (routeLoading || error || !route || !team) {
    return (
      <Box maw={1280} mx="auto" px="md" py="xl">
        <QueryStateBoundary
          replacesPage
          isLoading={routeLoading}
          isError={!!error}
          error={error}
          isNotFound={!route || !team}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton />}
          notFound={{
            title: t('routes.detail.notFound.title'),
            message: t('routes.detail.notFound.message'),
            backTo: paths.routes(teamSlug!),
            backLabel: t('routes.detail.notFound.backToRoutes'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Box>
    )
  }

  // The files « GPS » offers, with the services (docs/LEDGER_*.md WEB-165)
  const hasFiles = !!(route.media.assets.gpx || route.media.assets.fit)

  return (
    <Box maw={1280} mx="auto" px="md" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      <TeamContextBanner team={team} />

      {/* The one header of detail pages (docs/LEDGER_*.md WEB-206) */}
      <DetailHeader
        logo={<EntityLogo logo={route.media.assets.logo} alt={route.name} size="lg" />}
        title={route.name}
        // « GPS » first: the action every reader takes (docs/LEDGER_*.md WEB-203, WEB-165)
        gps={
          hasFiles ? (
            <GpsMenuButton
              teamSlug={team.slug}
              routeSlug={route.slug}
              route={route}
              statuses={route.gpsSyncStatuses}
              size="sm"
            />
          ) : undefined
        }
        edit={
          canEdit ? (
            <EditMenuButton to={paths.routeEdit(teamSlug!, routeSlug!)}>
              {route.deleted ? (
                // A deleted route can only be restored: deleting it again changes nothing (D11)
                canDelete && (
                  <Menu.Item
                    color="green"
                    disabled={undeleteRouteMutation.isPending}
                    leftSection={undeleteRouteMutation.isPending ? <Loader size="xs" /> : undefined}
                    onClick={handleRestore}
                  >
                    {t('actions.restore')}
                  </Menu.Item>
                )
              ) : (
                <>
                  {/* Retouch and a new file change the track too: the same menu as the app's
                      pencil (« Gérer le parcours »). */}
                  <RouteRetouchMenuItems offer={retouchOffer} onChoose={setRetouchMode} />
                  <Menu.Item
                    leftSection={<IconFileUpload size={14} />}
                    onClick={() => gpxInputRef.current?.click()}
                  >
                    {t('routes.detail.replaceGpx')}
                  </Menu.Item>
                  <Menu.Item
                    leftSection={<IconCopy size={14} />}
                    onClick={() => setShowDuplicate(true)}
                  >
                    {t('actions.duplicate')}
                  </Menu.Item>
                  {canDelete && (
                    <>
                      <Menu.Divider />
                      <Menu.Item color="danger" onClick={() => setShowDeleteConfirm(true)}>
                        {t('actions.delete')}
                      </Menu.Item>
                    </>
                  )}
                </>
              )}
            </EditMenuButton>
          ) : // A reader who cannot edit takes a copy to the GPX tools instead (ledger WEB-169)
          isAuthenticated && !route.deleted && route.media.assets.gpx ? (
            <Button
              variant="outline"
              leftSection={<IconCopy size={16} />}
              onClick={handleEditCopy}
              loading={createPreviewMutation.isPending}
            >
              {t('routes.detail.editCopy')}
            </Button>
          ) : undefined
        }
        // An editor retouches from « Modifier ▾ » (above); a reader who cannot edit gets the retouch
        // as a new route, from its own button (WEB-201)
        retouch={
          !canEdit && !route.deleted ? (
            <RouteRetouchButton offer={retouchOffer} onChoose={setRetouchMode} />
          ) : undefined
        }
        shareTitle={route.name}
        more={
          <ContentActionsMenu
            teamSlug={team.slug}
            teamName={team.name}
            targetType={ReportTargetType.ROUTE}
            targetId={route.id}
            isOwn={route.createdBy?.id === currentUserId}
            onReported={() => navigate(team.accessible ? paths.routes(team.slug) : paths.home())}
          />
        }
      >
        <MediaDisplay media={route.media} />
      </DetailHeader>

      {canEdit && (
        // « Remplacer le fichier GPX »: the file goes to the editor, which saves nothing before
        // « Enregistrer » — as the app does
        <input
          ref={gpxInputRef}
          type="file"
          accept=".gpx"
          hidden
          data-testid="route-replace-gpx-input"
          onChange={(e) => {
            const file = e.target.files?.[0]
            e.target.value = ''
            if (file) navigate(paths.routeEdit(team.slug, route.slug), { state: { gpxFile: file } })
          }}
        />
      )}

      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={handleDelete}
        title={t('routes.detail.deleteConfirm.title')}
        message={t('routes.detail.deleteConfirm.message')}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={deleteRouteMutation.isPending}
      />

      {showDuplicate && (
        <DuplicateRouteModal
          sourceName={route.name}
          loading={duplicateRouteMutation.isPending}
          onSubmit={handleDuplicate}
          onClose={() => setShowDuplicate(false)}
        />
      )}

      {retouchOffer?.available && retouchMode && (
        <RouteRetouchModal
          opened
          onClose={() => setRetouchMode(null)}
          teamSlug={team.slug}
          route={route}
          offer={retouchOffer}
          initialMode={retouchMode}
          plannerQuota={teamQuery.data?.plannerQuota}
          onOpen={(generated) => navigate(paths.routeNew(team.slug), { state: { generated } })}
          // The editor's planner only takes a single-track route (EditRoutePage)
          onEdit={
            canEdit && route.tracks.length === 1
              ? (generated) =>
                  navigate(paths.routeEdit(team.slug, route.slug), { state: { generated } })
              : undefined
          }
        />
      )}

      {/* Route Details */}
      <Box>
        <RouteDetailView
          route={route}
          fullscreenPath={(colorBy) => withMapColor(paths.routeMap(team.slug, route.slug), colorBy)}
        />
      </Box>

      {/* Comments Section - only visible to team members */}
      {canReadComments && (
        <Box mt="xl">
          <CommentSection
            teamSlug={teamSlug!}
            teamName={team.name}
            entityType="routes"
            entitySlug={routeSlug!}
            isOrganizer={!!canEdit}
          />
        </Box>
      )}

      {/* Where this route is used (rides & trips) — visible to all, results already access-filtered.
          Last on the page: it's navigation away from the route, after its own discussion. Its own
          `mt="xl"` carries the gap from whatever precedes it. */}
      <RouteUsages teamSlug={teamSlug!} routeSlug={routeSlug!} />
    </Box>
  )
}
