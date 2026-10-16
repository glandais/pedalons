import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Paper, SimpleGrid, Stack, Text } from '@mantine/core'
import {
  IconAlertTriangle,
  IconSunset2,
  IconTemperature,
  IconUmbrella,
  IconWind,
} from '@tabler/icons-react'
import type { DepartureWeatherDto, WeatherLegDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useWeatherLabels } from './useWeatherLabels'
import { useRouteLabels } from './useRouteLabels'
import { rainAlertCondition } from './weatherDisplay'
import {
  NIGHT_AFTER_SUNSET_MINUTES,
  daylightVerdict,
  rainVerdict,
  temperatureVerdict,
  windVerdict,
  type WindPhase,
} from './routeWeather'
import classes from './RouteWeather.module.css'

interface RouteVerdictsProps {
  leg: WeatherLegDto
  departure: DepartureWeatherDto
  phases: WindPhase[]
  timezone?: string
}

/**
 * The four answers a rider looks for before the details: how warm, wet or dry, which wind, and
 * whether the group is back before dark. Each is computed from the leg (`routeWeather.ts`); a tile
 * without data is left out, the daylight one included when the meeting point has no sunset.
 */
export function RouteVerdicts({ leg, departure, phases, timezone }: RouteVerdictsProps) {
  const { t } = useTranslation()
  const { temperature, speed } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const tiles: ReactNode[] = []

  // Temperatures
  const temperatures = temperatureVerdict(departure.conditions, leg.checkpoints)
  if (temperatures) {
    const min = temperature(temperatures.min)
    const max = temperature(temperatures.max)
    const warmest =
      temperatures.warmest !== undefined ? leg.checkpoints[temperatures.warmest] : undefined
    tiles.push(
      <VerdictTile
        key="temperature"
        icon={<IconTemperature size={16} aria-hidden />}
        label={t('rides.weather.route.verdict.temperature.label')}
        answer={
          min === max ? min : t('rides.weather.route.verdict.temperature.range', { min, max })
        }
        guessed={isGuessedText}
        sentence={[
          temperatures.start &&
            t('rides.weather.route.verdict.temperature.start', {
              temperature: temperature(temperatures.start.temperature),
              felt: temperature(temperatures.start.apparentTemperature),
            }),
          warmest &&
            t('rides.weather.route.verdict.temperature.warmest', {
              time: formatTime(warmest.time),
            }),
        ]}
      />
    )
  }

  // Rain
  const rain = rainVerdict(leg)
  if (rain.kind === 'alert') {
    const { alert } = rain
    tiles.push(
      <VerdictTile
        key="rain"
        icon={<IconUmbrella size={16} aria-hidden />}
        label={t('rides.weather.route.verdict.rain.label')}
        answer={labels.condition(rainAlertCondition(alert.condition))}
        warn
        guessed={isGuessedText}
        sentence={[
          alert.distance !== undefined
            ? t('rides.weather.route.verdict.rain.alert', {
                time: formatTime(alert.time),
                distance: route.marker(alert.distance),
                probability: alert.probability,
              })
            : t('rides.weather.route.verdict.rain.alertNoDistance', {
                time: formatTime(alert.time),
                probability: alert.probability,
              }),
        ]}
      />
    )
  } else {
    const first = rain.first !== undefined ? leg.checkpoints[rain.first] : undefined
    const last = rain.last !== undefined ? leg.checkpoints[rain.last] : undefined
    let sentence: string
    // No probability anywhere is missing data, not a dry forecast: no « Sec » for it.
    if (rain.max === undefined) sentence = t('rides.weather.route.verdict.rain.unknown')
    else if (!first || !last) sentence = t('rides.weather.route.verdict.rain.none')
    else if (first === last)
      sentence = t('rides.weather.route.verdict.rain.peak', {
        probability: rain.max,
        time: formatTime(first.time),
        distance: route.marker(first.distance),
      })
    else
      sentence = t('rides.weather.route.verdict.rain.window', {
        probability: rain.max,
        from: formatTime(first.time),
        to: formatTime(last.time),
        fromDistance: route.marker(first.distance),
        toDistance: route.marker(last.distance),
      })
    tiles.push(
      <VerdictTile
        key="rain"
        icon={<IconUmbrella size={16} aria-hidden />}
        label={t('rides.weather.route.verdict.rain.label')}
        answer={
          rain.max === undefined
            ? t('rides.weather.route.timeline.empty')
            : t('rides.weather.route.verdict.rain.dry')
        }
        guessed={isGuessedText}
        sentence={[sentence]}
      />
    )
  }

  // Wind
  const wind = windVerdict(leg, phases)
  if (wind) {
    const first = wind.firstHalf ?? wind.secondHalf!
    const second = wind.secondHalf ?? first
    const answer =
      first === second
        ? t(`rides.weather.route.verdict.wind.mostly.${first}`)
        : t('rides.weather.route.verdict.wind.then', {
            first: labels.relativeWindShort(first),
            second: t(`rides.weather.route.verdict.wind.lower.${second}`),
          })
    const sentence: (string | undefined)[] = [
      leg.prevailingWind &&
        t('rides.weather.route.verdict.wind.prevailing', { wind: labels.wind(leg.prevailingWind) }),
    ]
    if (wind.sequential && wind.head && wind.tail) {
      sentence.push(
        wind.head.gusts !== undefined
          ? t('rides.weather.route.verdict.wind.headUntilGusts', {
              distance: route.marker(wind.head.until),
              gusts: speed(wind.head.gusts),
            })
          : t('rides.weather.route.verdict.wind.headUntil', {
              distance: route.marker(wind.head.until),
            }),
        t('rides.weather.route.verdict.wind.tailAfter', { distance: route.marker(wind.tail.from) })
      )
    } else {
      if (wind.head)
        sentence.push(
          t('rides.weather.route.verdict.wind.headOver', {
            distance: route.length(wind.head.distance),
          })
        )
      if (wind.tail)
        sentence.push(
          t('rides.weather.route.verdict.wind.tailOver', {
            distance: route.length(wind.tail.distance),
          })
        )
    }
    tiles.push(
      <VerdictTile
        key="wind"
        icon={<IconWind size={16} aria-hidden />}
        label={t('rides.weather.route.verdict.wind.label')}
        answer={answer}
        sentence={sentence}
      />
    )
  }

  // Daylight
  const day = daylightVerdict(leg.startTime, leg.arrivalTime, departure.sunrise, departure.sunset)
  if (day && departure.sunset) {
    const answer =
      day.marginMinutes >= 0
        ? t('rides.weather.route.verdict.day.margin', {
            duration: route.duration(day.marginMinutes),
          })
        : day.marginMinutes > -NIGHT_AFTER_SUNSET_MINUTES
          ? t('rides.weather.route.verdict.day.afterSunset', {
              duration: route.duration(day.marginMinutes),
            })
          : t('rides.weather.route.verdict.day.night')
    tiles.push(
      <VerdictTile
        key="day"
        icon={<IconSunset2 size={16} aria-hidden />}
        label={t('rides.weather.route.verdict.day.label')}
        answer={answer}
        warn={day.marginMinutes < 0}
        guessed={isGuessedText}
        sentence={[
          departure.sunrise
            ? t('rides.weather.route.verdict.day.sun', {
                sunrise: formatTime(departure.sunrise),
                sunset: formatTime(departure.sunset),
              })
            : t('rides.weather.route.verdict.day.sunset', { sunset: formatTime(departure.sunset) }),
          t('rides.weather.route.verdict.day.arrival', { time: formatTime(leg.arrivalTime) }),
          day.startsBeforeSunrise && t('rides.weather.route.verdict.day.beforeSunrise'),
        ]}
      />
    )
  }

  if (tiles.length === 0) return null
  return (
    <SimpleGrid
      cols={{ base: 2, md: 4 }}
      spacing={{ base: 'xs', sm: 'md' }}
      role="list"
      aria-label={t('rides.weather.route.verdicts.label')}
    >
      {tiles}
    </SimpleGrid>
  )
}

