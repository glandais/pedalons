import { useTranslation } from 'react-i18next'
import { Group, Paper, ScrollArea, Stack, Text } from '@mantine/core'
import { IconDroplet } from '@tabler/icons-react'
import type { WeatherCheckpointDto } from '@/api/dto'
import { WeatherCheckpointKind } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { WeatherIcon } from './WeatherIcon'
import { WindArrow } from './WindArrow'
import { useWeatherLabels } from './useWeatherLabels'
import { isKnownRelativeWind, relativeWindColor } from './weatherDisplay'
import classes from './WeatherCheckpointStrip.module.css'

interface WeatherCheckpointStripProps {
  checkpoints: WeatherCheckpointDto[]
  /** The ride's or stage's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
}

/**
 * The forecast points of a leg, start to finish, at their estimated passages: hour, sky,
 * temperature, chance of rain, and the wind as the rider meets it there. A point carries no
 * coordinates (docs/plans/archive/2026-10-05-weather.md §1) — only its distance along the route.
 *
 * The points hold nothing focusable, so the scrolling viewport itself is a named, focusable region:
 * without it a long route's later points were out of a keyboard user's reach.
 */
export function WeatherCheckpointStrip({ checkpoints, timezone }: WeatherCheckpointStripProps) {
  const { t } = useTranslation()

  return (
    <ScrollArea
      type="auto"
      offsetScrollbars
      classNames={{ viewport: classes.viewport }}
      viewportProps={{
        tabIndex: 0,
        role: 'region',
        'aria-label': t('rides.weather.checkpoints.label'),
      }}
    >
      <Group
        component="ol"
        gap="xs"
        wrap="nowrap"
        align="stretch"
        m={0}
        p={0}
        style={{ listStyle: 'none' }}
      >
        {checkpoints.map((checkpoint) => (
          <CheckpointCard key={checkpoint.index} checkpoint={checkpoint} timezone={timezone} />
        ))}
      </Group>
    </ScrollArea>
  )
}

function CheckpointCard({
  checkpoint,
  timezone,
}: {
  checkpoint: WeatherCheckpointDto
  timezone?: string
}) {
  const { t } = useTranslation()
  const passage = useRendezvousFormat(timezone)
  const { distance, temperature, speed } = useUnits()
  const labels = useWeatherLabels()
  const weather = checkpoint.weather

  const place =
    checkpoint.kind === WeatherCheckpointKind.START
      ? t('rides.weather.checkpoints.start')
      : checkpoint.kind === WeatherCheckpointKind.FINISH
        ? t('rides.weather.checkpoints.finish', { distance: distance(checkpoint.distance) })
        : distance(checkpoint.distance)

  const relativeWind = isKnownRelativeWind(checkpoint.relativeWind)
    ? checkpoint.relativeWind
    : undefined

  return (
    <Paper component="li" withBorder radius="md" p="xs" miw={104} style={{ flexShrink: 0 }}>
      <Stack gap={4} align="center">
        <Text size="xs" fw={600} ta="center" lineClamp={1}>
          {place}
        </Text>
        <Text size="xs" c="dimmed" suppressHydrationWarning={passage.isGuessedText}>
          {passage.formatTime(checkpoint.time)}
        </Text>
        {weather ? (
          <>
            <WeatherIcon condition={weather.condition} daylight={weather.daylight} size={28} />
            <Text size="sm" fw={700}>
              {temperature(weather.temperature)}
            </Text>
            {weather.precipitationProbability !== undefined && (
              <Group gap={2} wrap="nowrap">
                <IconDroplet
                  size={12}
                  color="var(--mantine-color-blue-text)"
                  role="img"
                  aria-label={t('rides.weather.precipitationLabel')}
                />
                <Text size="xs" c="dimmed">
                  {t('rides.weather.percent', { value: weather.precipitationProbability })}
                </Text>
              </Group>
            )}
            {relativeWind && checkpoint.relativeWindAngle !== undefined && (
              <Group gap={2} wrap="nowrap">
                <WindArrow
                  angle={checkpoint.relativeWindAngle}
                  relativeWind={relativeWind}
                  label={t('rides.weather.wind.relativeAria', {
                    relativeWind: labels.relativeWind(relativeWind),
                    speed: speed(weather.wind.speed),
                  })}
                  size={16}
                />
                <Text size="xs" c={`var(--mantine-color-${relativeWindColor(relativeWind)}-text)`}>
                  {labels.relativeWindShort(relativeWind)}
                </Text>
              </Group>
            )}
            <Text size="xs" c="dimmed" ta="center">
              {speed(weather.wind.speed)}
            </Text>
            {weather.wind.gusts !== undefined && (
              <Text size="xs" c="dimmed" ta="center">
                {t('rides.weather.wind.gustsShort', { gusts: speed(weather.wind.gusts) })}
              </Text>
            )}
          </>
        ) : (
          <Text size="xs" c="dimmed" ta="center">
            {t('rides.weather.checkpoints.noForecast')}
          </Text>
        )}
      </Stack>
    </Paper>
  )
}
