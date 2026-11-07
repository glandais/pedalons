import { useTranslation } from 'react-i18next'
import { Box, Group, Stack, Text, ThemeIcon, UnstyledButton } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useFormattedDate } from '@/utils/dateFormat'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import type { NotificationDto } from '@/api/dto'
import { NotificationChange, NotificationType } from '@/api/dto'
import { notificationColor, notificationIcon, notificationPath } from './notificationDisplay'

interface NotificationItemProps {
  notification: NotificationDto
  /** Marks it read. Called before navigating, so opening one clears its dot. */
  onOpen: (notification: NotificationDto) => void
  /** The bell's dropdown is tighter than the page's list. */
  compact?: boolean
}

/**
 * One inbox entry, shared by the bell dropdown and the notifications page.
 *
 * The wording is built here from the type and the structured fields — the API sends no rendered
 * text (`docs/plans/archive/2026-09-18-notifications.md` §3). An unread entry is marked by a dot and a
 * heavier title rather than a background tint: the row is a link, and a tinted link fights the
 * hover state.
 */
export function NotificationItem({ notification, onOpen, compact = false }: NotificationItemProps) {
  const { t } = useTranslation()
  // `createdAt` is a timestamp, read in the reader's zone; `subjectDateTime` is a rendezvous, read
  // in the subject's own zone with the « heure de Tokyo (…) » mention (docs/LEDGER_*.md API-60).
  // A notification sent before 10.20.0 has no `subjectTimezone`: the hook then falls back to the
  // reader's zone, without mention.
  const { formatRelative } = useFormattedDate()
  const rendezvous = useRendezvousFormat(notification.subjectTimezone)

  const Icon = notificationIcon(notification.type)
  const color = notificationColor(notification.type)

  // The subject's own name carries the "what", so the sentence only has to say the "why".
  const title = t(
    `notifications.type.${notification.type satisfies NotificationType}`,
    // `actorName` is absent for a scheduled publication: the fallback keeps the sentence whole
    // rather than rendering "undefined".
    {
      actor: notification.actorName ?? notification.teamName,
      team: notification.teamName,
    }
  )

  // What moved, for RIDE_UPDATED: the snapshot says which fields changed, and `subjectDateTime` is
  // already the new date. A reminder carries no change but reads better with its start time. The
  // dated clause goes last, so the zone mention that closes the line sits right after its date.
  const date = notification.subjectDateTime
    ? // The departure's one format, « Demain · 09:00 » included (docs/BRANDING.md §8.3, WEB-138).
      rendezvous.formatDeparture(notification.subjectDateTime)
    : ''
  const clauses =
    notification.type === NotificationType.RIDE_REMINDER && notification.subjectDateTime
      ? [t('notifications.item.startsAt', { date })]
      : [
          ...notification.changes.filter((change) => change !== NotificationChange.DATE_TIME),
          ...notification.changes.filter((change) => change === NotificationChange.DATE_TIME),
        ].map((change) =>
          t(`notifications.change.${change satisfies NotificationChange}`, { date })
        )
  const dated =
    notification.type === NotificationType.RIDE_REMINDER ||
    notification.changes.includes(NotificationChange.DATE_TIME)
  const mention = dated ? rendezvous.mention(notification.subjectDateTime) : null
  if (mention && clauses.length > 0) clauses.push(mention.full)
  const details = clauses.join(' · ')

  // The excerpt is a quoted comment — except for a join or a removed group, where it is the group's
  // name.
  const namesAGroup =
    notification.type === NotificationType.RIDE_JOINED ||
    notification.type === NotificationType.RIDE_GROUP_REMOVED
  const excerpt =
    notification.excerpt && namesAGroup
      ? t('notifications.item.group', { group: notification.excerpt })
      : notification.excerpt

  return (
    <UnstyledButton
      component={PrefetchLink}
      to={notificationPath(notification)}
      onClick={() => onOpen(notification)}
      p={compact ? 'xs' : 'sm'}
      style={{ borderRadius: 'var(--mantine-radius-md)', display: 'block' }}
    >
      <Group gap="sm" wrap="nowrap" align="flex-start">
        <ThemeIcon variant="light" color={color} size={compact ? 'md' : 'lg'} radius="xl">
          <Icon size={compact ? 16 : 18} />
        </ThemeIcon>
        <Stack gap={2} style={{ flex: 1, minWidth: 0 }}>
          <Text size="sm" fw={notification.read ? 400 : 600} lineClamp={2}>
            {title}
          </Text>
          <Text size="sm" c="dimmed" lineClamp={compact ? 1 : 2}>
            {notification.subjectName}
          </Text>
          {details && (
            // The mention depends on the reader's zone, and so does the date without a subject
            // zone (`isGuessedText` implies `isGuessedTimezone`).
            <Text size="xs" c="dimmed" suppressHydrationWarning={rendezvous.isGuessedTimezone}>
              {details}
            </Text>
          )}
          {excerpt && (
            <Text size="xs" c="dimmed" fs={namesAGroup ? undefined : 'italic'} lineClamp={2}>
              {excerpt}
            </Text>
          )}
          {/* "il y a 2 minutes" is read off the clock, not off a timezone: server and client
              legitimately render different text a few seconds apart. */}
          <Text size="xs" c="dimmed" suppressHydrationWarning>
            {t('notifications.item.meta', {
              team: notification.teamName,
              when: formatRelative(notification.createdAt),
            })}
          </Text>
        </Stack>
        {!notification.read && (
          <Box
            w={8}
            h={8}
            mt={6}
            style={{ borderRadius: '50%', backgroundColor: `var(--mantine-color-${color}-filled)` }}
            aria-label={t('notifications.item.unread')}
          />
        )}
      </Group>
    </UnstyledButton>
  )
}