function VerdictTile({
  icon,
  label,
  answer,
  sentence,
  warn = false,
  guessed = false,
}: {
  icon: ReactNode
  label: string
  answer: string
  /** Sentences, joined by a space; empty ones dropped. */
  sentence: (string | false | undefined | null | '')[]
  /** Something to watch: a warning sign before the answer, whose words say why. The answer
   * itself keeps the text colour — the warning yellow is 1.8:1 on white. */
  warn?: boolean
  /** The sentence carries passages that may differ between the server and the browser. */
  guessed?: boolean
}) {
  return (
    <Paper withBorder radius="md" p={{ base: 'sm', sm: 'md' }} role="listitem">
      <Stack gap={6}>
        {/* Not dimmed: at 12px it would fall under 4.5:1 in both schemes (docs/LEDGER_*.md WEB-2) */}
        <Group gap={6} wrap="nowrap">
          {icon}
          <Text size="xs" fw={700} tt="uppercase">
            {label}
          </Text>
        </Group>
        <Group gap={6} wrap="nowrap" align="flex-start">
          {warn && <IconAlertTriangle size={20} aria-hidden className={classes.warnIcon} />}
          <Text fz={{ base: 'md', sm: 'xl' }} fw={700} lh={1.2}>
            {answer}
          </Text>
        </Group>
        <Text size="sm" suppressHydrationWarning={guessed}>
          {sentence.filter(Boolean).join(' ')}
        </Text>
      </Stack>
    </Paper>
  )
}
