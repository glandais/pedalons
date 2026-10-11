import { useTranslation } from 'react-i18next'
import { Group, Paper, Progress, SimpleGrid, Stack, Text } from '@mantine/core'
import { IconUmbrella } from '@tabler/icons-react'
import { RelativeWind, WeatherCondition } from '@/api/dto'
import { RELATIVE_WIND_COLORS } from '@/lib/badgeColors.generated'
import { WeatherIcon } from '@/components/weather/WeatherIcon'
import { WindArrow } from '@/components/weather/WindArrow'
import { VisualFrame } from './VisualFrame'

/** Arrow angles of the legend, as `WindExposureBar` draws them: pushing, across, in the face. */
const WIND_ANGLES: Record<RelativeWind, number> = {
  [RelativeWind.TAIL]: 0,
  [RelativeWind.CROSS]: 90,
  [RelativeWind.HEAD]: 180,
}

/**
 * The forecast of a group's ride: the sky at the start, at each passing time along the route, the
 * wind as the rider meets it stretch by stretch, and the rain alert — the blocks of the ride page.
 */
export function WeatherVisual() {
  const { t } = useTranslation()
  const checkpoints = [
    { time: '08:00', condition: WeatherCondition.CLEAR, temperature: '11 °C' },
    { time: '09:10', condition: WeatherCondition.MOSTLY_CLEAR, temperature: '14 °C' },
    { time: '10:20', condition: WeatherCondition.PARTLY_CLOUDY, temperature: '17 °C' },
    { time: '11:30', condition: WeatherCondition.SHOWERS, temperature: '16 °C' },
  ]
  // Stretches in route order, as percentages of the distance.
  const stretches: { wind: RelativeWind; percent: number }[] = [
    { wind: RelativeWind.HEAD, percent: 30 },
    { wind: RelativeWind.CROSS, percent: 20 },
    { wind: RelativeWind.TAIL, percent: 35 },
    { wind: RelativeWind.CROSS, percent: 15 },
  ]
  const totals: { wind: RelativeWind; distance: string }[] = [
    { wind: RelativeWind.HEAD, distance: t('features.demo.weather.head') },
    { wind: RelativeWind.CROSS, distance: t('features.demo.weather.cross') },
    { wind: RelativeWind.TAIL, distance: t('features.demo.weather.tail') },
  ]

  return (
    <VisualFrame color="cyan">
      <Stack gap="sm">
        <Paper withBorder radius="lg" p="md">
          <Stack gap="sm">
            <Group justify="space-between" wrap="nowrap" gap="sm">
              <Stack gap={0}>
                <Text fw={700}>{t('features.demo.weather.title')}</Text>
                <Text size="sm" c="dimmed">
                  {t('rides.weather.leg.speed', { speed: t('features.demo.weather.speed') })}
                </Text>
              </Stack>
              <Group gap={6} wrap="nowrap">
                <WeatherIcon condition={WeatherCondition.CLEAR} size={28} />
                <Text size="xl" fw={700}>
                  {checkpoints[0].temperature}
                </Text>
              </Group>
            </Group>
            <SimpleGrid cols={4} spacing="xs">
              {checkpoints.map((checkpoint, index) => (
                <Stack
                  key={checkpoint.time}
                  gap={2}
                  align="center"
                  py={6}
                  style={{
                    borderRadius: 'var(--mantine-radius-md)',
                    backgroundColor: 'var(--mantine-color-default-hover)',
                  }}
                >
                  <Text size="xs" c="dimmed">
                    {index === 0
                      ? t('rides.weather.checkpoints.start')
                      : t('features.demo.weather.km', { km: index * 28 })}
                  </Text>
                  <WeatherIcon condition={checkpoint.condition} size={22} />
                  <Text size="sm" fw={600}>
                    {checkpoint.temperature}
                  </Text>
                  <Text size="xs" c="dimmed">
                    {checkpoint.time}
                  </Text>
                </Stack>
              ))}
            </SimpleGrid>
          </Stack>
        </Paper>
        <Paper withBorder radius="lg" p="md">
          <Stack gap={6}>
            <Text size="sm" fw={600}>
              {t('rides.weather.exposure.title')}
            </Text>
            <Progress.Root size={14} radius="sm">
              {stretches.map((stretch, index) => (
                <Progress.Section
                  key={index}
                  value={stretch.percent}
                  color={RELATIVE_WIND_COLORS[stretch.wind]}
                />
              ))}
            </Progress.Root>
            <Group gap="md" wrap="wrap">
              {totals.map(({ wind, distance }) => (
                <Group key={wind} gap={4} wrap="nowrap">
                  <WindArrow
                    angle={WIND_ANGLES[wind]}
                    relativeWind={wind}
                    label={t(`rides.weather.relativeWind.${wind}`)}
                    size={14}
                  />
                  <Text size="xs" c="dimmed">
                    {t('rides.weather.exposure.total', {
                      relativeWind: t(`rides.weather.relativeWindShort.${wind}`),
                      distance,
                    })}
                  </Text>
                </Group>
              ))}
            </Group>
          </Stack>
        </Paper>
        <Group
          gap={8}
          wrap="nowrap"
          px="md"
          py="xs"
          style={{
            borderRadius: 'var(--mantine-radius-lg)',
            backgroundColor: 'var(--mantine-color-body)',
            border: '1px solid var(--mantine-color-default-border)',
          }}
        >
          <IconUmbrella size={18} style={{ flex: 'none' }} />
          <Text size="sm">
            {t('rides.weather.rain.alertAt', {
              condition: t('rides.weather.condition.SHOWERS'),
              probability: 60,
              time: '11:30',
              distance: t('features.demo.weather.km', { km: 84 }),
            })}
          </Text>
        </Group>
      </Stack>
    </VisualFrame>
  )
}
