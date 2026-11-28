import { useTranslation } from 'react-i18next'
import { Badge as MantineBadge, Box, Group, Paper, Stack, Text, Title } from '@mantine/core'
import { IconChevronRight, IconClock, IconMapPin } from '@tabler/icons-react'
import {
  CompassPoint,
  WeatherCondition,
  WeatherStatus,
  type RideWeatherSummaryDto,
} from '@/api/dto'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { routeColor } from '@/lib/routeColors'
import { TypeBadge } from '@/components/card/common'
import { ChildFacts } from '@/components/publication/ChildCard'
import { GroupPeopleRow } from '@/components/ride/group/GroupPeopleRow'
import { RideWeatherSummaryLine } from '@/components/weather/RideWeatherSummaryLine'
import { VisualFrame } from './VisualFrame'
import { DemoDayBox } from './DemoDayBox'
import { DemoButton } from './DemoButton'

interface DemoGroup {
  nameKey: 'features.demo.ride.groupA' | 'features.demo.ride.groupB' | 'features.demo.ride.groupC'
  color: string
  time: string
  distanceM: number
  climbM: number
  speed: number
  count: number
  max: number
  temperatureMin: number
  temperatureMax: number
  wind: number
  rain: number
  state: 'open' | 'joined' | 'full'
}

// The joined group first, as on the ride page; the bar is the colour of the group's trace.
const GROUPS: DemoGroup[] = [
  {
    nameKey: 'features.demo.ride.groupB',
    color: routeColor(1),
    time: '08:15',
    distanceM: 92_000,
    climbM: 1_180,
    speed: 28,
    count: 9,
    max: 15,
    temperatureMin: 9,
    temperatureMax: 12,
    wind: 14,
    rain: 20,
    state: 'joined',
  },
  {
    nameKey: 'features.demo.ride.groupA',
    color: routeColor(0),
    time: '08:00',
    distanceM: 110_000,
    climbM: 1_520,
    speed: 31,
    count: 12,
    max: 15,
    temperatureMin: 9,
    temperatureMax: 12,
    wind: 14,
    rain: 25,
    state: 'open',
  },
  {
    nameKey: 'features.demo.ride.groupC',
    color: routeColor(2),
    time: '08:30',
    distanceM: 68_000,
    climbM: 720,
    speed: 25,
    count: 15,
    max: 15,
    temperatureMin: 10,
    temperatureMax: 12,
    wind: 12,
    rain: 20,
    state: 'full',
  },
]

function weatherOf(group: DemoGroup): RideWeatherSummaryDto {
  return {
    status: WeatherStatus.OK,
    condition: WeatherCondition.OVERCAST,
    temperatureMin: group.temperatureMin,
    temperatureMax: group.temperatureMax,
    wind: { speed: group.wind, direction: 315, compass: CompassPoint.NW },
    maxPrecipitationProbability: group.rain,
  }
}

/**
 * A ride and its groups, as on the ride page: the real group cards drawn inert — the colour of the
 * trace, the departure, the facts, the places (a count, never a face), the weather line — the
 * group you joined on top, one filled button at most per card.
 */
export function RideGroupsVisual() {
  const { t } = useTranslation()

  const renderGroup = (group: DemoGroup) => {
    const joined = group.state === 'joined'
    return (
      <Paper
        key={group.nameKey}
        withBorder
        shadow="xs"
        p="sm"
        style={
          joined
            ? {
                borderColor: 'var(--mantine-primary-color-filled)',
                boxShadow: '0 0 0 1px var(--mantine-primary-color-filled)',
              }
            : undefined
        }
      >
        <Group justify="space-between" wrap="nowrap" gap="sm">
          <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
            <Box w={4} h={20} bg={group.color} style={{ borderRadius: 2, flex: 'none' }} />
            <Group gap={2} wrap="nowrap">
              <Text fw={600} truncate>
                {t(group.nameKey)}
              </Text>
              <IconChevronRight size={16} />
            </Group>
            {joined && (
              <MantineBadge size="sm" color="primary" variant="light">
                {t('rides.detail.groups.joined')}
              </MantineBadge>
            )}
          </Group>
          {group.state === 'full' && (
            <DemoButton size="xs" variant="default" disabled>
              {t('rides.detail.groups.full')}
            </DemoButton>
          )}
        </Group>
        <Box
          mt="xs"
          px="sm"
          py={6}
          bg="light-dark(var(--mantine-color-primary-0), var(--mantine-color-dark-6))"
          style={{ borderRadius: 'var(--mantine-radius-sm)' }}
        >
          <Group gap={6} wrap="nowrap">
            <IconClock size={16} color="var(--mantine-primary-color-filled)" />
            <Text fz={14} fw={700}>
              {t('departure.block.time', { time: group.time })}
            </Text>
          </Group>
        </Box>
        <Group mt="xs" gap="md" wrap="wrap">
          <ChildFacts
            distance={group.distanceM}
            elevationGain={group.climbM}
            averageSpeed={group.speed}
          />
        </Group>
        <Box mt="xs">
          <GroupPeopleRow
            participants={[]}
            canSeeParticipants={false}
            countParticipants={group.count}
            maxParticipants={group.max}
            full={group.count === group.max}
          />
        </Box>
        <Box mt="xs">
          <RideWeatherSummaryLine summary={weatherOf(group)} timezone="Europe/Paris" />
        </Box>
        {group.state === 'open' && (
          <DemoButton fullWidth mt="xs">
            {t('rides.detail.groups.switchTo', { group: t(group.nameKey) })}
          </DemoButton>
        )}
      </Paper>
    )
  }

  return (
    <VisualFrame color={PUBLICATION_TYPE_COLORS.RIDE}>
      <Paper withBorder radius="md" p="md" bg="var(--mantine-color-body)">
        <Stack gap="sm">
          <Group gap="sm" wrap="nowrap" align="center">
            <DemoDayBox
              small
              weekday={t('features.demo.ride.weekday')}
              day={22}
              month={t('features.demo.ride.month')}
            />
            <Stack gap={4} style={{ minWidth: 0 }} align="flex-start">
              <TypeBadge type="RIDE">{t('publicationType.ride')}</TypeBadge>
              <Title order={3} size="h4">
                {t('features.demo.ride.title')}
              </Title>
              <Group gap={4} wrap="nowrap">
                <IconMapPin size={14} style={{ flex: 'none' }} />
                <Text size="sm" c="dimmed">
                  {t('features.demo.ride.place')}
                </Text>
              </Group>
            </Stack>
          </Group>
          <Text fw={700}>{t('rides.detail.groups.title')}</Text>
          <Stack gap="xs">{GROUPS.map(renderGroup)}</Stack>
        </Stack>
      </Paper>
    </VisualFrame>
  )
}
