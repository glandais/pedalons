import { useState } from 'react'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'
import { useParams, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { IconCalendar, IconPencil, IconChevronDown } from '@tabler/icons-react'
import {
  Button,
  Menu,
  Container,
  Paper,
  Group,
  Title,
  Badge,
  Stack,
  Text,
  Box,
  Loader,
} from '@mantine/core'
import {
  useUpdatePost,
  useDeletePost,
  useUndeletePost,
  getGetPostQueryKey,
} from '../../api/endpoints/posts/posts'
import { usePostDetailData } from './postDetailData'
import { postStatusRequest } from './postFormData'
import { getListPublicationsQueryKey } from '../../api/endpoints/publications/publications'
import { ReportTargetType, Status } from '../../api/dto'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { UserAvatar } from '../../components/common/UserAvatar'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { ShareButton } from '../../components/common/ShareButton'
import { CommentSection } from '../../components/comment'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { Rendezvous } from '../../components/common/Rendezvous'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { TagList } from '@/components/tag'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function PostDetailPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, postSlug } = useParams<{ teamSlug: string; postSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [showUnpublishConfirm, setShowUnpublishConfirm] = useState(false)
  const [showCancelConfirm, setShowCancelConfirm] = useState(false)
  const [showUncancelConfirm, setShowUncancelConfirm] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const { team: teamQuery, post: postQuery } = usePostDetailData(teamSlug, postSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: post, isLoading: isLoadingPost, error, refetch } = postQuery

  const updateMutation = useUpdatePost()
  const deleteMutation = useDeletePost()
  const undeleteMutation = useUndeletePost()

  useCanonicalPath(team && post ? paths.post(team.slug, post.slug) : undefined)

  if (isLoadingTeam || isLoadingPost || error || !post || !team) {
    return (
      <Container size="lg" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingTeam || isLoadingPost}
          isError={!!error}
          error={error}
          isNotFound={!post || !team}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton withMap={false} />}
          notFound={{
            title: t('posts.detail.notFound.title'),
            message: t('posts.detail.notFound.message'),
            backTo: paths.team(teamSlug!),
            backLabel: t('posts.title'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  // Registering and the join banner follow the real membership; editing and the comment thread
  // (moderation), the rights a platform admin holds in every team (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const canReadComments = isMember || isPlatformAdmin

  // A post's date is entered, a rendezvous in its (the team's) zone (docs/LEDGER_*.md API-60).
  const formattedDate = <Rendezvous date={post.dateTime} zone={post.timezone} variant="detail" />

  const invalidatePosts = () => {
    queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
    queryClient.invalidateQueries({ queryKey: getGetPostQueryKey(teamSlug!, postSlug!) })
  }

  const handlePublish = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug!, data: postStatusRequest(post, Status.PUBLISHED) },
      {
        onSuccess: () => {
          invalidatePosts()
          notifications.show({ message: i18next.t('posts.notifications.updated'), color: 'green' })
        },
      }
    )
  }

  const handleUnpublish = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug!, data: postStatusRequest(post, Status.DRAFT) },
      {
        onSuccess: () => {
          invalidatePosts()
          notifications.show({ message: i18next.t('posts.notifications.updated'), color: 'green' })
          setShowUnpublishConfirm(false)
        },
      }
    )
  }

  const handleCancel = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug!, data: postStatusRequest(post, Status.CANCELLED) },
      {
        onSuccess: () => {
          invalidatePosts()
          notifications.show({ message: i18next.t('posts.notifications.updated'), color: 'green' })
          setShowCancelConfirm(false)
        },
      }
    )
  }

  const handleUncancel = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug!, data: postStatusRequest(post, Status.PUBLISHED) },
      {
        onSuccess: () => {
          invalidatePosts()
          notifications.show({ message: i18next.t('posts.notifications.updated'), color: 'green' })
          setShowUncancelConfirm(false)
        },
      }
    )
  }

  const handleDelete = () => {
    deleteMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug!) })
          queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug!) })
          notifications.show({ message: i18next.t('posts.notifications.deleted'), color: 'green' })
          setShowDeleteConfirm(false)
          // Back to the feed, not the dashboard: the reader was managing publications.
          navigate(paths.teamPosts(teamSlug!))
        },
      }
    )
  }

  const handleRestore = () => {
    undeleteMutation.mutate(
      { teamSlug: teamSlug!, postSlug: postSlug! },
      {
        onSuccess: () => {
          invalidatePosts()
          notifications.show({ message: i18next.t('posts.notifications.restored'), color: 'green' })
        },
      }
    )
  }

  return (
    <Container size="md" py="xl">
      <Stack>
        {/* Way back to the team: this page is not mounted inside TeamLayout */}
        <TeamContextBanner team={team} mb={0} />

        {/* Header */}
        <Paper withBorder p="lg" radius="md">
          <Group justify="space-between" align="flex-start" wrap="wrap">
            <Group gap="sm" style={{ minWidth: 0 }}>
              <EntityLogo logo={post.media.assets.logo} alt={post.name} size="lg" />
              <Title order={2} lineClamp={1}>
                {post.name}
              </Title>
              <Badge color={STATUS_COLORS[post.status]}>
                {t(`status.${post.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
              </Badge>
            </Group>

            <Group gap="xs" wrap="nowrap">
              {canEdit && (
                <Button.Group>
                  <Button
                    component={PrefetchLink}
                    to={paths.postEdit(teamSlug!, postSlug!)}
                    variant="outline"
                    leftSection={<IconPencil size={16} />}
                  >
                    {t('actions.edit')}
                  </Button>
                  <Menu position="bottom-end">
                    <Menu.Target>
                      <Button variant="outline" px="xs" aria-label={t('aria.manageActions')}>
                        <IconChevronDown size={16} />
                      </Button>
                    </Menu.Target>
                    <Menu.Dropdown>
                      {post.status === Status.DRAFT && (
                        <Menu.Item
                          onClick={handlePublish}
                          disabled={updateMutation.isPending}
                          color="success"
                          leftSection={updateMutation.isPending ? <Loader size="sm" /> : undefined}
                        >
                          {t('actions.publish')}
                        </Menu.Item>
                      )}
                      {post.status === Status.PUBLISHED && (
                        <>
                          <Menu.Item onClick={() => setShowUnpublishConfirm(true)} color="warning">
                            {t('actions.unpublish')}
                          </Menu.Item>
                          <Menu.Item onClick={() => setShowCancelConfirm(true)} color="warning">
                            {t('actions.cancelAction')}
                          </Menu.Item>
                        </>
                      )}
                      {post.status === Status.CANCELLED && (
                        <Menu.Item onClick={() => setShowUncancelConfirm(true)} color="green">
                          {t('posts.detail.actions.uncancel')}
                        </Menu.Item>
                      )}
                      {post.deleted && (
                        <Menu.Item
                          onClick={handleRestore}
                          color="green"
                          disabled={undeleteMutation.isPending}
                        >
                          {t('actions.restore')}
                        </Menu.Item>
                      )}
                      <Menu.Divider />
                      <Menu.Item onClick={() => setShowDeleteConfirm(true)} color="danger">
                        {t('actions.delete')}
                      </Menu.Item>
                    </Menu.Dropdown>
                  </Menu>
                </Button.Group>
              )}
              <ShareButton title={post.name} />
              <ContentActionsMenu
                teamSlug={post.team.slug}
                teamName={post.team.name}
                targetType={ReportTargetType.POST}
                targetId={post.id}
                onReported={() => navigate(paths.team(post.team.slug))}
              />
            </Group>
          </Group>

          <Box mt="md">
            <MediaDisplay media={post.media} />
          </Box>
          {post.status === Status.DRAFT && post.publishAt && (
            <Group gap="xs" mt="sm">
              <IconCalendar size={16} color="var(--mantine-color-yellow-text)" />
              <Text size="sm" c="var(--mantine-color-yellow-text)">
                <Rendezvous
                  date={post.publishAt}
                  zone={post.timezone}
                  variant="detail"
                  template={(date) => t('posts.detail.scheduledPublish', { date })}
                />
              </Text>
            </Group>
          )}
          <Group mt="md">
            {/* The author, unless the team signs the post and the reader is not one who may know
                (docs/LEDGER_*.md API-6): then the team banner above is the signature. */}
            {post.createdBy && (
              <Group gap="xs" wrap="nowrap">
                <UserAvatar user={post.createdBy} size="xs" />
                <Text size="sm">
                  {t('posts.author.byline', { name: post.createdBy.displayName })}
                </Text>
                {post.signedAsTeam && (
                  <Text size="xs" c="dimmed">
                    {t('posts.author.onBehalfOfTeam')}
                  </Text>
                )}
              </Group>
            )}
            <Group gap="xs">
              <IconCalendar size={16} color="var(--mantine-color-dimmed)" />
              <Text size="sm" c="dimmed">
                {formattedDate}
              </Text>
            </Group>
          </Group>
          {/* The team tags, every one of them (cards show the first three). */}
          <TagList tags={post.tags} mt="md" />
        </Paper>

        {/* Comments Section - only visible to team members */}
        {canReadComments && (
          <CommentSection
            teamSlug={teamSlug!}
            teamName={team.name}
            entityType="posts"
            entitySlug={postSlug!}
            isOrganizer={canEdit}
          />
        )}

        {/* Confirmation Dialogs */}
        <ConfirmDialog
          isOpen={showUnpublishConfirm}
          onClose={() => setShowUnpublishConfirm(false)}
          onConfirm={handleUnpublish}
          title={t('actions.unpublish')}
          message={t('posts.detail.confirmations.unpublish')}
          confirmText={t('actions.unpublish')}
          variant="warning"
          isLoading={updateMutation.isPending}
        />
        <ConfirmDialog
          isOpen={showCancelConfirm}
          onClose={() => setShowCancelConfirm(false)}
          onConfirm={handleCancel}
          title={t('posts.detail.actions.cancel')}
          message={t('posts.detail.confirmations.cancel')}
          confirmText={t('posts.detail.actions.cancel')}
          variant="warning"
          isLoading={updateMutation.isPending}
        />
        <ConfirmDialog
          isOpen={showUncancelConfirm}
          onClose={() => setShowUncancelConfirm(false)}
          onConfirm={handleUncancel}
          title={t('posts.detail.actions.uncancel')}
          message={t('posts.detail.confirmations.uncancel')}
          confirmText={t('posts.detail.actions.uncancel')}
          variant="info"
          isLoading={updateMutation.isPending}
        />
        <ConfirmDialog
          isOpen={showDeleteConfirm}
          onClose={() => setShowDeleteConfirm(false)}
          onConfirm={handleDelete}
          title={t('actions.delete')}
          message={t('posts.detail.confirmations.delete')}
          confirmText={t('actions.delete')}
          variant="danger"
          isLoading={deleteMutation.isPending}
        />
      </Stack>
    </Container>
  )
}
