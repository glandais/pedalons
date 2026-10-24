import { useCallback, useEffect, useId, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Marker, Popup, useMap } from 'react-map-gl/maplibre'
import { Box, Group, Stack, Text, UnstyledButton } from '@mantine/core'
import { IconArrowUp, IconDroplet } from '@tabler/icons-react'
import type { TrackDto, WeatherLegDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { getOverlayBg } from '@/lib/colors'
import {
  chainedDistances,
  checkpointPoint,
  mapCheckpoints,
  mapWindRotation,
  type MapCheckpoint,
} from '@/lib/weatherOnRoute'
import { WeatherIcon } from './WeatherIcon'
import { useCheckpointSummary } from './useCheckpointSummary'
import { useRouteLabels } from './useRouteLabels'
import { useWeatherLabels } from './useWeatherLabels'
import { isKnownRelativeWind, rainAlertCondition } from './weatherDisplay'

interface WeatherCheckpointMarkersProps {
  /** The tracks the map draws: a checkpoint is placed by its distance on them (chained). */
  tracks: Pick<TrackDto, 'line'>[]
  leg: WeatherLegDto
  /** The ride's zone: passages are rendezvous read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
  /**
   * The checkpoint (its `index`) whose popup is open, when the page holds it (ledger WEB-117: the
   * row selected in « Heure par heure » opens its badge). Left out, the component keeps its own.
   */
  openIndex?: number | null
  /** Every opening or closing — a badge, the popup's button, Escape —, controlled or not. */
  onOpenChange?: (index: number | null) => void
  /**
   * Whose points these are, when a map lays several legs at once (a trip's overview, ledger
   * WEB-118): a stage's name. Each badge's label, its popup's title and the drop's label then name
   * it and the passage's day (in `timezone`), so the stages of a multi-day trip — the loops of a
   * base camp, whose badges overlap — are told apart. Left out (a group, a stage), they read as
   * before.
   */
  context?: string
}

/**
 * The forecast on the map, point by point (ledger WEB-116, plan 2026-10-24-weather-on-map.md §5
 * palier 2): a compact badge at every checkpoint that has its weather — sky, temperature, the
 * wind's absolute arrow — and a drop where rain becomes likely (`leg.rainAlert`, the server's
 * threshold). A badge is a button: a click or Enter opens its detail in a popup that stays open,
 * one at a time, closed by its button, Escape or the badge again. The timeline under the map
 * remains the full, accessible reference. Rendered inside the map (`overlays`), in the Météo mode
 * only — the caller's decision.
 */
export function WeatherCheckpointMarkers({
  tracks,
  leg,
  timezone,
  openIndex: controlledOpenIndex,
  onOpenChange,
  context,
}: WeatherCheckpointMarkersProps) {
  const { t } = useTranslation()
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const passage = useRendezvousFormat(timezone)
  const summarize = useCheckpointSummary(timezone)
  const inContext = useInContext(context, timezone)
  // The whole geometry measured once, for every badge and the drop
  const bearing = useMapBearing()
  const chained = useMemo(() => chainedDistances(tracks), [tracks])
  const markers = useMemo(
    () => mapCheckpoints(tracks, leg.checkpoints, chained),
    [tracks, leg.checkpoints, chained]
  )
  const [ownOpenIndex, setOwnOpenIndex] = useState<number | null>(null)
  const controlled = controlledOpenIndex !== undefined
  const openIndex = controlled ? controlledOpenIndex : ownOpenIndex
  const setOpenIndex = useCallback(
    (next: number | null) => {
      if (!controlled) setOwnOpenIndex(next)
      onOpenChange?.(next)
    },
    [controlled, onOpenChange]
  )
  /**
   * Whether the popup about to open was asked by its badge: only then does it take the focus. One
   * opened from the page's table leaves the focus on the table's row.
   */
  const focusOnOpen = useRef(false)
  const buttons = useRef(new Map<number, HTMLButtonElement>())
  const popupRef = useRef<HTMLDivElement>(null)
  /** Whether the focus was last inside the popup — kept as it moves, read when it closes. */
  const focusInPopup = useRef(false)
  const open = markers.find((m) => m.checkpoint.index === openIndex)

  /** Inside the popup: its content, or MapLibre's close button beside it. */
  const isInPopup = useCallback(
    (node: EventTarget | null) =>
      node instanceof Element &&
      (!!popupRef.current?.contains(node) || !!node.closest('.maplibregl-popup')),
    []
  )

  // On opening, the focus goes to the detail itself — the dialog with its title, read first —
  // rather than to MapLibre's close button. Then follow it: MapLibre takes its close button out
  // of the page *before* it says the popup closed, so by then the focus has already fallen to the
  // body and `document.activeElement` can no longer tell where it was.
  useEffect(() => {
    if (openIndex === null) return
    if (focusOnOpen.current) popupRef.current?.focus({ preventScroll: true })
    focusOnOpen.current = false
    focusInPopup.current = isInPopup(document.activeElement)
    const onFocusIn = (event: FocusEvent) => {
      focusInPopup.current = isInPopup(event.target)
    }
    document.addEventListener('focusin', onFocusIn)
    return () => document.removeEventListener('focusin', onFocusIn)
  }, [openIndex, isInPopup])

  /** Closes the popup, handing the focus back to its badge when it was inside. */
  const close = useCallback(() => {
    const index = openIndex
    const hadFocus = focusInPopup.current || isInPopup(document.activeElement)
    focusInPopup.current = false
    setOpenIndex(null)
    if (hadFocus && index !== null) buttons.current.get(index)?.focus()
  }, [openIndex, isInPopup, setOpenIndex])

  // Escape closes it, wherever the focus is — the popup's close button, the badge, the page.
  useEffect(() => {
    if (openIndex === null) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key !== 'Escape' || event.defaultPrevented) return
      const target = event.target instanceof Element ? event.target : null
      // An Escape that closes a menu or another dialog over the map is not for this popup
      const dialog = target?.closest('[role=dialog], [role=menu]')
      if (dialog && !popupRef.current?.contains(dialog)) return
      close()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [openIndex, close])

  const alert = leg.rainAlert
  const alertPoint = useMemo(
    () =>
      alert?.distance !== undefined ? checkpointPoint(tracks, alert.distance, chained) : undefined,
    [tracks, alert?.distance, chained]
  )

  return (
    <>
      {markers.map((marker) => (
        <Marker
          key={marker.checkpoint.index}
          longitude={marker.longitude}
          latitude={marker.latitude}
          // The capsule 6 px above its point (the line, the start and the finish stay visible
          // under it): its 44 px target, centred on it, reaches 5 px below the point
          anchor="bottom"
          offset={[0, BADGE_TARGET / 2 - BADGE_HEIGHT / 2 - 6]}
        >
          <CheckpointBadge
            marker={marker}
            label={inContext(summarize(marker.checkpoint), marker.checkpoint.time)}
            expanded={openIndex === marker.checkpoint.index}
            bearing={bearing}
            buttonRef={(element) => {
              if (element) buttons.current.set(marker.checkpoint.index, element)
              else buttons.current.delete(marker.checkpoint.index)
            }}
            onToggle={() => {
              const opening = openIndex !== marker.checkpoint.index
              focusOnOpen.current = opening
              setOpenIndex(opening ? marker.checkpoint.index : null)
            }}
          />
        </Marker>
      ))}

      {alert && alertPoint && (
        // A mere sign, under its point: a press on it is the map's
        <Marker
          longitude={alertPoint[0]}
          latitude={alertPoint[1]}
          anchor="top"
          offset={[0, 6]}
          style={{ pointerEvents: 'none' }}
        >
          <RainDrop
            label={inContext(
              t('rides.weather.rain.alertAt', {
                condition: labels.condition(rainAlertCondition(alert.condition)),
                probability: alert.probability,
                time: passage.formatTime(alert.time),
                distance: route.marker(alert.distance ?? 0),
              }),
              alert.time
            )}
          />
        </Marker>
      )}

      {open && (
        <Popup
          // One popup per point: switching points remounts it, its focus with it
          key={open.checkpoint.index}
          longitude={open.longitude}
          latitude={open.latitude}
          anchor="bottom"
          offset={34}
          closeOnClick={false}
          // The detail takes the focus itself (the effect above), not the close button
          focusAfterOpen={false}
          maxWidth="260px"
          onClose={close}
        >
          <CheckpointDetail
            ref={popupRef}
            marker={open}
            timezone={timezone}
            context={context}
            bearing={bearing}
          />
        </Popup>
      )}
    </>
  )
}

/** The capsule drawn on the map, and the touch target around it (WCAG 2.5.8, 44 px aimed). */
const BADGE_HEIGHT = 22
const BADGE_TARGET = 44

function CheckpointBadge({
  marker,
  label,
  expanded,
  bearing,
  buttonRef,
  onToggle,
}: {
  marker: MapCheckpoint
  label: string
  expanded: boolean
  bearing: number
  buttonRef: (element: HTMLButtonElement | null) => void
  onToggle: () => void
}) {
  const colorScheme = useResolvedColorScheme()
  const { temperature } = useUnits()
  const weather = marker.checkpoint.weather
  return (
    <UnstyledButton
      ref={buttonRef}
      aria-label={label}
      aria-expanded={expanded}
      aria-haspopup="dialog"
      data-testid="weather-checkpoint-badge"
      onClick={(event) => {
        // The map's own click (a waypoint's selection) is not for the badge. This does reach the
        // native event in time: the Marker renders the badge through a portal into its own
        // element, where React listens too, and that element sits inside the map's canvas
        // container, where MapLibre listens — so React's handler runs first and stops it there.
        event.stopPropagation()
        onToggle()
      }}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minWidth: BADGE_TARGET,
        height: BADGE_TARGET,
      }}
    >
      <Box
        component="span"
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 2,
          height: BADGE_HEIGHT,
          padding: '0 5px 0 3px',
          borderRadius: BADGE_HEIGHT / 2,
          border: `1px solid ${
            expanded ? 'var(--mantine-color-blue-filled)' : 'var(--mantine-color-default-border)'
          }`,
          backgroundColor: getOverlayBg(colorScheme, true),
          color: 'var(--mantine-color-text)',
          boxShadow: 'var(--mantine-shadow-sm)',
          whiteSpace: 'nowrap',
        }}
      >
        <Box component="span" aria-hidden style={{ display: 'flex' }}>
          <WeatherIcon condition={weather.condition} daylight={weather.daylight} size={14} />
        </Box>
        <Text component="span" size="xs" fw={700} aria-hidden style={{ lineHeight: 1 }}>
          {temperature(weather.temperature)}
        </Text>
        <IconArrowUp
          size={12}
          stroke={2.5}
          aria-hidden
          style={{
            flexShrink: 0,
            transform: `rotate(${mapWindRotation(weather.wind.direction, bearing)}deg)`,
          }}
        />
      </Box>
    </UnstyledButton>
  )
}

