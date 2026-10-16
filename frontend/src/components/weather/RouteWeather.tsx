import { useCallback, useId, useMemo, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import type { TFunction } from 'i18next'
import {
  Box,
  Collapse,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  Title,
  UnstyledButton,
  VisuallyHidden,
} from '@mantine/core'
import { IconChevronDown } from '@tabler/icons-react'
import type {
  DepartureWeatherDto,
  WeatherCheckpointDto,
  WeatherLegDto,
  WindExposureDto,
} from '@/api/dto'
import { RelativeWind } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { RouteVerdicts } from './RouteVerdicts'
import { WeatherIcon } from './WeatherIcon'
import { WindArrow } from './WindArrow'
import { useRouteLabels } from './useRouteLabels'
import { useWeatherLabels } from './useWeatherLabels'
import { isKnownRelativeWind, relativeWindColor } from './weatherDisplay'
import {
  RELATIVE_WIND_ANGLE,
  checkpointSpacing,
  phaseAnchor,
  phaseColumns,
  phaseOfCheckpoint,
  phaseStats,
  temperaturePolylines,
  tickPositions,
  windPhases,
  type WindPhase,
} from './routeWeather'
import classes from './RouteWeather.module.css'

interface RouteWeatherProps {
  /** The group's leg, with a forecast and at least one checkpoint. */
  leg: WeatherLegDto
  /** The meeting point at departure: its temperature, sunrise and sunset feed the verdicts. */
  departure: DepartureWeatherDto
  /** The ride's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
}

/** The colour variables of a relative wind's generated family (contracts/brand-colors.yaml). */
function windStyle(relativeWind: string | undefined): CSSProperties {
  const family = relativeWindColor(relativeWind)
  return {
    '--wind-filled': `var(--mantine-color-${family}-filled)`,
    '--wind-light': `var(--mantine-color-${family}-light)`,
  } as CSSProperties
}

const LEGEND_ORDER: RelativeWind[] = [RelativeWind.HEAD, RelativeWind.CROSS, RelativeWind.TAIL]

/** « 09:00–10:00 », or one time when the phase opens and closes at the same point. */
function phaseTimes(
  t: TFunction,
  formatTime: (instant: string) => string,
  phase: WindPhase,
  checkpoints: WeatherCheckpointDto[]
): string {
  const from = formatTime(checkpoints[phase.firstCheckpoint].time)
  if (phase.firstCheckpoint === phase.lastCheckpoint) return from
  return t('rides.weather.route.phases.times', {
    from,
    to: formatTime(checkpoints[phase.lastCheckpoint].time),
  })
}

/**
 * The selected point, and the phase it was picked from: a phase shorter than the spacing of the
 * points has none of its own and selects a neighbour's, so the phase is kept rather than looked up
 * from the point. `fromSlider`: the slider's own value text already speaks the point.
 */
interface Selection {
  position: number
  phase?: number
  fromSlider?: boolean
}

/**
 * A group's route, full width on its page: four verdicts, the wind phase by phase, then every
 * forecast point at its passage — a scrolling table on a wide screen, a strip with a slider and the
 * phases as a list on a phone. Both layouts are in the markup and switched by CSS (`visibleFrom` /
 * `hiddenFrom`), so the server and the browser render the same tree. One point is selected at a
 * time, shared by the table, the slider, the phases and the detail panel.
 */
export function RouteWeather({ leg, departure, timezone }: RouteWeatherProps) {
  const { t } = useTranslation()
  const { speed } = useUnits()
  const route = useRouteLabels()
  const checkpoints = leg.checkpoints
  const phases = useMemo(() => windPhases(leg.segments, checkpoints), [leg.segments, checkpoints])
  const [selection, setSelection] = useState<Selection>({ position: 0 })
  const current = Math.min(selection.position, checkpoints.length - 1)
  const currentPhase =
    selection.phase !== undefined && selection.phase < phases.length
      ? selection.phase
      : phaseOfCheckpoint(phases, current)
  const selectPoint = useCallback((position: number) => setSelection({ position }), [])
  const selectWithSlider = useCallback(
    (position: number) => setSelection({ position, fromSlider: true }),
    []
  )
  const selectPhase = useCallback(
    (index: number) => setSelection({ position: phaseAnchor(phases[index]), phase: index }),
    [phases]
  )
  const spacing = checkpointSpacing(checkpoints)

  const speedLine = leg.speedIsDefault
    ? t('rides.weather.route.timeline.speedDefault', { speed: speed(leg.averageSpeed) })
    : t('rides.weather.route.timeline.speed', { speed: speed(leg.averageSpeed) })

  return (
    <Stack gap="xl">
      <RouteVerdicts leg={leg} departure={departure} phases={phases} timezone={timezone} />

      <Stack gap="sm">
        <Stack gap={2}>
          <Title order={4} size="h5">
            {t('rides.weather.route.timeline.title')}
          </Title>
          <Text size="sm">
            {spacing
              ? [
                  speedLine,
                  t('rides.weather.route.timeline.spacing', { distance: route.length(spacing) }),
                ].join(' · ')
              : speedLine}
          </Text>
          {/* On a phone the totals head the « Par tronçon » list instead */}
          {phases.length > 0 && (
            <Box visibleFrom="sm" mt={4}>
              <WindTotals exposure={leg.windExposure} />
            </Box>
          )}
        </Stack>

        <Box visibleFrom="sm">
          <DesktopTimeline
            checkpoints={checkpoints}
            timezone={timezone}
            selected={current}
            onSelect={selectPoint}
            phases={phases}
            selectedPhase={currentPhase}
            onSelectPhase={selectPhase}
          />
        </Box>
        <Box hiddenFrom="sm">
          <PhoneStrip
            checkpoints={checkpoints}
            timezone={timezone}
            selected={current}
            onSelect={selectWithSlider}
          />
        </Box>

        <CheckpointDetail
          checkpoint={checkpoints[current]}
          phase={currentPhase === undefined ? undefined : phases[currentPhase]}
          timezone={timezone}
          announce={!selection.fromSlider}
        />
      </Stack>

      {phases.length > 0 && (
        <Box hiddenFrom="sm">
          <PhaseList
            phases={phases}
            checkpoints={checkpoints}
            exposure={leg.windExposure}
            timezone={timezone}
            onSelect={selectPhase}
          />
        </Box>
      )}
    </Stack>
  )
}

/** « 15 °C, Partiellement nuageux, pluie 13 %, Vent dans le dos, 13 km/h » — a point, spoken. */
function useCheckpointSummary(timezone: string | undefined) {
  const { t } = useTranslation()
  const { temperature, speed } = useUnits()
  const { formatTime } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()

  return useCallback(
    (checkpoint: WeatherCheckpointDto) => {
      const weather = checkpoint.weather
      let summary: string
      if (!weather) summary = t('rides.weather.checkpoints.noForecast')
      else {
        const temperatureText = temperature(weather.temperature)
        const condition = labels.condition(weather.condition)
        const wind = isKnownRelativeWind(checkpoint.relativeWind)
          ? t('rides.weather.wind.relativeAria', {
              relativeWind: labels.relativeWind(checkpoint.relativeWind),
              speed: speed(weather.wind.speed),
            })
          : labels.wind(weather.wind)
        // No chance of rain in the model is not a measured 0 %: it is left unsaid.
        summary =
          weather.precipitationProbability === undefined
            ? t('rides.weather.route.timeline.summaryNoRain', {
                temperature: temperatureText,
                condition,
                wind,
              })
            : t('rides.weather.route.timeline.summary', {
                temperature: temperatureText,
                condition,
                rain: weather.precipitationProbability,
                wind,
              })
      }
      return t('rides.weather.route.timeline.column', {
        time: formatTime(checkpoint.time),
        place: route.place(checkpoint),
        summary,
      })
    },
    [t, temperature, speed, formatTime, labels, route]
  )
}

// ---------------------------------------------------------------------------------------------
// The wind, phase by phase
// ---------------------------------------------------------------------------------------------

/**
 * The phases as the table's top row, each one above its own points (`phaseColumns`): the hours,
 * the band and the arrows under a block are that block's. A narrow block keeps its arrow and drops
 * its words (container queries); its name stays in its accessible label.
 */
function PhaseRow({
  phases,
  checkpoints,
  timezone,
  selectedPhase,
  onSelect,
}: {
  phases: WindPhase[]
  checkpoints: WeatherCheckpointDto[]
  timezone?: string
  selectedPhase: number | undefined
  onSelect: (phase: number) => void
}) {
  const { t } = useTranslation()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const spans = useMemo(() => phaseColumns(phases), [phases])

  return (
    <div
      className={classes.phaseRow}
      style={{ gridTemplateColumns: `repeat(${checkpoints.length * 2}, minmax(0, 1fr))` }}
      role="group"
      aria-label={t('rides.weather.route.phases.title')}
    >
      {phases.map((phase, index) => {
        const span = spans[index]
        if (!span) return null
        const times = phaseTimes(t, formatTime, phase, checkpoints)
        return (
          <UnstyledButton
            key={phase.fromDistance}
            className={classes.phase}
            style={{
              ...windStyle(phase.relativeWind),
              gridColumn: `${span.start + 1} / ${span.end + 1}`,
            }}
            aria-pressed={selectedPhase === index}
            aria-label={t('rides.weather.route.phases.block', {
              relativeWind: labels.relativeWind(phase.relativeWind),
              from: route.marker(phase.fromDistance),
              to: route.marker(phase.toDistance),
              times,
            })}
            onClick={() => onSelect(index)}
          >
            <span className={classes.phaseLine}>
              <WindArrow
                angle={RELATIVE_WIND_ANGLE[phase.relativeWind]}
                relativeWind={phase.relativeWind}
                label={labels.relativeWind(phase.relativeWind)}
                size={14}
              />
              <Text span size="sm" fw={700} className={`${classes.ellipsis} ${classes.phaseName}`}>
                {labels.relativeWindShort(phase.relativeWind)}
              </Text>
            </span>
            <Text
              span
              size="xs"
              className={`${classes.ellipsis} ${classes.phaseRange}`}
              suppressHydrationWarning={isGuessedText}
            >
              {route.range(phase.fromDistance, phase.toDistance)}
            </Text>
          </UnstyledButton>
        )
      })}
    </div>
  )
}

/** « Face 90 km · Travers 90 km · Dos 127 km » — always in words, with an arrow. */
function WindTotals({ exposure }: { exposure: WindExposureDto }) {
  const { t } = useTranslation()
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const totals: Record<RelativeWind, number> = {
    [RelativeWind.HEAD]: exposure.head,
    [RelativeWind.CROSS]: exposure.cross,
    [RelativeWind.TAIL]: exposure.tail,
  }
  return (
    <Group gap="md" wrap="wrap">
      {LEGEND_ORDER.filter((kind) => totals[kind] > 0).map((kind) => (
        <Group key={kind} gap={4} wrap="nowrap">
          <WindArrow
            angle={RELATIVE_WIND_ANGLE[kind]}
            relativeWind={kind}
            label={labels.relativeWind(kind)}
            size={14}
          />
          <Text size="xs">
            {t('rides.weather.route.phases.total', {
              relativeWind: labels.relativeWindShort(kind),
              distance: route.length(totals[kind]),
            })}
          </Text>
        </Group>
      ))}
    </Group>
  )
}

// ---------------------------------------------------------------------------------------------
// Desktop: one column per point
// ---------------------------------------------------------------------------------------------

interface TimelineProps {
  checkpoints: WeatherCheckpointDto[]
  timezone?: string
  selected: number
  onSelect: (position: number) => void
}

function DesktopTimeline({
  checkpoints,
  timezone,
  selected,
  onSelect,
  phases,
  selectedPhase,
  onSelectPhase,
}: TimelineProps & {
  phases: WindPhase[]
  selectedPhase: number | undefined
  onSelectPhase: (phase: number) => void
}) {
  const { t } = useTranslation()
  const { temperature, formatSpeed, distanceUnit, unitSystem } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const summarize = useCheckpointSummary(timezone)
  const lines = useMemo(
    () => temperaturePolylines(checkpoints.map((c) => c.weather?.temperature)),
    [checkpoints]
  )
  const empty = t('rides.weather.route.timeline.empty')

  return (
    <div className={classes.scroller}>
      <div className={classes.table} style={{ minWidth: Math.max(900, checkpoints.length * 48) }}>
        <div className={classes.labels} aria-hidden>
          {phases.length > 0 && (
            <div className={`${classes.label} ${classes.rPhases}`}>
              {t('rides.weather.route.timeline.rows.phases')}
            </div>
          )}
          <div className={`${classes.label} ${classes.rTime}`}>
            {t('rides.weather.route.timeline.rows.time')}
          </div>
          <div className={classes.rIcon} />
          <div className={`${classes.label} ${classes.rTempLabel}`}>
            {t('rides.weather.route.timeline.rows.temperature')}
          </div>
          <div
            className={`${classes.label} ${classes.rRain}`}
            style={{ alignItems: 'flex-start', justifyContent: 'center' }}
          >
            {t('rides.weather.route.timeline.rows.rain')}
          </div>
          <div className={`${classes.label} ${classes.rWindLabel}`}>
            {t('rides.weather.route.timeline.rows.wind')}
            {/* The wind and gust rows print bare numbers: their unit is said here, once */}
            <span className={classes.unit}>
              {unitSystem === 'IMPERIAL'
                ? t('rides.weather.route.timeline.rows.speedUnit_imperial')
                : t('rides.weather.route.timeline.rows.speedUnit')}
            </span>
          </div>
          <div className={`${classes.label} ${classes.rGusts}`}>
            {t('rides.weather.route.timeline.rows.gusts')}
          </div>
          <div className={`${classes.label} ${classes.rKm}`}>{distanceUnit()}</div>
        </div>

        <div className={classes.body}>
          {phases.length > 0 && (
            <PhaseRow
              phases={phases}
              checkpoints={checkpoints}
              timezone={timezone}
              selectedPhase={selectedPhase}
              onSelect={onSelectPhase}
            />
          )}
          <div
            className={classes.columns}
            style={{ gridTemplateColumns: `repeat(${checkpoints.length}, minmax(0, 1fr))` }}
            role="group"
            aria-label={t('rides.weather.route.timeline.label')}
          >
            <svg
              className={classes.curve}
              viewBox="0 0 100 100"
              preserveAspectRatio="none"
              aria-hidden
              focusable="false"
            >
              {lines.map((points) => (
                <polyline
                  key={points}
                  points={points}
                  className={classes.curveLine}
                  vectorEffect="non-scaling-stroke"
                />
              ))}
            </svg>
            {checkpoints.map((checkpoint, position) => {
              const weather = checkpoint.weather
              const relativeWind = isKnownRelativeWind(checkpoint.relativeWind)
                ? checkpoint.relativeWind
                : undefined
              return (
                <UnstyledButton
                  key={checkpoint.index}
                  className={classes.column}
                  aria-pressed={position === selected}
                  aria-label={summarize(checkpoint)}
                  onClick={() => onSelect(position)}
                  suppressHydrationWarning={isGuessedText}
                >
                  <span
                    className={`${classes.cell} ${classes.rTime}`}
                    suppressHydrationWarning={isGuessedText}
                  >
                    {/* « 1:00 PM » on two lines: a 12-hour time is wider than a column */}
                    {formatTime(checkpoint.time).replace(/[\s\u202f]+/g, '\n')}
                  </span>
                  <span className={`${classes.cell} ${classes.rIcon}`}>
                    {weather && (
                      <WeatherIcon
                        condition={weather.condition}
                        daylight={weather.daylight}
                        size={22}
                      />
                    )}
                  </span>
                  <span className={`${classes.cell} ${classes.rCurve}`} />
                  <span className={`${classes.cell} ${classes.rTemp}`}>
                    {weather ? temperature(weather.temperature) : empty}
                  </span>
                  <span className={`${classes.cell} ${classes.rRain}`}>
                    {weather?.precipitationProbability !== undefined && (
                      <>
                        <span className={classes.rainTrack}>
                          <span
                            className={classes.rainBar}
                            style={{ height: `${weather.precipitationProbability}%` }}
                          />
                        </span>
                        <span>
                          {t('rides.weather.percent', { value: weather.precipitationProbability })}
                        </span>
                      </>
                    )}
                  </span>
                  <span
                    className={`${classes.cell} ${classes.rBand}`}
                    style={relativeWind ? windStyle(relativeWind) : undefined}
                  >
                    {relativeWind && <span className={classes.band} />}
                  </span>
                  <span className={`${classes.cell} ${classes.rArrow}`}>
                    {weather && relativeWind && checkpoint.relativeWindAngle !== undefined && (
                      <WindArrow
                        angle={checkpoint.relativeWindAngle}
                        relativeWind={relativeWind}
                        label={labels.relativeWind(relativeWind)}
                        size={16}
                      />
                    )}
                  </span>
                  <span className={`${classes.cell} ${classes.rWind}`}>
                    {weather ? formatSpeed(weather.wind.speed) : ''}
                  </span>
                  <span className={`${classes.cell} ${classes.rGusts}`}>
                    {weather?.wind.gusts !== undefined ? formatSpeed(weather.wind.gusts) : ''}
                  </span>
                  <span className={`${classes.cell} ${classes.rKm}`}>
                    {route.whole(checkpoint.distance)}
                  </span>
                </UnstyledButton>
              )
            })}
          </div>
        </div>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------------------------
// Phone: the strip and its slider
// ---------------------------------------------------------------------------------------------

function PhoneStrip({ checkpoints, timezone, selected, onSelect }: TimelineProps) {
  const { t } = useTranslation()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const summarize = useCheckpointSummary(timezone)
  const sliderId = useId()
  const lines = useMemo(
    () => temperaturePolylines(checkpoints.map((c) => c.weather?.temperature)),
    [checkpoints]
  )
  const ticks = tickPositions(checkpoints.length)
  const grid = { gridTemplateColumns: `repeat(${checkpoints.length}, minmax(0, 1fr))` }

  return (
    <Stack gap={4}>
      <div aria-hidden>
        <div className={classes.strip} style={grid}>
          <svg
            className={classes.stripCurve}
            viewBox="0 0 100 100"
            preserveAspectRatio="none"
            focusable="false"
          >
            {lines.map((points) => (
              <polyline
                key={points}
                points={points}
                className={classes.curveLine}
                vectorEffect="non-scaling-stroke"
              />
            ))}
          </svg>
          {checkpoints.map((checkpoint, position) => {
            const probability = checkpoint.weather?.precipitationProbability
            return (
              <div
                key={checkpoint.index}
                className={classes.stripColumn}
                data-selected={position === selected || undefined}
              >
                <div className={classes.stripTemp} />
                <div className={classes.stripRain}>
                  {probability !== undefined && (
                    <div className={classes.stripRainBar} style={{ height: `${probability}%` }} />
                  )}
                </div>
                <div
                  className={classes.stripBand}
                  style={
                    isKnownRelativeWind(checkpoint.relativeWind)
                      ? windStyle(checkpoint.relativeWind)
                      : { background: 'transparent' }
                  }
                />
              </div>
            )
          })}
        </div>
        <div className={classes.ticks}>
          {ticks.map((position, k) => (
            <span
              key={position}
              className={classes.tick}
              style={tickStyle(position, checkpoints.length, k, ticks.length)}
              suppressHydrationWarning={isGuessedText}
            >
              {formatTime(checkpoints[position].time)}
            </span>
          ))}
        </div>
      </div>
      <Text component="label" htmlFor={sliderId} size="sm" fw={500}>
        {t('rides.weather.route.timeline.slider')}
      </Text>
      <input
        id={sliderId}
        type="range"
        className={classes.slider}
        min={0}
        max={Math.max(0, checkpoints.length - 1)}
        step={1}
        value={selected}
        aria-valuetext={summarize(checkpoints[selected])}
        onChange={(event) => onSelect(Number(event.currentTarget.value))}
      />
    </Stack>
  )
}

/**
 * A tick under the centre of its column (column i of n spans [i/n, (i+1)/n]), the first one
 * flush left and the last one flush right so neither runs off the strip.
 */
function tickStyle(position: number, n: number, k: number, count: number): CSSProperties {
  if (k === 0) return { left: 0 }
  if (k === count - 1) return { right: 0 }
  return { left: `${((position + 0.5) / n) * 100}%`, transform: 'translateX(-50%)' }
}

// ---------------------------------------------------------------------------------------------
// The selected point
// ---------------------------------------------------------------------------------------------

function CheckpointDetail({
  checkpoint,
  phase,
  timezone,
  announce,
}: {
  checkpoint: WeatherCheckpointDto
  phase: WindPhase | undefined
  timezone?: string
  /** Speak the newly selected point (a short line) — not when the slider already does. */
  announce: boolean
}) {
  const { t } = useTranslation()
  const { temperature, speed } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const weather = checkpoint.weather
  const relativeWind = isKnownRelativeWind(checkpoint.relativeWind)
    ? checkpoint.relativeWind
    : undefined

  return (
    <Paper withBorder radius="md" p="md" data-route-detail>
      <VisuallyHidden aria-live="polite">
        {announce
          ? t('rides.weather.route.detail.announce', {
              place: route.place(checkpoint),
              time: formatTime(checkpoint.time),
            })
          : ''}
      </VisuallyHidden>
      <Stack gap="sm">
        <Group gap="xs" wrap="wrap" align="baseline">
          <Text fw={700}>{route.place(checkpoint)}</Text>
          <Text size="sm" suppressHydrationWarning={isGuessedText}>
            {formatTime(checkpoint.time)}
          </Text>
        </Group>
        {weather ? (
          <SimpleGrid cols={{ base: 2, sm: 4 }} spacing="md" verticalSpacing="sm">
            <DetailCell label={t('rides.weather.route.detail.temperature')}>
              <Group gap={6} wrap="nowrap">
                <WeatherIcon condition={weather.condition} daylight={weather.daylight} size={20} />
                <Text size="sm" fw={700}>
                  {temperature(weather.temperature)}
                </Text>
              </Group>
              <Text size="sm">{labels.condition(weather.condition)}</Text>
              <Text size="sm">
                {t('rides.weather.feelsLike', {
                  temperature: temperature(weather.apparentTemperature),
                })}
              </Text>
            </DetailCell>
            <DetailCell label={t('rides.weather.route.detail.rain')}>
              <Text size="sm" fw={700}>
                {weather.precipitationProbability === undefined
                  ? t('rides.weather.route.timeline.empty')
                  : weather.precipitation > 0
                    ? t('rides.weather.route.detail.rainAmount', {
                        probability: weather.precipitationProbability,
                        amount: weather.precipitation.toFixed(1),
                      })
                    : t('rides.weather.route.detail.rainChance', {
                        probability: weather.precipitationProbability,
                      })}
              </Text>
            </DetailCell>
            <DetailCell label={t('rides.weather.route.detail.wind')}>
              <Group gap={6} wrap="nowrap">
                {relativeWind && checkpoint.relativeWindAngle !== undefined && (
                  <WindArrow
                    angle={checkpoint.relativeWindAngle}
                    relativeWind={relativeWind}
                    label={labels.relativeWind(relativeWind)}
                    size={18}
                  />
                )}
                <Text size="sm" fw={700}>
                  {speed(weather.wind.speed)}
                </Text>
              </Group>
              {relativeWind && <Text size="sm">{labels.relativeWind(relativeWind)}</Text>}
              <Text size="sm">
                {[
                  weather.wind.gusts !== undefined &&
                    t('rides.weather.route.detail.gusts', { gusts: speed(weather.wind.gusts) }),
                  labels.compass(weather.wind.compass) &&
                    t('rides.weather.route.detail.sector', {
                      compass: labels.compass(weather.wind.compass),
                    }),
                ]
                  .filter(Boolean)
                  .join(' · ')}
              </Text>
            </DetailCell>
            <DetailCell label={t('rides.weather.route.detail.phase')}>
              <Text size="sm">
                {phase
                  ? t('rides.weather.route.detail.phaseRange', {
                      relativeWind: labels.relativeWindShort(phase.relativeWind),
                      from: route.marker(phase.fromDistance),
                      to: route.marker(phase.toDistance),
                    })
                  : t('rides.weather.route.timeline.empty')}
              </Text>
            </DetailCell>
          </SimpleGrid>
        ) : (
          <Text size="sm">{t('rides.weather.checkpoints.noForecast')}</Text>
        )}
      </Stack>
    </Paper>
  )
}

function DetailCell({ label, children }: { label: string; children: ReactNode }) {
  return (
    <Stack gap={2}>
      <Text size="xs" fw={700} tt="uppercase">
        {label}
      </Text>
      {children}
    </Stack>
  )
}

// ---------------------------------------------------------------------------------------------
// Phone: by stretch
// ---------------------------------------------------------------------------------------------

function PhaseList({
  phases,
  checkpoints,
  exposure,
  timezone,
  onSelect,
}: {
  phases: WindPhase[]
  checkpoints: WeatherCheckpointDto[]
  exposure: WindExposureDto
  timezone?: string
  /** Selects the phase (by its index) and the point it opens on. */
  onSelect: (phase: number) => void
}) {
  const { t } = useTranslation()
  const { temperature, speed, formatSpeed } = useUnits()
  const { formatTime, isGuessedText } = useRendezvousFormat(timezone)
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const baseId = useId()
  const [open, setOpen] = useState<number | null>(null)

  return (
    <Stack gap="xs">
      <Title order={4} size="h5">
        {t('rides.weather.route.phaseList.title')}
      </Title>
      <ol className={classes.phaseList}>
        {phases.map((phase, index) => {
          const stats = phaseStats(phase, checkpoints)
          const expanded = open === index
          const panelId = `${baseId}-${index}`
          const summary = [
            phaseTimes(t, formatTime, phase, checkpoints),
            [
              stats.windMin !== undefined &&
                stats.windMax !== undefined &&
                (stats.windMin === stats.windMax
                  ? speed(stats.windMax)
                  : t('rides.weather.route.phaseList.windRange', {
                      min: formatSpeed(stats.windMin),
                      max: speed(stats.windMax),
                    })),
              stats.gustsMax !== undefined &&
                t('rides.weather.route.phaseList.gusts', { gusts: formatSpeed(stats.gustsMax) }),
            ]
              .filter(Boolean)
              .join(', '),
            stats.rainMax !== undefined &&
              t('rides.weather.route.phaseList.rain', { probability: stats.rainMax }),
          ]
            .filter(Boolean)
            .join(' · ')
          const temperatures =
            stats.temperatureMin === undefined || stats.temperatureMax === undefined
              ? undefined
              : temperature(stats.temperatureMin) === temperature(stats.temperatureMax)
                ? temperature(stats.temperatureMax)
                : t('rides.weather.route.verdict.temperature.range', {
                    min: temperature(stats.temperatureMin),
                    max: temperature(stats.temperatureMax),
                  })
          return (
            <li key={phase.fromDistance}>
              <UnstyledButton
                className={classes.phaseItem}
                aria-expanded={expanded}
                aria-controls={panelId}
                onClick={() => {
                  setOpen(expanded ? null : index)
                  onSelect(index)
                }}
              >
                <Group gap="sm" wrap="nowrap">
                  <span className={classes.swatch} style={windStyle(phase.relativeWind)}>
                    <WindArrow
                      angle={RELATIVE_WIND_ANGLE[phase.relativeWind]}
                      relativeWind={phase.relativeWind}
                      label={labels.relativeWind(phase.relativeWind)}
                      size={16}
                    />
                  </span>
                  <Stack gap={0} style={{ flex: 1, minWidth: 0 }}>
                    <Text size="sm" fw={700}>
                      {t('rides.weather.route.phaseList.heading', {
                        relativeWind: labels.relativeWindShort(phase.relativeWind),
                        range: route.range(phase.fromDistance, phase.toDistance),
                      })}
                    </Text>
                    <Text size="xs" suppressHydrationWarning={isGuessedText}>
                      {summary}
                    </Text>
                  </Stack>
                  {temperatures && (
                    <Text size="sm" fw={600} style={{ whiteSpace: 'nowrap' }}>
                      {temperatures}
                    </Text>
                  )}
                  <IconChevronDown size={18} aria-hidden className={classes.chevron} />
                </Group>
              </UnstyledButton>
              <Collapse expanded={expanded} id={panelId}>
                {phase.checkpoints.length === 0 && (
                  <Text size="sm" className={classes.noPoint}>
                    {t('rides.weather.route.phaseList.noPoint')}
                  </Text>
                )}
                <ul className={classes.pointRows}>
                  {phase.checkpoints.map((position) => {
                    const checkpoint = checkpoints[position]
                    const weather = checkpoint.weather
                    const relativeWind = isKnownRelativeWind(checkpoint.relativeWind)
                      ? checkpoint.relativeWind
                      : undefined
                    return (
                      <li key={checkpoint.index} className={classes.pointRow}>
                        <span suppressHydrationWarning={isGuessedText}>
                          {formatTime(checkpoint.time)}
                        </span>
                        <span>{route.marker(checkpoint.distance)}</span>
                        <span>
                          {weather
                            ? temperature(weather.temperature)
                            : t('rides.weather.route.timeline.empty')}
                        </span>
                        <span>
                          {weather?.precipitationProbability !== undefined &&
                            t('rides.weather.percent', {
                              value: weather.precipitationProbability,
                            })}
                        </span>
                        <span>
                          {weather &&
                            (weather.wind.gusts !== undefined
                              ? t('rides.weather.route.phaseList.windRow', {
                                  relativeWind: labels.relativeWindShort(relativeWind),
                                  speed: formatSpeed(weather.wind.speed),
                                  gusts: formatSpeed(weather.wind.gusts),
                                })
                              : t('rides.weather.route.phaseList.windRowNoGusts', {
                                  relativeWind: labels.relativeWindShort(relativeWind),
                                  speed: formatSpeed(weather.wind.speed),
                                })
                            ).trim()}
                        </span>
                      </li>
                    )
                  })}
                </ul>
              </Collapse>
            </li>
          )
        })}
      </ol>
      <WindTotals exposure={exposure} />
    </Stack>
  )
}
