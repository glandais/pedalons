import { useTranslation } from 'react-i18next'
import { Box, Group, Paper, SimpleGrid, Stack, Text } from '@mantine/core'
import {
  IconArrowUp,
  IconSunset2,
  IconTemperature,
  IconUmbrella,
  IconWind,
  type TablerIcon,
} from '@tabler/icons-react'
import { RelativeWind } from '@/api/dto'
import { RELATIVE_WIND_COLORS } from '@/lib/badgeColors.generated'
import { useUnits } from '@/hooks/useUnits'
import { useRouteLabels } from '@/components/weather/useRouteLabels'
import { WindArrow } from '@/components/weather/WindArrow'
import { WeatherIcon } from '@/components/weather/WeatherIcon'
import { VisualFrame } from './VisualFrame'
import { MAP_CASING, MAP_CLASS, MAP_ROAD, MapBackdrop, Pin } from './MapBackdrop'

const fam = (w: RelativeWind) => RELATIVE_WIND_COLORS[w]
const filled = (w: RelativeWind) => `var(--mantine-color-${fam(w)}-filled)`
/** Where the wind blows towards, relative to the direction of travel (the legend of the real bar). */
const ANGLE: Record<RelativeWind, number> = {
  [RelativeWind.TAIL]: 0,
  [RelativeWind.CROSS]: 90,
  [RelativeWind.HEAD]: 180,
}

const TOTALS = [
  { wind: RelativeWind.TAIL, km: 34 },
  { wind: RelativeWind.CROSS, km: 30 },
  { wind: RelativeWind.HEAD, km: 28 },
]
const BAND = [
  { wind: RelativeWind.TAIL, from: 0, to: 34 },
  { wind: RelativeWind.CROSS, from: 34, to: 64 },
  { wind: RelativeWind.HEAD, from: 64, to: 92 },
]
const HOURS = [
  { time: '08:15', temp: 9, wind: RelativeWind.TAIL, rain: 10, km: 0 },
  { time: '08:50', temp: 10, wind: RelativeWind.TAIL, rain: 15, km: 17 },
  { time: '09:25', temp: 10, wind: RelativeWind.CROSS, rain: 25, km: 34 },
  { time: '10:00', temp: 11, wind: RelativeWind.CROSS, rain: 40, km: 50 },
  { time: '10:40', temp: 12, wind: RelativeWind.HEAD, rain: 55, km: 64 },
  { time: '11:15', temp: 12, wind: RelativeWind.HEAD, rain: 35, km: 80 },
]
const BADGES = [
  { left: '37.5%', top: '11%', condition: 'OVERCAST', temp: 10 },
  { left: '75%', top: '44%', condition: 'OVERCAST', temp: 11 },
  { left: '45%', top: '85%', condition: 'SHOWERS', temp: 12 },
]

/**
 * The group page's weather in miniature: the map coloured by the wind met, the totals, the four
 * verdicts, the hour-by-hour passages (what `RideGroupPage` shows, in fictional figures).
 */
