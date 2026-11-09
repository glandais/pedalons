import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconArrowsMaximize, IconArrowUp, IconBolt, IconClock } from '@tabler/icons-react'
import { Group, Paper, SimpleGrid, Stack, Text } from '@mantine/core'
import { Rendezvous } from '@/components/common/Rendezvous'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useUnits } from '@/hooks/useUnits'

/** One figure: its label above, its value, an optional line below. */
function StatTile({
  icon,
  label,
  children,
  hint,
}: {
  icon: ReactNode
  label: string
  children: ReactNode
  hint?: ReactNode
}) {
  return (
    <Stack gap={2}>
      <Group gap={4} wrap="nowrap" c="dimmed">
        {icon}
        <Text size="xs" tt="uppercase" fw={600} c="dimmed">
          {label}
        </Text>
      </Group>
      <Text fw={700} size="lg" style={{ whiteSpace: 'nowrap' }}>
        {children}
      </Text>
      {hint && (
        <Text size="xs" c="dimmed">
          {hint}
        </Text>
      )}
    </Stack>
  )
}

interface StatsCardProps {
  /** The zone the departure and the arrival read in: the ride's, the stage's. */
  timezone: string
  /** The « Départ » tile, when the page has no departure block above it (docs/BRANDING.md §7.8). */
  departure?: string
  averageSpeed?: number
  distance?: number
  elevationGain?: number
  /** The estimated arrival of the leg, when the forecast gives one. */
  arrival?: string
  testId?: string
}

/**
 * Pace, distance and climb — each one only when known — and, under the pace, the estimated arrival:
 * a ride group's figures and a trip stage's alike (docs/LEDGER_*.md WEB-155), on their pages and on
 * a solo ride's (WEB-79).
 */
export function StatsCard({
  timezone,
  departure,
  averageSpeed,
  distance: meters,
  elevationGain,
  arrival,
  testId,
}: StatsCardProps) {
  const { t } = useTranslation()
  const { speed, distance, elevation } = useUnits()
  const rendezvous = useRendezvousFormat(timezone)

  return (
    <Paper withBorder p="lg" data-testid={testId}>
      {/* Container query: the tiles sit in a narrow side column on wide screens, so the viewport
          width says nothing about the room they have. */}
      <SimpleGrid type="container" cols={{ base: 2, '560px': 4 }} spacing="md">
        {departure && (
          <StatTile
            icon={<IconClock size={14} aria-hidden />}
            label={t('rides.group.stats.departure')}
          >
            <Rendezvous date={departure} zone={timezone} format="time" />
          </StatTile>
        )}
        {/* A 0 pace means none — and `0 && …` would render a bare « 0 ». */}
        {!!averageSpeed && (
          <StatTile
            icon={<IconBolt size={14} aria-hidden />}
            label={t('rides.group.stats.pace')}
            hint={
              arrival && (
                <span suppressHydrationWarning={rendezvous.isGuessedText}>
                  {t('rides.group.stats.arrival', { time: rendezvous.formatTime(arrival) })}
                </span>
              )
            }
          >
            {speed(averageSpeed)}
          </StatTile>
        )}
        {meters !== undefined && (
          <StatTile
            icon={<IconArrowsMaximize size={14} aria-hidden />}
            label={t('rides.group.stats.distance')}
          >
            {distance(meters)}
          </StatTile>
        )}
        {elevationGain !== undefined && (
          <StatTile
            icon={<IconArrowUp size={14} aria-hidden />}
            label={t('rides.group.stats.elevation')}
          >
            {elevation(elevationGain)}
          </StatTile>
        )}
      </SimpleGrid>
    </Paper>
  )
}
