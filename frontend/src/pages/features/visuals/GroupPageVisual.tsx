import { useTranslation } from 'react-i18next'
import { ActionIcon, Box, Group, Paper, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import {
  IconArrowUp,
  IconArrowsMaximize,
  IconBolt,
  IconChevronLeft,
  IconChevronRight,
  IconGps,
  IconMapPin,
  IconUsers,
  type TablerIcon,
} from '@tabler/icons-react'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { routeColor } from '@/lib/routeColors'
import { useUnits } from '@/hooks/useUnits'
import { VisualFrame } from './VisualFrame'
import { DemoDayBox } from './DemoDayBox'
import { DemoButton } from './DemoButton'
import { FakeSegments } from './FakeControls'
import { MAP_CASING, MAP_CLASS, MAP_ROAD, MapBackdrop, Pin } from './MapBackdrop'

const TRACE =
  'M70 105 C60 60 120 30 190 32 C260 34 320 60 300 95 C285 120 200 118 150 115 C110 112 80 118 70 105'

/**
 * The page of one group (`RideGroupPage`), drawn inert for the group the ride's cards offer to
 * join: the switcher between sibling groups, the departure, the facts, the trace on the map and
 * the number of people signed up — a count, never a name or a face.
 */
export function GroupPageVisual() {
  const { t } = useTranslation()
  const { distance, elevation, speed } = useUnits()

  const stats: { icon: TablerIcon; label: string; value: string; hint?: string }[] = [
    {
      icon: IconArrowsMaximize,
      label: t('rides.group.stats.distance'),
      value: distance(110_000),
    },
    { icon: IconArrowUp, label: t('rides.group.stats.elevation'), value: elevation(1_520) },
    {
      icon: IconBolt,
      label: t('rides.group.stats.pace'),
      value: speed(31),
      hint: t('rides.group.stats.arrival', { time: '11:35' }),
    },
  ]
  const option = (
    key: 'features.demo.ride.groupA' | 'features.demo.ride.groupB' | 'features.demo.ride.groupC',
    current: number
  ) => t('rides.group.option', { name: t(key), current, max: 15 })

  return (
    <VisualFrame color={PUBLICATION_TYPE_COLORS.RIDE}>
      <Paper withBorder radius="md" p="md" bg="var(--mantine-color-body)">
        <Stack gap="sm">
          <Group gap="xs" wrap="nowrap">
            <ActionIcon component="span" variant="default" size="lg" disabled>
              <IconChevronLeft size={18} />
            </ActionIcon>
            <Box style={{ flex: 1, minWidth: 0 }}>
              <FakeSegments
                active={0}
                items={[
                  option('features.demo.ride.groupA', 12),
                  option('features.demo.ride.groupB', 9),
                  option('features.demo.ride.groupC', 15),
                ]}
              />
            </Box>
            <ActionIcon component="span" variant="default" size="lg">
              <IconChevronRight size={18} />
            </ActionIcon>
          </Group>

          <Group justify="space-between" align="flex-end" gap="xs" wrap="wrap">
            <Stack gap={2}>
              <Text size="xs" c="dimmed">
                {t('features.demo.ride.title')}
              </Text>
              <Title order={3}>{t('features.demo.ride.groupA')}</Title>
            </Stack>
            <Group gap={6}>
              <DemoButton size="xs">
                {t('rides.detail.groups.switchTo', { group: t('features.demo.ride.groupA') })}
              </DemoButton>
              <DemoButton size="xs" variant="default" leftSection={<IconGps size={14} />}>
                {t('routes.gps.button')}
              </DemoButton>
            </Group>
          </Group>

          <Group
            gap="md"
            wrap="nowrap"
            p="sm"
            bg="light-dark(var(--mantine-color-gray-0), var(--mantine-color-dark-6))"
            style={{
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-md)',
            }}
          >
            <DemoDayBox
              small
              weekday={t('features.demo.ride.weekday')}
              day={22}
              month={t('features.demo.ride.month')}
            />
            <Stack gap={4}>
              <Text fz={18} fw={700}>
                {t('departure.block.time', { time: '08:00' })}
              </Text>
              <Group gap={6} wrap="nowrap">
                <IconMapPin size={16} color="var(--mantine-color-green-text)" />
                <Text size="sm">{t('features.demo.ride.place')}</Text>
              </Group>
            </Stack>
          </Group>

          <Paper withBorder p="sm" radius="md">
            <SimpleGrid cols={3} spacing="sm">
              {stats.map(({ icon: Icon, label, value, hint }) => (
                <Stack key={label} gap={2}>
                  <Group gap={4} wrap="nowrap" c="dimmed">
                    <Icon size={14} style={{ flex: 'none' }} />
                    <Text size="xs" tt="uppercase" fw={600} c="dimmed">
                      {label}
                    </Text>
                  </Group>
                  <Text fw={700} size="md" style={{ whiteSpace: 'nowrap' }}>
                    {value}
                  </Text>
                  {hint && (
                    <Text size="xs" c="dimmed">
                      {hint}
                    </Text>
                  )}
                </Stack>
              ))}
            </SimpleGrid>
          </Paper>

          <Box
            pos="relative"
            h={140}
            style={{
              overflow: 'hidden',
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-md)',
            }}
          >
            <svg
              className={MAP_CLASS}
              viewBox="0 0 368 140"
              preserveAspectRatio="xMidYMid slice"
              style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
            >
              <MapBackdrop width={368} height={140} />
              <g stroke={MAP_ROAD} fill="none" strokeLinecap="round">
                <path d="M30 0 L90 140" strokeWidth={3} />
                <path d="M0 60 C120 70 240 40 368 66" strokeWidth={3} />
              </g>
              <g fill="none" strokeLinecap="round" strokeLinejoin="round">
                <path d={TRACE} stroke={MAP_CASING} strokeWidth={8} />
                <path d={TRACE} stroke={routeColor(0)} strokeWidth={4} />
              </g>
              <Pin x={70} y={105} />
            </svg>
          </Box>

          <Group justify="space-between" wrap="nowrap">
            <Text fw={700}>{t('rides.group.participantsTitle')}</Text>
            <Group gap={4} wrap="nowrap" c="dimmed">
              <IconUsers size={16} />
              <Text size="sm" c="dimmed">
                {t('rides.detail.groups.participants', { current: 12, count: 15 })}
              </Text>
            </Group>
          </Group>
        </Stack>
      </Paper>
    </VisualFrame>
  )
}
