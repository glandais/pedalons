import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Stack, Text, Button, Box } from '@mantine/core'
import { IconTrash, IconMessage } from '@tabler/icons-react'
import { UserAvatar } from '../common/UserAvatar'
import { CommentForm } from './CommentForm'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { useFormattedDate } from '../../utils/dateFormat'
import type { CommentDto } from '@/api/dto'
import { ReportTargetType } from '@/api/dto'
import { useCommentReplies, type EntityType } from '../../hooks/useComments'
import { ContentActionsMenu } from '../moderation/ContentActionsMenu'
import { PlainTextWithLinks } from '../common/PlainTextWithLinks'

/** Where a report of this comment goes: the team the commented content belongs to. */
export interface CommentReportContext {
  teamSlug: string
  teamName: string
}

interface CommentItemProps {
  comment: CommentDto
  /** Needed to expand a thread whose replies were not embedded in the page. */
  teamSlug?: string
  entityType?: EntityType
  entitySlug?: string
  /** Enables the report/block menu. Passed down to replies, unlike the slugs above. */
  reportContext?: CommentReportContext
  canDeleteComment: (comment: CommentDto) => boolean
  onDeleteComment: (commentId: string) => void
  onReply?: () => void
  replyingTo: string | null
  onReplySubmit?: (content: string) => void
  onCancelReply?: () => void
  isDeleting: boolean
  isReplying: boolean
  isReply?: boolean
}

export function CommentItem({
  comment,
  teamSlug,
  entityType,
  entitySlug,
  reportContext,
  canDeleteComment,
  onDeleteComment,
  onReply,
  replyingTo,
  onReplySubmit,
  onCancelReply,
  isDeleting,
  isReplying,
  isReply = false,
}: CommentItemProps) {
  // A deleted account's comment kept only to carry the replies others wrote: no author, no actions.
  const isTombstone = comment.deleted
  const canDelete = !isTombstone && canDeleteComment(comment)
  const { t } = useTranslation()
  const { formatRelative } = useFormattedDate()
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [threadExpanded, setThreadExpanded] = useState(false)

  const isReplyingToThis = replyingTo === comment.id

  // A page of top-level comments does not necessarily embed every reply; `replyCount` is
  // authoritative, so anything it counts beyond what we hold is fetched on demand.
  const embedded = comment.replies ?? []
  const hasHiddenReplies = comment.replyCount > embedded.length
  const { data: fetchedReplies, isFetching: isFetchingReplies } = useCommentReplies(
    teamSlug,
    entityType ?? 'rides',
    entitySlug,
    comment.id,
    threadExpanded && hasHiddenReplies && !!teamSlug && !!entitySlug
  )
  const replies = threadExpanded && fetchedReplies ? fetchedReplies.items : embedded

  return (
    <Box
      ml={isReply ? 'xl' : 0}
      pl={isReply ? 'md' : 0}
      style={isReply ? { borderLeft: '2px solid var(--mantine-color-default-border)' } : undefined}
    >
      {isTombstone ? (
        <Text size="sm" c="dimmed" fs="italic">
          {t('comments.deletedPlaceholder')}
        </Text>
      ) : (
        <Group align="flex-start" gap="sm">
          <UserAvatar user={comment.author} size="sm" />
          <Stack gap={4} style={{ flex: 1, minWidth: 0 }}>
            <Group gap="xs" justify="space-between" wrap="nowrap">
              <Group gap="xs">
                <Text fw={500}>{comment.author.displayName}</Text>
                {/* Read off the clock: server and client may render it a few seconds apart. */}
                <Text size="xs" c="dimmed" suppressHydrationWarning>
                  {formatRelative(comment.createdAt)}
                </Text>
              </Group>
              {reportContext && (
                <ContentActionsMenu
                  teamSlug={reportContext.teamSlug}
                  teamName={reportContext.teamName}
                  targetType={ReportTargetType.COMMENT}
                  targetId={comment.id}
                  author={comment.author}
                  placement="inline"
                />
              )}
            </Group>
            <Text style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
              <PlainTextWithLinks text={comment.content} />
            </Text>

            <Group mt={4}>
              {!isReply && onReply && (
                <Button
                  variant="subtle"
                  size="xs"
                  color="gray"
                  leftSection={<IconMessage size={14} />}
                  onClick={onReply}
                >
                  {t('comments.actions.reply')}
                </Button>
              )}
              {canDelete && (
                <Button
                  variant="subtle"
                  size="xs"
                  color="danger"
                  leftSection={<IconTrash size={14} />}
                  onClick={() => setShowDeleteConfirm(true)}
                >
                  {t('actions.delete')}
                </Button>
              )}
            </Group>
          </Stack>
        </Group>
      )}

      {isReplyingToThis && onReplySubmit && onCancelReply && (
        <Box mt="sm" ml={44}>
          <CommentForm
            onSubmit={onReplySubmit}
            onCancel={onCancelReply}
            isLoading={isReplying}
            placeholder={t('comments.form.replyPlaceholder')}
            autoFocus
          />
        </Box>
      )}

      {!isReply && hasHiddenReplies && !threadExpanded && (
        <Button
          variant="subtle"
          size="xs"
          color="gray"
          mt="xs"
          ml={44}
          loading={isFetchingReplies}
          onClick={() => setThreadExpanded(true)}
        >
          {t('comments.showReplies', { count: comment.replyCount })}
        </Button>
      )}

      {replies.length > 0 && (
        <Stack gap="sm" mt="md">
          {replies.map((reply) => (
            <CommentItem
              key={reply.id}
              comment={reply}
              reportContext={reportContext}
              canDeleteComment={canDeleteComment}
              onDeleteComment={onDeleteComment}
              replyingTo={null}
              isDeleting={isDeleting}
              isReplying={isReplying}
              isReply
            />
          ))}
        </Stack>
      )}

      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={() => {
          onDeleteComment(comment.id)
          setShowDeleteConfirm(false)
        }}
        title={t('comments.confirmDelete.title')}
        message={t('comments.confirmDelete.message')}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={isDeleting}
      />
    </Box>
  )
}
