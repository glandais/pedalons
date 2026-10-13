import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { IconArrowsMaximize, IconArrowUp, IconBolt, IconClock } from '@tabler/icons-react'
import { Group, Paper, SimpleGrid, Stack, Text } from '@mantine/core'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { Rendezvous } from '@/components/common/Rendezvous'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useUnits } from '@/hooks/useUnits'
import { groupStartRelation } from '@/utils/groupStart'

/** One figure of the group: its label above, its value, an optional line below. */
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
      <Text fw={700} size="lg">
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

/**
 * Departure, pace, distance and climb — each one only when the group has it. On a group's page
 * (WEB-77) and on a solo ride's (WEB-79).
 */
export function GroupStats({
  ride,
  group,
  arrival,
}: {
  ride: RideDto
  group: RideGroupDto
  /** The estimated arrival of the group's leg, when the forecast gives one. */
  arrival: string | undefined
}) {
  const { t } = useTranslation()
  const { speed, distance, elevation } = useUnits()
  const rendezvous = useRendezvousFormat(ride.timezone)
  const relation = groupStartRelation(group.startAt, ride.dateTime)

  return (
    <Paper withBorder p="lg" data-testid="group-stats">
      <SimpleGrid cols={{ base: 2, sm: 4 }} spacing="md">
        {group.startAt && (
          <StatTile
            icon={<IconClock size={14} aria-hidden />}
            label={t('rides.group.stats.departure')}
            hint={t(`rides.group.stats.${relation}`)}
          >
            <Rendezvous date={group.startAt} zone={ride.timezone} format="time" />
          </StatTile>
        )}
        {group.averageSpeed && (
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
            {speed(group.averageSpeed)}
          </StatTile>
        )}
        {group.distance !== undefined && (
          <StatTile
            icon={<IconArrowsMaximize size={14} aria-hidden />}
            label={t('rides.group.stats.distance')}
          >
            {distance(group.distance)}
          </StatTile>
        )}
        {group.elevationGain !== undefined && (
          <StatTile
            icon={<IconArrowUp size={14} aria-hidden />}
            label={t('rides.group.stats.elevation')}
          >
            {elevation(group.elevationGain)}
          </StatTile>
        )}
      </SimpleGrid>
    </Paper>
  )
}
