import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { Box, Button, Group, Stack, Title } from '@mantine/core'
import { useDeleteRoute, useUndeleteRoute } from '@/api/endpoints/routes/routes'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { useRouteDetailData } from './routeDetailData'
import { RouteDetailView } from '../../components/route/RouteDetailView'
import { RouteUsages } from '../../components/route/RouteUsages'
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
import { useAuthStore, selectUser, selectIsPlatformAdmin } from '@/store/authStore'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { teamAccess } from '@/lib/teamAccess'

export function RouteDetailPage() {
  const { teamSlug, routeSlug } = useParams<{ teamSlug: string; routeSlug: string }>()
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const currentUserId = useAuthStore(selectUser)?.id

  const { team: teamQuery, route: routeQuery } = useRouteDetailData(teamSlug, routeSlug)
  const { data: team, isLoading: teamLoading } = teamQuery
  const { data: route, isLoading: routeLoading, error, refetch } = routeQuery
  const deleteRouteMutation = useDeleteRoute()
  const undeleteRouteMutation = useUndeleteRoute()

  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  useCanonicalPath(team && route ? paths.route(team.slug, route.slug) : undefined)

  // Editing and the comment thread (moderation) are the rights a platform admin holds in every
  // team (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const canReadComments = isMember || isPlatformAdmin

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

  if (routeLoading || teamLoading || error || !route || !team) {
    return (
      <Box maw={1280} mx="auto" px="md" py="xl">
        <QueryStateBoundary
          isLoading={routeLoading || teamLoading}
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
            {canEdit && (
              <>
                <Button
                  variant="default"
                  component="a"
                  href={paths.routeEdit(teamSlug!, routeSlug!)}
                >
                  {t('actions.edit')}
                </Button>
                {route.deleted && (
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
                {!route.deleted && (
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
              isOwn={route.createdBy.id === currentUserId}
              onReported={() => navigate(paths.routes(team.slug))}
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

      {/* Route Details */}
      <Box>
        <RouteDetailView
          route={route}
          teamSlug={teamSlug}
          fullscreenPath={paths.routeMap(team.slug, route.slug)}
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
