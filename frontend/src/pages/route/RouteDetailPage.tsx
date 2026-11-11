import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { Box, Button, Group, Stack, Title } from '@mantine/core'
import { IconCopy } from '@tabler/icons-react'
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
import { RouteUsages } from '../../components/route/RouteUsages'
import { DuplicateRouteModal } from '../../components/route/DuplicateRouteModal'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { CommentSection } from '../../components/comment'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { ShareButton } from '../../components/common/ShareButton'
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

  const { route: routeQuery } = useRouteDetailData(teamSlug, routeSlug)
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

  useCanonicalPath(team && route ? paths.route(team.slug, route.slug) : undefined)

  // The backend's answers for this route (docs/LEDGER_*.md WEB-166, decision D7).
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

  return (
    <Box maw={1280} mx="auto" px="md" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      <TeamContextBanner team={team} />

      {/* Header */}
      <Stack mb="lg">
        <Group justify="space-between" align="flex-start" wrap="wrap">
          <Stack gap="xs">
            <Group>
              <EntityLogo logo={route.media.assets.logo} alt={route.name} size="lg" />
              <Title order={1}>{route.name}</Title>
            </Group>
            <MediaDisplay media={route.media} />
          </Stack>
          <Group mt={{ base: 'md', sm: 0 }} gap="sm">
            {(canEdit || canDelete) && (
              <>
                {canEdit && (
                  <Button
                    variant="default"
                    component="a"
                    href={paths.routeEdit(teamSlug!, routeSlug!)}
                  >
                    {t('actions.edit')}
                  </Button>
                )}
                {canEdit && !route.deleted && (
                  <Button
                    variant="default"
                    leftSection={<IconCopy size={16} />}
                    onClick={() => setShowDuplicate(true)}
                  >
                    {t('actions.duplicate')}
                  </Button>
                )}
                {canDelete && route.deleted && (
                  <Button
                    variant="outline"
                    color="green"
                    onClick={handleRestore}
                    loading={undeleteRouteMutation.isPending}
                  >
                    {t('actions.restore')}
                  </Button>
                )}
                {/* A deleted route can only be restored */}
                {canDelete && !route.deleted && (
                  <Button
                    variant="outline"
                    color="danger"
                    onClick={() => setShowDeleteConfirm(true)}
                  >
                    {t('actions.delete')}
                  </Button>
                )}
              </>
            )}
            <ShareButton title={route.name} />
            <ContentActionsMenu
              teamSlug={team.slug}
              teamName={team.name}
              targetType={ReportTargetType.ROUTE}
              targetId={route.id}
              isOwn={route.createdBy?.id === currentUserId}
              onReported={() => navigate(team.accessible ? paths.routes(team.slug) : paths.home())}
            />
          </Group>
        </Group>
      </Stack>

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

      {/* Route Details */}
      <Box>
        <RouteDetailView
          route={route}
          teamSlug={teamSlug}
          fullscreenPath={(colorBy) => withMapColor(paths.routeMap(team.slug, route.slug), colorBy)}
          extraActions={
            isAuthenticated &&
            !canEdit &&
            !route.deleted &&
            route.media.assets.gpx && (
              <Button
                variant="default"
                size="sm"
                leftSection={<IconCopy size={16} />}
                onClick={handleEditCopy}
                loading={createPreviewMutation.isPending}
              >
                {t('routes.detail.editCopy')}
              </Button>
            )
          }
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