function RainDrop({ label }: { label: string }) {
  const colorScheme = useResolvedColorScheme()
  return (
    <Box
      role="img"
      aria-label={label}
      data-testid="weather-rain-alert"
      w={20}
      h={20}
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: '50%',
        border: '1px solid var(--mantine-color-default-border)',
        backgroundColor: getOverlayBg(colorScheme, true),
        boxShadow: 'var(--mantine-shadow-sm)',
      }}
    >
      <IconDroplet size={14} color="var(--mantine-color-blue-text)" aria-hidden />
    </Box>
  )
}

/**
 * A point's forecast in full: its passage in the ride's zone, the sky, the chance and amount of
 * rain when the model gives them, the wind and its gusts — never « 0 » for gusts it lacks.
 */
function CheckpointDetail({
  ref,
  marker,
  timezone,
  context,
  bearing,
}: {
  ref: React.Ref<HTMLDivElement>
  marker: MapCheckpoint
  timezone?: string
  context?: string
  bearing: number
}) {
  const { t } = useTranslation()
  const { temperature, precipitation } = useUnits()
  const labels = useWeatherLabels()
  const route = useRouteLabels()
  const passage = useRendezvousFormat(timezone)
  const inContext = useInContext(context, timezone)
  const titleId = useId()
  const { checkpoint } = marker
  const weather = checkpoint.weather
  const amount = weather.precipitation > 0 ? precipitation(weather.precipitation) : undefined
  const rain =
    weather.precipitationProbability !== undefined
      ? amount
        ? t('rides.weather.precipitationWithAmount', {
            probability: weather.precipitationProbability,
            amount,
          })
        : t('rides.weather.precipitation', { probability: weather.precipitationProbability })
      : amount && t('rides.weather.map.precipitationAmount', { amount })
  const relativeWind = isKnownRelativeWind(checkpoint.relativeWind)
    ? labels.relativeWind(checkpoint.relativeWind)
    : ''

  return (
    <Stack
      ref={ref}
      role="dialog"
      aria-labelledby={titleId}
      // Focused on opening (never a tab stop of its own), so its title is what is read first
      tabIndex={-1}
      gap={4}
      pr="md"
      data-testid="weather-checkpoint-detail"
    >
      <Text
        id={titleId}
        component="h3"
        size="sm"
        fw={700}
        m={0}
        suppressHydrationWarning={passage.isGuessedText}
      >
        {inContext(
          t('rides.weather.map.checkpointTitle', {
            place: route.place(checkpoint),
            time: passage.formatTime(checkpoint.time),
          }),
          checkpoint.time
        )}
      </Text>
      <Group gap={6} wrap="nowrap">
        <WeatherIcon condition={weather.condition} daylight={weather.daylight} size={18} />
        <Text size="sm" fw={700}>
          {temperature(weather.temperature)}
        </Text>
        <Text size="sm">{labels.condition(weather.condition)}</Text>
      </Group>
      {rain && <Text size="sm">{rain}</Text>}
      <Group gap={6} wrap="nowrap" align="flex-start">
        <IconArrowUp
          size={16}
          stroke={2.5}
          aria-hidden
          style={{
            flexShrink: 0,
            marginTop: 2,
            transform: `rotate(${mapWindRotation(weather.wind.direction, bearing)}deg)`,
          }}
        />
        <Text size="sm">
          {relativeWind
            ? t('rides.weather.map.windDetail', {
                wind: labels.windWithGusts(weather.wind),
                relativeWind,
              })
            : labels.windWithGusts(weather.wind)}
        </Text>
      </Group>
    </Stack>
  )
}

/**
 * « Étape 3, sam. 3 mai — Départ · 09:00 »: a text prefixed with whose point it is and the day of
 * its passage, read in the leg's zone — the text alone without a `context`.
 */
function useInContext(context: string | undefined, timezone: string | undefined) {
  const { t } = useTranslation()
  const { formatPattern } = useRendezvousFormat(timezone)
  return useCallback(
    (text: string, time: string) =>
      context
        ? t('rides.weather.map.inContext', {
            // Not `context`: i18next reads it as the key's variant
            name: context,
            day: formatPattern(time, 'EEE d MMM'),
            text,
          })
        : text,
    [t, formatPattern, context]
  )
}

/**
 * The map's bearing, followed as it turns: the arrows stay geographic on a rotated map (drag to
 * rotate, the compass resets it). 0 outside a map.
 */
function useMapBearing(): number {
  const { current: mapRef } = useMap()
  const [bearing, setBearing] = useState(() => mapRef?.getBearing() ?? 0)

  useEffect(() => {
    if (!mapRef) return
    const map = mapRef.getMap()
    const update = () => setBearing(map.getBearing())
    update()
    map.on('rotate', update)
    return () => {
      map.off('rotate', update)
    }
  }, [mapRef])

  return bearing
}
