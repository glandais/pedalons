import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { useDisclosure } from '@mantine/hooks'
import { notifications } from '@mantine/notifications'
import {
  Alert,
  Anchor,
  Button,
  Checkbox,
  Code,
  Collapse,
  Group,
  Modal,
  SegmentedControl,
  Stack,
  Text,
  Textarea,
} from '@mantine/core'
import type { ClientContextDto, ClientLogEntryDto, FeedbackKind } from '@/api/dto'
import { useSendFeedback } from '@/api/endpoints/feedback/feedback'
import {
  sendFeedbackBodyMessageMax,
  sendFeedbackBodyMessageMin,
} from '@/api/zod/feedback/feedback.zod'
import { ApiClientError } from '@/lib/apiError'
import { buildClientContext } from '@/lib/feedback/clientContext'
import { getLogEntries } from '@/lib/feedback/clientLog'
import { useFeedbackStore } from '@/lib/feedback/feedbackStore'

interface Failure {
  color: 'orange' | 'red'
  message: string
}

/**
 * "Report a problem": the member's words, plus — if they agree — the technical context and the
 * browser's recent log, shown in full before sending. The server turns it into an issue of the
 * maintainers' private repository.
 *
 * Mounted once, outside the router (see AppFrame): it reads the location from `window`.
 */
export function FeedbackModal() {
  const { t } = useTranslation()
  const { opened, error, close } = useFeedbackStore()
  const [failure, setFailure] = useState<Failure | null>(null)
  const [context, setContext] = useState<ClientContextDto | null>(null)
  const [logs, setLogs] = useState<ClientLogEntryDto[]>([])
  const [previewOpened, { toggle: togglePreview }] = useDisclosure(false)
  // Failures are rendered in the modal, draft in hand: the global toast would say it twice.
  const mutation = useSendFeedback({ request: { skipErrorToast: true } })

  const form = useForm({
    initialValues: { kind: 'BUG' as FeedbackKind, message: '', attach: true },
    validate: {
      // A bug may go without a description: whoever hit an error may not know what happened, and
      // the context, error and log speak for them. A suggestion is nothing but its text.
      message: (value, values) => {
        const length = value.trim().length
        if (length === 0 && values.kind === 'BUG') return null
        if (length < sendFeedbackBodyMessageMin) return t('feedback.error.tooShort')
        if (length > sendFeedbackBodyMessageMax) return t('feedback.error.tooLong')
        return null
      },
    },
  })

  // The context and the log are captured when the modal opens: what the member saw, not what
  // typing the report added.
  useEffect(() => {
    if (!opened) return
    setLogs(getLogEntries())
    void buildClientContext().then(setContext)
  }, [opened])

  const describe = (err: unknown): Failure => {
    if (err instanceof ApiClientError && err.error.code === 'FEEDBACK_RATE_LIMITED') {
      return {
        color: 'orange',
        message: err.retryAfterSeconds
          ? t('feedback.error.rateLimitedIn', {
              minutes: Math.max(1, Math.ceil(err.retryAfterSeconds / 60)),
            })
          : t('errors.api.FEEDBACK_RATE_LIMITED'),
      }
    }
    return { color: 'red', message: t('feedback.error.generic') }
  }

  const handleSubmit = form.onSubmit(async (values) => {
    setFailure(null)
    const ctx = context ?? (await buildClientContext())
    mutation.mutate(
      {
        data: {
          kind: values.kind,
          message: values.message.trim() || undefined,
          context: values.attach ? ctx : { platform: ctx.platform, appVersion: ctx.appVersion },
          error: values.attach ? error : undefined,
          logs: values.attach ? logs : undefined,
        },
      },
      {
        onSuccess: () => {
          form.reset()
          close()
          notifications.show({ message: t('feedback.sent'), color: 'green' })
        },
        // The draft is kept on every failure: losing a written report is worse than a retry.
        onError: (err) => setFailure(describe(err)),
      }
    )
  })

  const handleClose = () => {
    setFailure(null)
    close()
  }

  const preview = JSON.stringify(
    {
      context,
      error,
      logs: logs.map((e) => `${e.ts} ${e.level} [${e.source}] ${e.message}`),
    },
    null,
    2
  )

  return (
    <Modal
      opened={opened}
      onClose={handleClose}
      title={t('feedback.title')}
      size="lg"
      closeButtonProps={{ 'aria-label': t('aria.closeDialog') }}
    >
      <form onSubmit={handleSubmit}>
        <Stack>
          <SegmentedControl
            data={[
              { value: 'BUG', label: t('feedback.kind.BUG') },
              { value: 'SUGGESTION', label: t('feedback.kind.SUGGESTION') },
            ]}
            {...form.getInputProps('kind')}
          />

          {error && (
            <Alert color="red" variant="light" title={t('feedback.errorAttached')}>
              <Text size="sm">{`${error.type}: ${error.message}`}</Text>
            </Alert>
          )}

          {failure && <Alert color={failure.color}>{failure.message}</Alert>}

          <Stack gap={4}>
            <Textarea
              autosize
              minRows={4}
              maxRows={12}
              label={
                form.values.kind === 'BUG'
                  ? t('feedback.messageLabel.BUG')
                  : t('feedback.messageLabel.SUGGESTION')
              }
              placeholder={
                form.values.kind === 'BUG'
                  ? t('feedback.placeholder.BUG')
                  : t('feedback.placeholder.SUGGESTION')
              }
              {...form.getInputProps('message')}
            />
            <Text size="xs" c="dimmed" ta="right">
              {t('feedback.counter', {
                length: form.values.message.length,
                max: sendFeedbackBodyMessageMax,
              })}
            </Text>
          </Stack>

          <Stack gap={4}>
            <Checkbox
              label={t('feedback.attach')}
              {...form.getInputProps('attach', { type: 'checkbox' })}
            />
            <Text size="xs" c="dimmed">
              {t('feedback.attachDescription')}{' '}
              <Anchor component="button" type="button" size="xs" onClick={togglePreview}>
                {previewOpened ? t('feedback.hidePreview') : t('feedback.showPreview')}
              </Anchor>
            </Text>
            <Collapse expanded={previewOpened}>
              <Code block mah={240} style={{ overflow: 'auto' }}>
                {preview}
              </Code>
            </Collapse>
          </Stack>

          <Group justify="flex-end">
            <Button variant="default" onClick={handleClose}>
              {t('actions.cancelAction')}
            </Button>
            <Button type="submit" loading={mutation.isPending}>
              {failure ? t('generic.retry') : t('feedback.send')}
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}
