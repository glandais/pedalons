import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { Alert, Button, Group, Modal, Stack, Text, Textarea } from '@mantine/core'
import { IconInfoCircle } from '@tabler/icons-react'
import {
  contactAdAuthorBodyMessageMax,
  contactAdAuthorBodyMessageMin,
  contactAdAuthorBodyMessageRegExp,
} from '@/api/zod/ads/ads.zod'
import { useContactAdAuthor } from '@/api/endpoints/ads/ads'
import { ApiClientError } from '@/lib/apiError'

/** What the modal reports back to the page that opened it. */
export type AdContactOutcome =
  /** 204: the server took the message. */
  | 'sent'
  /**
   * `AD_CONTACT_OPTED_OUT`: the author made themselves unreachable. Trying again changes nothing,
   * so the page drops the button entirely.
   */
  | 'optedOut'

interface AdContactModalProps {
  opened: boolean
  onClose: () => void
  teamSlug: string
  adSlug: string
  /** Display name of the author, so the modal says who the message goes to. */
  sellerName: string
  /**
   * Called with the outcomes the *page* has to render. Recoverable failures — a quota, a relay
   * outage — never reach it: they are handled here, draft in hand.
   */
  onOutcome: (outcome: AdContactOutcome) => void
}

interface Failure {
  color: 'orange' | 'red'
  message: string
}

/**
 * Writes to an ad's author through the server-side email relay.
 *
 * No address is involved on either side: the server sends the mail and sets `Reply-To` to the
 * sender, so the author can answer directly while neither address ever reaches the API or the
 * DOM. There is deliberately nothing here to display as a contact address.
 */
export function AdContactModal({
  opened,
  onClose,
  teamSlug,
  adSlug,
  sellerName,
  onOutcome,
}: AdContactModalProps) {
  const { t } = useTranslation()
  const [failure, setFailure] = useState<Failure | null>(null)
  // Every failure is rendered here (Alert) or by the page (opted out): the global toast would
  // duplicate it, and on a quota contradict its retry delay.
  const mutation = useContactAdAuthor({ request: { skipErrorToast: true } })

  const form = useForm({
    initialValues: { message: '' },
    validate: {
      message: (value) => {
        if (value.trim().length === 0 || !contactAdAuthorBodyMessageRegExp.test(value)) {
          return t('ads.contact.error.blank')
        }
        if (value.length < contactAdAuthorBodyMessageMin) return t('ads.contact.error.tooShort')
        if (value.length > contactAdAuthorBodyMessageMax) return t('ads.contact.error.tooLong')
        return null
      },
    },
  })

  const length = form.values.message.length
  const outOfBounds =
    length < contactAdAuthorBodyMessageMin || length > contactAdAuthorBodyMessageMax

  const describe = (error: unknown): Failure => {
    if (!(error instanceof ApiClientError)) {
      return { color: 'red', message: t('ads.contact.error.generic') }
    }
    switch (error.error.code) {
      case 'AD_CONTACT_RATE_LIMITED':
        return {
          color: 'orange',
          message: error.retryAfterSeconds
            ? t('ads.contact.error.rateLimitedIn', {
                minutes: Math.max(1, Math.ceil(error.retryAfterSeconds / 60)),
              })
            : t('ads.contact.error.rateLimited'),
        }
      case 'AD_CONTACT_DELIVERY_FAILED':
        return { color: 'red', message: t('ads.contact.error.deliveryFailed') }
      case 'AD_CONTACT_SELF':
        return { color: 'orange', message: t('errors.api.AD_CONTACT_SELF') }
      default:
        return { color: 'red', message: t('ads.contact.error.generic') }
    }
  }

  const handleSubmit = form.onSubmit((values) => {
    setFailure(null)
    mutation.mutate(
      { teamSlug, slug: adSlug, data: { message: values.message } },
      {
        // No optimistic success: the modal stays until the server has answered 204. A relay that
        // swallows a message is worse than one that fails, because the sender then waits for an
        // answer that will never come. The confirmation is a *state of the page* rather than a
        // toast that disappears before it is read, so the outcome goes back to the caller.
        onSuccess: () => {
          form.reset()
          onClose()
          onOutcome('sent')
        },
        // The draft is deliberately kept on every recoverable failure: a quota or a delivery
        // outage is not the sender's fault, and losing what they wrote would be.
        onError: (error) => {
          if (error instanceof ApiClientError && error.error.code === 'AD_CONTACT_OPTED_OUT') {
            // Nothing to retry: the page drops the button.
            form.reset()
            onClose()
            onOutcome('optedOut')
            return
          }
          setFailure(describe(error))
        },
      }
    )
  })

  const handleClose = () => {
    setFailure(null)
    onClose()
  }

  return (
    <Modal
      opened={opened}
      onClose={handleClose}
      title={t('ads.contact.title')}
      closeButtonProps={{ 'aria-label': t('aria.closeDialog') }}
    >
      <form onSubmit={handleSubmit}>
        <Stack>
          <Text size="sm" c="dimmed">
            {t('ads.contact.intro', { seller: sellerName })}
          </Text>

          {/* A consent, not a footnote. The API discloses no address; the sender's own goes out
              all the same, since the server puts the `Reply-To` on it. Saying so before the send
              is the only way it is chosen. */}
          <Alert variant="light" icon={<IconInfoCircle size={16} />}>
            {t('ads.contact.disclosure')}
          </Alert>

          {failure && <Alert color={failure.color}>{failure.message}</Alert>}

          <Stack gap={4}>
            <Textarea
              autosize
              minRows={4}
              maxRows={12}
              label={t('ads.contact.messageLabel')}
              placeholder={t('ads.contact.placeholder')}
              {...form.getInputProps('message')}
            />
            <Text size="xs" c="dimmed" ta="right">
              {t('ads.contact.counter', { length, max: contactAdAuthorBodyMessageMax })}
            </Text>
          </Stack>

          <Group justify="flex-end">
            <Button variant="default" onClick={handleClose}>
              {t('actions.cancelAction')}
            </Button>
            <Button type="submit" loading={mutation.isPending} disabled={outOfBounds}>
              {failure ? t('generic.retry') : t('ads.contact.send')}
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}