export function WeatherVisual() {
  const { t } = useTranslation()
  const { temperature, speed, percent } = useUnits()
  const { marker, length, range, duration } = useRouteLabels()

  const verdicts: { icon: TablerIcon; label: string; answer: string; sentence: string }[] = [
    {
      icon: IconTemperature,
      label: t('rides.weather.route.verdict.temperature.label'),
      answer: t('rides.weather.route.verdict.temperature.range', {
        min: temperature(9),
        max: temperature(12),
      }),
      sentence: t('rides.weather.route.verdict.temperature.start', {
        temperature: temperature(9),
        felt: temperature(7),
      }),
    },
    {
      icon: IconUmbrella,
      label: t('rides.weather.route.verdict.rain.label'),
      answer: t('rides.weather.condition.SHOWERS'),
      sentence: t('rides.weather.route.verdict.rain.alert', {
        time: '10:40',
        distance: marker(64_000),
        probability: 55,
      }),
    },
    {
      icon: IconWind,
      label: t('rides.weather.route.verdict.wind.label'),
      answer: t('rides.weather.route.verdict.wind.then', {
        first: t('rides.weather.relativeWindShort.TAIL'),
        second: t('rides.weather.route.verdict.wind.lower.HEAD'),
      }),
      sentence: t('rides.weather.route.verdict.wind.headOver', { distance: length(28_000) }),
    },
    {
      icon: IconSunset2,
      label: t('rides.weather.route.verdict.day.label'),
      answer: t('rides.weather.route.verdict.day.margin', { duration: duration(350) }),
      sentence: t('rides.weather.route.verdict.day.arrival', { time: '11:35' }),
    },
  ]

  return (
    <VisualFrame color="cyan">
      <Paper withBorder radius="lg" style={{ overflow: 'hidden' }}>
        <Box pos="relative" h={210}>
          <svg
            className={MAP_CLASS}
            viewBox="0 0 400 210"
            preserveAspectRatio="xMidYMid slice"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
          >
            <MapBackdrop width={400} height={210} />
            <g stroke={MAP_ROAD} fill="none" strokeLinecap="round">
              <path d="M40 0 L110 210" strokeWidth={3} />
              <path d="M0 70 C140 80 260 50 400 80" strokeWidth={3} />
              <path d="M290 0 C300 80 330 150 360 210" strokeWidth={2} />
            </g>
            <path
              d="M80 150 C70 100 110 50 190 45 C230 43 260 48 290 60 C340 80 350 120 330 145 C300 175 220 170 160 168 C120 166 90 165 80 150"
              fill="none"
              stroke={MAP_CASING}
              strokeWidth={10}
              strokeLinejoin="round"
            />
            <g fill="none" strokeWidth={6} strokeLinecap="round" strokeLinejoin="round">
              <path
                d="M80 150 C70 100 110 50 190 45 C230 43 260 48 290 60"
                stroke={filled(RelativeWind.TAIL)}
              />
              <path d="M290 60 C340 80 350 120 330 145" stroke={filled(RelativeWind.CROSS)} />
              <path
                d="M330 145 C300 175 220 170 160 168 C120 166 90 165 80 150"
                stroke={filled(RelativeWind.HEAD)}
              />
            </g>
            <Pin x={80} y={150} />
          </svg>
          <Text
            size="xs"
            fw={600}
            px={8}
            py={4}
            pos="absolute"
            left={12}
            top={12}
            bg="color-mix(in srgb, var(--mantine-color-body) 92%, transparent)"
            style={{
              borderRadius: 'var(--mantine-radius-md)',
              border: '1px solid var(--mantine-color-default-border)',
            }}
          >
            {t('features.demo.weather.title')}
          </Text>
          {BADGES.map((badge) => (
            <Group
              key={badge.left}
              gap={4}
              wrap="nowrap"
              px={7}
              py={2}
              pos="absolute"
              left={badge.left}
              top={badge.top}
              bg="var(--mantine-color-dark-7)"
              c="white"
              style={{ borderRadius: 1000 }}
            >
              <WeatherIcon condition={badge.condition} size={12} />
              <Text fz={11} fw={700} c="white">
                {temperature(badge.temp)}
              </Text>
              <IconArrowUp size={12} stroke={2.5} style={{ transform: 'rotate(135deg)' }} />
            </Group>
          ))}
        </Box>

        <Stack gap="sm" p="sm">
          <Group gap={6}>
            {TOTALS.map(({ wind, km }) => (
              <Group
                key={wind}
                gap={4}
                wrap="nowrap"
                px={8}
                h={24}
                bg={`var(--mantine-color-${fam(wind)}-light)`}
                c={`var(--mantine-color-${fam(wind)}-light-color)`}
                style={{ borderRadius: 1000 }}
              >
                <IconArrowUp
                  size={12}
                  stroke={2.5}
                  style={{ transform: `rotate(${ANGLE[wind]}deg)` }}
                />
                <Text size="xs" fw={600} c="inherit">
                  {t('rides.weather.exposure.total', {
                    relativeWind: t(`rides.weather.relativeWindShort.${wind}`),
                    distance: length(km * 1000),
                  })}
                </Text>
              </Group>
            ))}
          </Group>

          <SimpleGrid cols={2} spacing="xs">
            {verdicts.map(({ icon: Icon, label, answer, sentence }) => (
              <Paper key={label} withBorder radius="md" p="xs">
                <Stack gap={2}>
                  <Group gap={6} wrap="nowrap">
                    <Icon size={14} style={{ flex: 'none' }} />
                    <Text size="xs" fw={700} tt="uppercase">
                      {label}
                    </Text>
                  </Group>
                  <Text fw={700} size="md" lh={1.2}>
                    {answer}
                  </Text>
                  <Text size="xs" c="dimmed">
                    {sentence}
                  </Text>
                </Stack>
              </Paper>
            ))}
          </SimpleGrid>

          <Stack gap={2}>
            <Text fw={700}>{t('rides.weather.route.timeline.title')}</Text>
            <Text size="xs" c="dimmed">
              {t('rides.weather.route.timeline.speed', { speed: speed(28) })}
            </Text>
          </Stack>

          <Group gap={2} wrap="nowrap" h={36}>
            {BAND.map(({ wind, from, to }, index) => (
              <Box
                key={wind}
                px={6}
                py={3}
                bg={`var(--mantine-color-${fam(wind)}-light)`}
                c={`var(--mantine-color-${fam(wind)}-light-color)`}
                style={{
                  flex: `${to - from} 1 0`,
                  minWidth: 0,
                  borderRadius: 'var(--mantine-radius-xs)',
                  ...(index === 0 && {
                    borderTopLeftRadius: 'var(--mantine-radius-sm)',
                    borderBottomLeftRadius: 'var(--mantine-radius-sm)',
                  }),
                  ...(index === BAND.length - 1 && {
                    borderTopRightRadius: 'var(--mantine-radius-sm)',
                    borderBottomRightRadius: 'var(--mantine-radius-sm)',
                  }),
                }}
              >
                <Group gap={4} wrap="nowrap">
                  <IconArrowUp
                    size={12}
                    style={{ flex: 'none', transform: `rotate(${ANGLE[wind]}deg)` }}
                  />
                  <Text size="xs" fw={700} c="inherit" truncate>
                    {t(`rides.weather.relativeWindShort.${wind}`)}
                  </Text>
                </Group>
                <Text fz={10} c="inherit" truncate>
                  {range(from * 1000, to * 1000)}
                </Text>
              </Box>
            ))}
          </Group>

          <SimpleGrid cols={6} spacing={4}>
            {HOURS.map((hour, index) => (
              <Stack
                key={hour.time}
                gap={4}
                align="center"
                py={6}
                bg={index === 0 ? 'var(--mantine-primary-color-light)' : undefined}
                style={{
                  borderRadius: 'var(--mantine-radius-md)',
                  border: `1px solid ${
                    index === 0
                      ? 'var(--mantine-primary-color-filled)'
                      : 'var(--mantine-color-default-border)'
                  }`,
                }}
              >
                <Text size="xs" fw={700}>
                  {hour.time}
                </Text>
                <Text size="sm" fw={600}>
                  {temperature(hour.temp)}
                </Text>
                <WindArrow
                  angle={ANGLE[hour.wind]}
                  relativeWind={hour.wind}
                  label={t(`rides.weather.relativeWind.${hour.wind}`)}
                  size={14}
                />
                <Text fz={11} c="dimmed">
                  {percent(hour.rain)}
                </Text>
                <Text fz={11} c="dimmed">
                  {marker(hour.km * 1000)}
                </Text>
              </Stack>
            ))}
          </SimpleGrid>
        </Stack>
      </Paper>
    </VisualFrame>
  )
}
