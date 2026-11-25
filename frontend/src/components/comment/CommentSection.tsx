import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Paper, Title, Stack, Center, Loader } from '@mantine/core'
import { IconMessageCircle } from '@tabler/icons-react'
import { EmptyState } from '../common/EmptyState'
import {
  useComments,
  useCreateComment,
  useDeleteComment,
  COMMENT_LIST_OPTIONS,
  type EntityType,
} from '../../hooks/useComments'
import { CommentItem } from './CommentItem'
import { CommentForm } from './CommentForm'
import type { CommentDto } from '../../api/dto'
import { useAuth } from '../../hooks/useAuth'

interface CommentSectionProps {
  teamSlug: string
  /** Named in the report dialog: its organizers receive the reports. */
  teamName: string
  entityType: EntityType
  entitySlug: string
  isOrganizer: boolean
}

export function CommentSection({
  teamSlug,
  teamName,
  entityType,
  entitySlug,
  isOrganizer,
}: CommentSectionProps) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const [replyingTo, setReplyingTo] = useState<string | null>(null)

  const { data, isLoading, fetchNextPage, hasNextPage, isFetchingNextPage } = useComments(
    teamSlug,
    entityType,
    entitySlug,
    COMMENT_LIST_OPTIONS
  )

  // `total` counts replies too — that is the number the heading has always shown.
  const total = data?.pages[0]?.total ?? 0
  const comments = data?.pages.flatMap((page) => page.items) ?? []
  const createMutation = useCreateComment(teamSlug, entityType, entitySlug)
  const deleteMutation = useDeleteComment(teamSlug, entityType, entitySlug)

  const handleSubmit = (content: string, parentId?: string) => {
    createMutation.mutate(
      { content, parentId: parentId || undefined },
      {
        onSuccess: () => setReplyingTo(null),
      }
    )
  }

  const canDeleteComment = (comment: CommentDto) => {
    // Author can delete own, organizers/admins can delete any
    const isAuthor = comment.author.id === user?.id
    return isAuthor || isOrganizer
  }

  if (isLoading) {
    return (
      <Paper p="xl" shadow="xs" withBorder>
        <Center>
          <Loader />
        </Center>
      </Paper>
    )
  }

  return (
    <Paper p="xl" shadow="xs" withBorder>
      <Title order={2} size="h4" mb="md">
        {t('comments.title')} ({total})
      </Title>

      {/* Comment form for new top-level comments */}
      <CommentForm
        onSubmit={(content) => handleSubmit(content)}
        isLoading={createMutation.isPending}
        placeholder={t('comments.form.placeholder')}
      />

      {/* Comments list */}
      <Stack mt="xl">
        {comments.map((comment) => (
          <CommentItem
            key={comment.id}
            comment={comment}
            teamSlug={teamSlug}
            entityType={entityType}
            entitySlug={entitySlug}
            reportContext={{ teamSlug, teamName }}
            canDeleteComment={canDeleteComment}
            onDeleteComment={(commentId) => deleteMutation.mutate(commentId)}
            onReply={() => setReplyingTo(comment.id)}
            replyingTo={replyingTo}
            onReplySubmit={(content) => handleSubmit(content, comment.id)}
            onCancelReply={() => setReplyingTo(null)}
            isDeleting={deleteMutation.isPending}
            isReplying={createMutation.isPending}
          />
        ))}
        {comments.length === 0 && (
          <EmptyState
            icon={<IconMessageCircle size={48} />}
            title={t('comments.emptyTitle')}
            description={t('comments.empty')}
          />
        )}

        {hasNextPage && (
          <Button
            variant="subtle"
            onClick={() => fetchNextPage()}
            loading={isFetchingNextPage}
            mt="sm"
          >
            {t('comments.loadMore')}
          </Button>
        )}
      </Stack>
    </Paper>
  )
}
