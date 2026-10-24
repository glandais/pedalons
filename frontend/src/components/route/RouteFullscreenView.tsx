import { lazy, Suspense, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocation, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { IconArrowLeft } from '@tabler/icons-react'
import { ActionIcon, Box, Center, Text } from '@mantine/core'
import type { WeatherAttributionDto, WeatherLegDto } from '@/api/dto'
import { WindMapLegend, type WindLegendSubject } from '@/components/weather/WindMapLegend'
import { getOverlayBg } from '@/lib/colors'
import { attributionHtml } from '@/lib/weatherOnRoute'
import { useRouteWindColors } from '@/hooks/useRouteWindColors'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useMapChartZoomSync } from '@/hooks/useMapChartZoomSync'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { hasSurfaces } from '@/lib/trackSurface'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import type { WaypointSelection } from '@/lib/waypoints'
import { useRouteSurfaceColors } from '@/hooks/useRouteSurfaceColors'
import { RouteTrackMap } from './RouteTrackMap'
import { ElevationChart } from './ElevationChart'
import { ColorByControl, type ColorByOption } from './ColorByControl'
import type { MappableRoute } from './RouteMapView'

// Lazy, as on the group's page: the forecast's points, in the Météo mode only.
const WeatherCheckpointMarkers = lazy(() =>
  import('@/components/weather/WeatherCheckpointMarkers').then((m) => ({
    default: m.WeatherCheckpointMarkers,
  }))
)

/** A route rich enough for the fullscreen toolbar's distance / D+ / D− readout. */
export type FullscreenRoute = MappableRoute & {
  elevationGain: number
  elevationLoss: number
}

export interface RouteFullscreenViewProps {
  route: FullscreenRoute
  /** Title shown in the toolbar (the route/stage/track name). */
  title: string
  /**
   * Locale-aware path to return to (built by the page via paths.xxx) when the map was opened
   * directly; reached from within the app, the back button goes back in history instead, so it
   * returns to whichever page opened the map (a ride group, a stage…), not to the route sheet.
   */
  backTo: string
  /**
   * The mode the line is coloured in, when the page holds it (the group's map reads it from its
   * URL, ledger WEB-117). A mode the route cannot offer — no surface, no `windLeg` — reads as the
   * grade. Left out, the view keeps its own, starting on the grade.
   */
  colorBy?: ColorByOption
  onColorByChange?: (colorBy: ColorByOption) => void
  /**
   * A leg with a forecast offers the Météo mode (WEB-115/116 on the group's page): the line by the
   * wind, a badge per forecast point with its popup, the legend and the forecast's credit; the
   * profile keeps its grade.
   */
  windLeg?: WeatherLegDto
  /** The forecast's credit, owed while the wind colours the line. */
  windAttribution?: WeatherAttributionDto
  /** Whose speed the legend speaks of when the passages assume the default: a group, a stage. */
  windSubject?: WindLegendSubject
  /** The ride's or the stage's zone: the passages of the forecast's points read in it. */
  timezone?: string
}

/**
 * Fullscreen route viewer à la prendslaroue: a slim toolbar, a map filling the viewport, and a
 * fixed elevation strip pinned below it. Cursor sync (map ↔ chart) plus bidirectional zoom/pan
 * sync via {@link useMapChartZoomSync}; hover updates are suppressed while either side is driving
 * the other so the crosshair doesn't jump mid-gesture.
 */
