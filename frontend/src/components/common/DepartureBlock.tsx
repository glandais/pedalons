import { Badge, Box, Group, Text } from '@mantine/core'
import { IconMapPin } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { groupTitle } from '@/utils/groupTitle'
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
  /** The line under the time: a trip's span « ven. 16 → dim. 18 mai », which names its last day. */
  dayLine?: string
  /** Where everyone meets. */
  place?: { name: string; address?: string } | null
  /**
   * The reader's group, when it leaves at another time than the departure (`groupLeavesAtOwnTime`):
   * its time becomes the block's (« Départ 09:30 »), and a line under it names the group and the
   * ride's first departure (« **Groupe B** · premier départ 09:00 ») — the app's reading (KIT §8,
   * docs/LEDGER_*.md WEB-165).
   */
  group?: { name: string; startAt: string } | null
}

/**
 * The departure block of a detail page (docs/BRANDING.md §7.8, ledger `BRAND-8`): just under the
 * title and the badges, before the description. The flat day box on the left; « Départ 09:00 »
 * (the reader's group's time when it has its own), the « Demain » pill, the trip's span, the zone
 * mention, the reader's group line and the start place on the right.
 */
export function DepartureBlock({
  date,
  zone,
  tone = 'primary',
  dayLine,
  place,
  group,
}: DepartureBlockProps) {
  const { t } = useTranslation()
  const start = useRendezvousFormat(zone)
  // The time the reader leaves at: their group's, when it has its own.
  const leaves = group?.startAt ?? date
  const relative = start.formatRelativeDay(leaves)
  const mention = start.mention(leaves)

  // The day box already says the day: no « samedi 12 avril » beside it (docs/BRANDING.md §7.8).
  // A trip's span stays, it names the last day too.

  return (
    <Box component="section" aria-label={t('departure.block.label')}>
      <div className={classes.surface}>
        <DayBox date={leaves} zone={start.zone} tone={tone} size="lg" />

        <div className={classes.main}>
          <Group gap="sm" wrap="wrap" align="center">
            <Text fz={24} fw={700} lh={1.2} suppressHydrationWarning={start.isGuessedText}>
              {t('departure.block.time', { time: start.formatTime(leaves) })}
            </Text>
            {relative && (
              <Badge variant="light" color={tone} suppressHydrationWarning>
                {relative}
              </Badge>
            )}
          </Group>
          {(dayLine || mention) && (
            <Text size="sm" c="dimmed" mt={4}>
              {dayLine ? (
                <>
                  <span suppressHydrationWarning={start.isGuessedText}>{dayLine}</span>
                  <ZoneMentionText mention={mention} isGuessed={start.isGuessedTimezone} />
                </>
              ) : (
                // Alone on its line: no leading « · ».
                <span suppressHydrationWarning={start.isGuessedTimezone}>{mention?.full}</span>
              )}
            </Text>
          )}
          {group && (
            <Text size="sm" mt={6} data-testid="departure-group">
              <Text span fw={600}>
                {groupTitle(group.name, t)}
              </Text>
              <Text span c="dimmed" suppressHydrationWarning={start.isGuessedText}>
                {' · '}
                {t('departure.block.firstDeparture', { time: start.formatTime(date) })}
              </Text>
            </Text>
          )}
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
      </div>
    </Box>
  )
}
