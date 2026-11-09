import type { ReactNode } from 'react'
import { Group, Text, VisuallyHidden } from '@mantine/core'
import { IconClock } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useEffectiveTimezone } from '@/utils/dateFormat'
import { formatPublicationSpan, spanStart, type DatedPublication } from '@/utils/publicationTiming'
import type { DayBoxTone } from './DayBox'
import { ZoneMentionIcon } from './Rendezvous'

interface DepartureLineProps {
  /** The departure that concerns the reader: their group's for a registered ride (`startFor`). */
  date: string
  /** The entity's zone: every time of the line reads in it (docs/LEDGER_*.md API-60). */
  zone: string | null | undefined
  /**
   * `md` (a card): 16 px/700 beside an 18 px clock. `sm` (a row of a list, under a 600 title):
   * 14 px/700 beside a 16 px clock.
   */
  size?: 'md' | 'sm'
  /**
   * No day box beside the line: « sam. 12 avr. · 09:00 » (« Demain · 09:00 ») rather than
   * « Départ 09:00 ».
   */
  withDay?: boolean
  /** In place of the departure: a trip's span, « ven. 16 → dim. 18 mai ». */
  label?: string
  /** The clock's colour: indigo for a ride or a stage, turquoise for a trip. */
  tone?: DayBoxTone
  /** What follows, dimmed (« Groupe B »). */
  detail?: ReactNode
  /**
   * The day box beside it is hidden from assistive tech (inside an `aria-hidden` thumbnail): the
   * long day « samedi 12 avril » is then read before the time, and only read.
   */
  announceDay?: boolean
  /** One line, cut with an ellipsis rather than wrapped — a fullscreen map's 48 px toolbar. */
  truncate?: boolean
}

/**
 * The departure line of a card or a row (docs/BRANDING.md §7.8, ledger `BRAND-8`): the indigo
 * clock and « Départ 09:00 » in 700 and the text colour — a
 * primary piece of information, never one statistic among others (docs/LEDGER_*.md WEB-138). The
 * zone indicator follows the time it describes.
 */
export function DepartureLine({
  date,
  zone,
  size = 'md',
  withDay = false,
  label,
  tone = 'primary',
  detail,
  announceDay = false,
  truncate = false,
}: DepartureLineProps) {
  const { t } = useTranslation()
  const rendezvous = useRendezvousFormat(zone)
  const main =
    label ??
    (withDay
      ? rendezvous.formatDeparture(date)
      : t('departure.block.time', { time: rendezvous.formatTime(date) }))

  return (
    <Group gap={6} wrap="nowrap" align="flex-start" data-testid="departure-line">
      <IconClock
        size={size === 'md' ? 18 : 16}
        color={`var(--mantine-color-${tone}-filled)`}
        aria-hidden
        style={{ flex: '0 0 auto', marginTop: size === 'md' ? 3 : 2 }}
      />
      <Text fz={size === 'md' ? 16 : 14} lh={1.4} truncate={truncate} style={{ minWidth: 0 }}>
        {announceDay && !withDay && !label && (
          <VisuallyHidden suppressHydrationWarning={rendezvous.isGuessedText}>
            {rendezvous.formatLongDay(date)}
            {', '}
          </VisuallyHidden>
        )}
        <Text span inherit fw={700} suppressHydrationWarning={rendezvous.isGuessedText || withDay}>
          {main}
        </Text>
        <ZoneMentionIcon
          mention={rendezvous.mention(date)}
          isGuessed={rendezvous.isGuessedTimezone}
        />
        {detail && (
          <Text span fz={14} c="dimmed" suppressHydrationWarning={rendezvous.isGuessedText}>
            {' · '}
            {detail}
          </Text>
        )}
      </Text>
    </Group>
  )
}

/**
 * The departure line of a ride or a trip: a ride's « Départ 09:00 » from the
 * reader's group's departure (`spanStart`, docs/LEDGER_*.md WEB-136), a trip's span on the
 * turquoise clock.
 */
export function PublicationDepartureLine({
  publication,
  size,
  withDay,
  detail,
}: {
  publication: DatedPublication
  size?: 'md' | 'sm'
  withDay?: boolean
  detail?: ReactNode
}) {
  const { t, i18n } = useTranslation()
  const { timezone: readerZone } = useEffectiveTimezone()
  if (publication.type === 'TRIP') {
    return (
      <DepartureLine
        date={publication.dateTime}
        zone={publication.timezone}
        size={size}
        tone="teal"
        label={formatPublicationSpan(publication, 'full', i18n.language, t, readerZone)}
        detail={detail}
      />
    )
  }
  return (
    <DepartureLine
      date={spanStart(publication)}
      zone={publication.timezone}
      size={size}
      withDay={withDay}
      detail={detail}
    />
  )
}
