import { Badge, Box, Group, Text } from '@mantine/core'
import { IconMapPin } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { DayBox, type DayBoxTone } from './DayBox'
import { ZoneMentionText } from './Rendezvous'
import classes from './DepartureBlock.module.css'

interface DepartureBlockProps {
  /** The departure: the ride's own `dateTime` on its detail (not the group's), a trip's start. */
  date: string
  /** The entity's zone: every time of the block reads in it (docs/LEDGER_*.md API-60). */
  zone: string | null | undefined
  /** The day box's tone: indigo for a ride or a stage, turquoise for a trip. */
  tone?: DayBoxTone
  /**
   * The line under the time, in place of the long day « samedi 12 avril » — a trip's span
   * « ven. 16 → dim. 18 mai », which already names the last day: the return then says its time
   * alone.
   */
  dayLine?: string
  /** The estimated return (`endDateTime`), « retour vers 14:10 ». */
  returnAt?: string | null
  /** The zone the return reads in, when not the departure's (a trip's last stage). */
  returnZone?: string | null
  /** Where everyone meets. */
  place?: { name: string; address?: string } | null
  /**
   * The reader's group, when it leaves at another time than the departure (`groupLeavesAtOwnTime`):
   * « Votre groupe · Groupe B · 09:30 » on the right.
   */
  group?: { name: string; startAt: string } | null
}

/**
 * The departure block of a detail page (docs/BRANDING.md §7.8, ledger `BRAND-8`): just under the
 * title and the badges, before the description. The flat day box on the left; « Départ 09:00 »,
 * the « Demain » pill, « samedi 12 avril · retour vers 14:10 », the zone mention and the start
 * place in the middle; the reader's group and its time on the right, below the rest under 600 px.
 */
export function DepartureBlock({
  date,
  zone,
  tone = 'primary',
  dayLine,
  returnAt,
  returnZone,
  place,
  group,
}: DepartureBlockProps) {
  const { t } = useTranslation()
  const start = useRendezvousFormat(zone)
  const back = useRendezvousFormat(returnZone ?? zone)
  const relative = start.formatRelativeDay(date)
  const mention = start.mention(date)

  const returnText = (() => {
    if (!returnAt || Number.isNaN(Date.parse(returnAt))) return null
    // The same local day, or a span that already names the last one: its time is enough.
    const sameDay =
      start.formatPattern(date, 'yyyy-MM-dd') === back.formatPattern(returnAt, 'yyyy-MM-dd')
    const time =
      sameDay || dayLine
        ? back.formatTime(returnAt)
        : back.formatDeparture(returnAt, { relative: false })
    return t('agenda.returnAround', { time })
  })()
  const day = dayLine ?? start.formatLongDay(date)

  return (
    <Box component="section" aria-label={t('departure.block.label')} className={classes.root}>
      <div className={classes.surface}>
        <DayBox date={date} zone={start.zone} tone={tone} size="lg" />

        <div className={classes.main}>
          <Group gap="sm" wrap="wrap" align="center">
            <Text fz={24} fw={700} lh={1.2} suppressHydrationWarning={start.isGuessedText}>
              {t('departure.block.time', { time: start.formatTime(date) })}
            </Text>
            {relative && (
              <Badge variant="light" color={tone} suppressHydrationWarning>
                {relative}
              </Badge>
            )}
          </Group>
          <Text size="sm" c="dimmed" mt={4}>
            <span suppressHydrationWarning={start.isGuessedText}>
              {returnText ? t('departure.block.dayLine', { day, back: returnText }) : day}
            </span>
            <ZoneMentionText mention={mention} isGuessed={start.isGuessedTimezone} />
          </Text>
          {place && (
            <Group gap={6} mt={6} wrap="nowrap" align="flex-start">
              <IconMapPin
                size={16}
                color="var(--mantine-color-green-text)"
                role="img"
                aria-label={t('departure.block.placeLabel')}
                style={{ flex: '0 0 auto', marginTop: 2 }}
              />
              <Text size="sm">
                <Text span fw={500}>
                  {place.name}
                </Text>
                {place.address && (
                  <Text span c="dimmed">
                    {' '}
                    ({place.address})
                  </Text>
                )}
              </Text>
            </Group>
          )}
        </div>

        {group && (
          <div className={classes.group} data-testid="departure-group">
            <Text size="sm" c="dimmed">
              {t('departure.block.yourGroup')}
            </Text>
            <Text fw={700} suppressHydrationWarning={start.isGuessedText}>
              {t('departure.block.group', {
                name: group.name,
                time: start.formatTime(group.startAt),
              })}
            </Text>
          </div>
        )}
      </div>
    </Box>
  )
}
