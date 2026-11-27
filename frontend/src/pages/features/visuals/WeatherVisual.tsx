import { useTranslation } from 'react-i18next'
import { Box, Group, Paper, Stack, Text } from '@mantine/core'
import { IconUmbrella } from '@tabler/icons-react'
import { RelativeWind } from '@/api/dto'
import { RELATIVE_WIND_COLORS } from '@/lib/badgeColors.generated'
import { VisualFrame } from './VisualFrame'
import { MapBackdrop, Pin } from './MapBackdrop'

const wind = (w: RelativeWind) => `var(--mantine-color-${RELATIVE_WIND_COLORS[w]}-filled)`

/**
 * A group's ride on the map in « weather » mode: the track coloured by the wind the rider meets
 * (tail, across, head — the colours of the real map), the temperatures along it, the legend in
 * words with the distance of each, and the rain alert.
 */
export function WeatherVisual() {
  const { t } = useTranslation()
  const legend = [
    { wind: RelativeWind.TAIL, label: t('features.demo.weather.tail') },
    { wind: RelativeWind.CROSS, label: t('features.demo.weather.cross') },
    { wind: RelativeWind.HEAD, label: t('features.demo.weather.head') },
  ]
  const temperatures = [
    { x: 196, y: 96, label: t('features.demo.weather.temperature1') },
    { x: 380, y: 182, label: t('features.demo.weather.temperature2') },
  ]

  return (
    <VisualFrame color="cyan">
      <Paper withBorder radius="lg" style={{ overflow: 'hidden' }}>
        <Box pos="relative" h={240}>
          <svg
            viewBox="0 0 520 240"
            preserveAspectRatio="xMidYMid slice"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
          >
            <MapBackdrop width={520} height={240} />
            <path
              d="M0 70 C140 90 300 40 520 80"
              stroke="var(--mantine-color-body)"
              strokeWidth={5}
              fill="none"
            />
            <path
              d="M120 0 L170 240"
              stroke="var(--mantine-color-body)"
              strokeWidth={4}
              fill="none"
            />
            <path
              d="M360 0 C370 90 400 160 430 240"
              stroke="var(--mantine-color-body)"
              strokeWidth={3}
              fill="none"
            />
            <path
              d="M90 180 C120 110 200 70 280 70 C360 70 430 100 440 150 C450 200 370 210 300 200 C230 190 160 215 90 180 Z"
              stroke="var(--mantine-color-body)"
              strokeWidth={9}
              fill="none"
            />
            <path
              d="M90 180 C120 110 200 70 280 70"
              stroke={wind(RelativeWind.TAIL)}
              strokeWidth={5}
              fill="none"
            />
            <path
              d="M280 70 C360 70 430 100 440 150"
              stroke={wind(RelativeWind.CROSS)}
              strokeWidth={5}
              fill="none"
            />
            <path
              d="M440 150 C450 200 370 210 300 200 C230 190 160 215 90 180"
              stroke={wind(RelativeWind.HEAD)}
              strokeWidth={5}
              fill="none"
            />
            <Pin x={90} y={180} />
            {temperatures.map((temperature) => (
              <g key={temperature.label}>
                <rect
                  x={temperature.x}
                  y={temperature.y}
                  width={62}
                  height={26}
                  rx={13}
                  fill="var(--mantine-color-body)"
                />
                <text
                  x={temperature.x + 31}
                  y={temperature.y + 17}
                  textAnchor="middle"
                  fontSize={12}
                  fontWeight={600}
                  fill="var(--mantine-color-text)"
                >
                  {temperature.label}
                </text>
              </g>
            ))}
          </svg>
          <Text
            pos="absolute"
            left={12}
            top={12}
            size="sm"
            fw={600}
            px="xs"
            py={6}
            bg="var(--mantine-color-body)"
            style={{ borderRadius: 'var(--mantine-radius-md)' }}
          >
            {t('features.demo.weather.title')}
          </Text>
        </Box>
        <Stack gap="sm" p="md">
          <Group gap="xs">
            {legend.map(({ wind: w, label }) => (
              <Group
                key={w}
                gap={6}
                wrap="nowrap"
                px="xs"
                h={26}
                bg={`var(--mantine-color-${RELATIVE_WIND_COLORS[w]}-light)`}
                style={{ borderRadius: 1000 }}
              >
                <Box w={12} h={4} style={{ borderRadius: 2, backgroundColor: wind(w) }} />
                <Text
                  size="xs"
                  fw={600}
                  c={`var(--mantine-color-${RELATIVE_WIND_COLORS[w]}-light-color)`}
                >
                  {label}
                </Text>
              </Group>
            ))}
          </Group>
          <Group
            gap="xs"
            wrap="nowrap"
            px="sm"
            py="xs"
            bg="var(--mantine-color-yellow-light)"
            c="var(--mantine-color-yellow-light-color)"
            style={{ borderRadius: 'var(--mantine-radius-md)' }}
          >
            <IconUmbrella size={18} style={{ flex: 'none' }} />
            <Text size="sm">{t('features.demo.weather.rain')}</Text>
          </Group>
        </Stack>
      </Paper>
    </VisualFrame>
  )
}
