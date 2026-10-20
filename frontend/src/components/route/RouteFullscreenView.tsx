import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocation, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { IconArrowLeft } from '@tabler/icons-react'
import { ActionIcon, Box, Center, SegmentedControl, Text } from '@mantine/core'
import { getOverlayBg } from '@/lib/colors'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useMapChartZoomSync } from '@/hooks/useMapChartZoomSync'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { hasSurfaces } from '@/lib/trackSurface'
import type { PlannerColorBy } from '@/lib/plannerSurface'
import { useRouteSurfaceColors } from '@/hooks/useRouteSurfaceColors'
import { RouteTrackMap } from './RouteTrackMap'
import { ElevationChart } from './ElevationChart'
import type { MappableRoute } from './RouteMapView'

/** A route rich enough for the fullscreen toolbar's distance / D+ / D− readout. */
export type FullscreenRoute = MappableRoute & {
  elevationGain: number
  elevationLoss: number
}

interface RouteFullscreenViewProps {
  route: FullscreenRoute
  /** Title shown in the toolbar (the route/stage/track name). */
  title: string
  /**
   * Locale-aware path to return to (built by the page via paths.xxx) when the map was opened
   * directly; reached from within the app, the back button goes back in history instead, so it
   * returns to whichever page opened the map (a ride group, a stage…), not to the route sheet.
   */
  backTo: string
}

/**
 * Fullscreen route viewer à la prendslaroue: a slim toolbar, a map filling the viewport, and a
 * fixed elevation strip pinned below it. Cursor sync (map ↔ chart) plus bidirectional zoom/pan
 * sync via {@link useMapChartZoomSync}; hover updates are suppressed while either side is driving
 * the other so the crosshair doesn't jump mid-gesture.
 */
export function RouteFullscreenView({ route, title, backTo }: RouteFullscreenViewProps) {
  const { t } = useTranslation()
  const location = useLocation()
  const navigate = useNavigate()
  const colorScheme = useResolvedColorScheme()
  const [hoveredPointIndex, setHoveredPointIndex] = useState<number>(-1)
  const [colorBy, setColorBy] = useState<PlannerColorBy>('grade')
  const { surfaceAt, lineColorAt } = useRouteSurfaceColors(route.tracks, colorBy)

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
      // The grade / surface switch of the route sheet (WEB-100 C1b), only once the route has its surface
      actions={
        hasSurfaces(route.tracks) && (
          <SegmentedControl
            size="xs"
            value={colorBy}
            onChange={(value) => setColorBy(value as PlannerColorBy)}
            aria-label={t('routes.surface.colorBy.label')}
            data={[
              { value: 'grade', label: t('routes.surface.colorBy.grade') },
              { value: 'surface', label: t('routes.surface.colorBy.surface') },
            ]}
            data-testid="route-fullscreen-color-by"
          />
        )
      }
      bottom={
        // Fixed elevation strip below the map (no overlap)
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
            zoom={{
              onMoveStart: onChartMoveStart,
              onMoveComplete: onChartMoveComplete,
            }}
          />
        </Box>
      }
    >
      <RouteTrackMap
        route={route}
        mapRef={mapRef}
        hoveredPointIndex={hoveredPointIndex}
        onHoverPoint={handleHoverPoint}
        fitPadding={50}
        lineColorAt={lineColorAt}
        onMoveStart={onMapMoveStart}
        onMoveEnd={onMapMoveEnd}
      />
    </MapFullscreenShell>
  )
}
