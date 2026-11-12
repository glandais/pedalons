import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Button, Group, Modal, Radio, Stack, Text, Textarea } from '@mantine/core'
import { useReportContent } from '@/api/endpoints/moderation/moderation'
import { ReportReason } from '@/api/dto'
import type { ReportTargetType } from '@/api/dto'
import { useAppName } from '@/hooks/useAppName'
import { invalidateModeratedContent } from '@/lib/moderationCacheInvalidation'

/** Same cap as `ReportRequest.message`. */
const MESSAGE_MAX_LENGTH = 500

const REASONS = Object.values(ReportReason)

interface ReportModalProps {
  opened: boolean
  onClose: () => void
  /** The team the content belongs to: its organizers receive the report. */
  teamSlug: string
  teamName: string
  targetType: ReportTargetType
  targetId: string
  /** Called once the report is accepted, after the lists have been told to refetch. */
  onReported?: () => void
}

/**
 * "Report" — a reason, an optional message, and who it goes to.
 *
 * Once sent, the content disappears from the reporter's own lists (the server filters it out), so
 * every list is refetched rather than only the one the content came from.
 */
export function ReportModal({
  opened,
  onClose,
  teamSlug,
  teamName,
  targetType,
  targetId,
  onReported,
}: ReportModalProps) {
  const { t } = useTranslation()
  const appName = useAppName()
  const queryClient = useQueryClient()
  const [reason, setReason] = useState<ReportReason | null>(null)
  const [message, setMessage] = useState('')
  const reportMutation = useReportContent()

  const close = () => {
    setReason(null)
    setMessage('')
    onClose()
  }

  const handleSubmit = () => {
    if (!reason) return
    const trimmed = message.trim()
    reportMutation.mutate(
      {
        data: {
          teamSlug,
          targetType,
          targetId,
          reason,
          message: trimmed ? trimmed : undefined,
        },
      },
      {
        onSuccess: () => {
          void invalidateModeratedContent(queryClient)
          // A member is not hidden by a report, unlike a piece of content.
          notifications.show({
            message:
              targetType === 'MEMBER'
                ? t('moderation.report.successMember')
                : t('moderation.report.success'),
            color: 'green',
          })
          close()
          onReported?.()
        },
      }
    )
  }

  return (
    <Modal
      opened={opened}
      onClose={close}
      title={t(`moderation.report.title.${targetType satisfies ReportTargetType}`)}
      centered
    >
      <Stack>
        <Radio.Group
          value={reason}
          onChange={(value) => setReason(value as ReportReason)}
          label={t('moderation.report.reasonLabel')}
          withAsterisk
        >
          <Stack gap="xs" mt="xs">
            {REASONS.map((value) => (
              <Radio
                key={value}
                value={value}
                label={t(`moderation.reason.${value satisfies ReportReason}`)}
              />
            ))}
          </Stack>
        </Radio.Group>

        <Textarea
          label={t('moderation.report.messageLabel')}
          placeholder={t('moderation.report.messagePlaceholder')}
          value={message}
          onChange={(event) => setMessage(event.currentTarget.value)}
          maxLength={MESSAGE_MAX_LENGTH}
          autosize
          minRows={2}
          maxRows={6}
        />

        <Text size="sm" c="dimmed">
          {t('moderation.report.recipients', { team: teamName, appName })}
        </Text>

        <Group justify="flex-end">
          <Button variant="default" onClick={close} disabled={reportMutation.isPending}>
            {t('actions.cancelAction')}
          </Button>
          <Button
            color="danger"
            onClick={handleSubmit}
            disabled={!reason}
            loading={reportMutation.isPending}
          >
            {t('moderation.report.submit')}
          </Button>
        </Group>
      </Stack>
    </Modal>
  )
}