export function RouteFullscreenView({
  route,
  title,
  backTo,
  colorBy: controlledColorBy,
  onColorByChange,
  windLeg,
  windAttribution,
  windSubject,
  timezone,
}: RouteFullscreenViewProps) {
  const { t } = useTranslation()
  const location = useLocation()
  const navigate = useNavigate()
  const colorScheme = useResolvedColorScheme()
  const [hoveredPointIndex, setHoveredPointIndex] = useState<number>(-1)
  const [ownColorBy, setOwnColorBy] = useState<ColorByOption>('grade')
  const requested = controlledColorBy ?? ownColorBy
  const setColorBy = (next: ColorByOption) => {
    if (controlledColorBy === undefined) setOwnColorBy(next)
    onColorByChange?.(next)
  }
  const withSurface = hasSurfaces(route.tracks)
  const options: ColorByOption[] = ['grade']
  if (withSurface) options.push('surface')
  if (windLeg) options.push('wind')
  // A mode the route cannot offer (a link's `?color=`, a forecast gone) reads as the grade
  const colorBy: ColorByOption = options.includes(requested) ? requested : 'grade'
  const wind = colorBy === 'wind' && windLeg ? windLeg : undefined
  const planner: PlannerColorBy = colorBy === 'surface' ? 'surface' : 'grade'
  const [waypointSelection, setWaypointSelection] = useState<WaypointSelection | null>(null)
  const { surfaceAt, lineColorAt: surfaceColorAt } = useRouteSurfaceColors(route.tracks, planner)
  const windColorAt = useRouteWindColors(route.tracks, wind)
  const lineColorAt = windColorAt ?? surfaceColorAt

  const {
    mapRef,
    chartRef,
    mapMoving,
    chartMoving,
    onMapMoveStart,
    onMapMoveEnd,
    onChartMoveStart,
    onChartMoveComplete,
  } = useMapChartZoomSync(route)

  // Ignore hover while a zoom/pan gesture is driving the counterpart view. Left unmemoized so the
  // React Compiler can optimize it (manual useCallback over ref reads is rejected by lint).
  const handleHoverPoint = (index: number) => {
    if (mapMoving.current || chartMoving.current) return
    setHoveredPointIndex(index)
  }

  const trackPoints = route.tracks.flatMap((track) => track.line.coordinates)

  if (trackPoints.length === 0) {
    return (
      <Center h="100dvh" bg="var(--mantine-color-body)">
        <Text c="dimmed">{t('map.noTrackData')}</Text>
      </Center>
    )
  }

  const stripBg = getOverlayBg(colorScheme, true)

  // The router's first entry has the key 'default': anything else was reached by an in-app
  // navigation, so there is a page of ours to go back to. A modified click keeps the link.
  const handleBack = (event: React.MouseEvent<HTMLAnchorElement>) => {
    if (location.key === 'default' || event.metaKey || event.ctrlKey || event.shiftKey) return
    event.preventDefault()
    navigate(-1)
  }

  return (
    <MapFullscreenShell
      leading={
        <ActionIcon
          component={PrefetchLink}
          to={backTo}
          onClick={handleBack}
          variant="subtle"
          size="lg"
          aria-label={t('actions.back')}
        >
          <IconArrowLeft size={20} />
        </ActionIcon>
      }
      title={title}
      stats={{
        distance: route.distance,
        gain: route.elevationGain,
        loss: route.elevationLoss,
      }}
      // The grade / surface switch of the route sheet (WEB-100 C1b), once the route has its surface,
      // and the Météo mode with a forecast (WEB-117) — nothing with a single mode
      actions={
        <ColorByControl
          value={colorBy}
          onChange={setColorBy}
          options={options}
          testId="route-fullscreen-color-by"
        />
      }
      bottom={
        <>
          {/* What the wind colours say, and the forecast's credit: the profile under the map
              would cover MapLibre's own attribution */}
          {wind && (
            <Box
              px="sm"
              py={6}
              style={{
                flexShrink: 0,
                borderTop: '1px solid var(--mantine-color-default-border)',
                backgroundColor: stripBg,
              }}
            >
              <WindMapLegend leg={wind} subject={windSubject} attribution={windAttribution} />
            </Box>
          )}
          {/* Fixed elevation strip below the map (no overlap) */}
          <Box
            h={160}
            style={{
              flexShrink: 0,
              borderTop: '1px solid var(--mantine-color-default-border)',
              backgroundColor: stripBg,
            }}
          >
            <ElevationChart
              ref={chartRef}
              route={route}
              hoveredPointIndex={hoveredPointIndex}
              onHoverPoint={handleHoverPoint}
              filled
              colorBy={surfaceAt ? 'surface' : 'grade'}
              surfaceAt={surfaceAt}
              selectedWaypoint={waypointSelection?.waypoint ?? null}
              onSelectWaypoint={(waypoint) => setWaypointSelection({ waypoint, from: 'profile' })}
              zoom={{
                onMoveStart: onChartMoveStart,
                onMoveComplete: onChartMoveComplete,
              }}
            />
          </Box>
        </>
      }
    >
      <RouteTrackMap
        route={route}
        mapRef={mapRef}
        hoveredPointIndex={hoveredPointIndex}
        onHoverPoint={handleHoverPoint}
        fitPadding={50}
        lineColorAt={lineColorAt}
        lineAttribution={wind && windAttribution ? attributionHtml(windAttribution) : undefined}
        overlays={
          wind && (
            <Suspense fallback={null}>
              <WeatherCheckpointMarkers tracks={route.tracks} leg={wind} timezone={timezone} />
            </Suspense>
          )
        }
        kmMarkers={!wind}
        waypointSelection={waypointSelection}
        onWaypointSelect={setWaypointSelection}
        onMoveStart={onMapMoveStart}
        onMoveEnd={onMapMoveEnd}
      />
    </MapFullscreenShell>
  )
}
