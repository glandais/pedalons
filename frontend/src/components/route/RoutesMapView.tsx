import { useEffect, useState, useCallback, useRef, useMemo } from 'react'
import type { LngLatBoundsLike } from 'maplibre-gl'
import { Source, Layer, MapRef, MapMouseEvent, FullscreenControl } from 'react-map-gl/maplibre'
import { Line } from 'react-chartjs-2'
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Filler,
  ChartOptions,
  ChartData,
  ChartEvent,
  ActiveElement,
  TooltipItem,
} from 'chart.js'
import { useTranslation } from 'react-i18next'
import { Box, Center, Text, Paper, useMantineTheme } from '@mantine/core'
import { useMapHeight } from '@/hooks/useResponsive'
import { useRoutesBulk } from '@/hooks/useRoutesBulk'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { RouteDetailDto } from '@/api/dto'
import { StartMarker, EndMarker, HoverMarker } from '../map/MapMarkers'
import {
  calculateBounds,
  distance as haversineDistance,
  findNearestPoint,
  getElevationAxisBounds,
  routeToGeoJSON,
} from '../map/mapUtils'
import { crosshairPlugin, type ChartWithCrosshair } from './chartCrosshair'
import { PedalonsMap } from '../map/PedalonsMap'
import { HideTrackControl } from '../map/HideTrackControl'
import { routeArrowLayout } from '../map/routeArrowLayout'
import { useHideTrackKey } from '@/hooks/useHideTrackKey'
import { useUnits } from '../../hooks/useUnits'
import { getOverlayBg } from '@/lib/colors'
import { routeColor } from '@/lib/routeColors'
// maplibre-gl CSS is provided by maplibre-theme in index.css

// Register Chart.js components
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Filler)

/**
 * The chart overlay is 150px at the bottom; the extra bottom padding keeps the traces clear of it.
 * At the bottom rather than the top: on a phone it spans the map's width, and at the top it covered
 * the whole control column (zoom, basemaps, fullscreen).
 */
const ROUTES_FIT_PADDING = { top: 50, bottom: 170, left: 50, right: 50 } as const

// One item, one layer. The ride page passes one item per distinct route (`rideMapRoutes`); a trip
// stage carries the whole RouteDto, so TripDetailPage narrows it down to the slug.
export interface MapRouteItem {
  id: string
  name: string
  routeSlug?: string
}

interface RouteData {
  itemId: string
  itemName: string
  color: string
  route: RouteDetailDto
  trackPoints: number[][]
  distance: number
  elevationGain: number
}

export interface RoutesMapViewProps {
  items: MapRouteItem[]
  teamSlug: string
  highlightedItemId?: string | null
  onItemHover?: (itemId: string | null) => void
  /**
   * The clicked (selected) trace, when the page holds it — the ride page shares it with the group
   * cards. Left undefined, the map keeps its own.
   */
  selectedItemId?: string | null
  /** A trace was clicked or tapped: it selects it (highlight and profile), it never navigates. */
  onItemSelect?: (itemId: string) => void
  /** Map size variant: 'compact' for cards, 'standard' for detail pages, 'full' for full-screen */
  variant?: 'compact' | 'standard' | 'full'
}

export function RoutesMapView({
  items,
  teamSlug,
  highlightedItemId,
  onItemHover,
  selectedItemId,
  onItemSelect,
  variant = 'full',
}: RoutesMapViewProps) {
  const { t } = useTranslation()
  const mapHeight = useMapHeight(variant)
  const colorScheme = useResolvedColorScheme()
  const theme = useMantineTheme()
  const { config, distance, formatDistance, elevation } = useUnits()
  const mapRef = useRef<MapRef>(null)

  // Chart colors based on color scheme
  const chartColors = useMemo(
    () => ({
      text: colorScheme === 'dark' ? theme.colors.dark[0] : theme.colors.dark[7],
      grid: colorScheme === 'dark' ? theme.colors.dark[4] : theme.colors.gray[3],
      background: getOverlayBg(colorScheme, true),
      crosshair: colorScheme === 'dark' ? 'rgba(255, 255, 255, 0.3)' : 'rgba(0, 0, 0, 0.3)',
    }),
    [colorScheme, theme.colors.dark, theme.colors.gray]
  )
  const [ownSelectedRouteId, setSelectedRouteId] = useState<string | null>(null)
  const selectedRouteId = selectedItemId !== undefined ? selectedItemId : ownSelectedRouteId
  // Traces the visitor unticked in the basemap panel. Their layers stay mounted, hidden through
  // `visibility`, so the click handler's layer list never names a layer that is gone.
  const [hiddenItemIds, setHiddenItemIds] = useState<ReadonlySet<string>>(() => new Set())
  const toggleTrace = useCallback((itemId: string) => {
    setHiddenItemIds((previous) => {
      const next = new Set(previous)
      if (next.has(itemId)) next.delete(itemId)
      else next.add(itemId)
      return next
    })
  }, [])
  const [cursor, setCursor] = useState<string>('grab')

  // Press "h" (or the map control) to hide the traces and their markers, revealing the basemap
  const [tracksHidden, toggleTracksHidden] = useHideTrackKey()

  // Position cursor shared by the map and the profile, as an index into the *highlighted* route's
  // points. -1 = nothing hovered.
  const [hoveredPointIndex, setHoveredPointIndex] = useState(-1)
  const chartRef = useRef<ChartJS<'line'>>(null)

  // One bulk request for every distinct route slug on the screen, instead of one `getRoute`
  // per item (several ride groups, or every stage of a trip, often share the same route).
  // Slugs are deduped and the array is memoized on their sorted, joined value so the query
  // key — and so the request — stays stable across renders that don't actually change the set.
  const itemsWithRoutes = useMemo(() => items.filter((item) => item.routeSlug), [items])
  const dedupedSlugsKey = useMemo(
    () =>
      Array.from(new Set(itemsWithRoutes.map((item) => item.routeSlug!)))
        .sort()
        .join(','),
    [itemsWithRoutes]
  )
  const dedupedSlugs = useMemo(
    () => (dedupedSlugsKey ? dedupedSlugsKey.split(',') : []),
    [dedupedSlugsKey]
  )

  const { data: bulkData, isLoading } = useRoutesBulk(teamSlug, {
    slug: dedupedSlugs,
  })

  const routesBySlug = useMemo(() => {
    const map = new Map<string, RouteDetailDto>()
    for (const route of bulkData?.routes ?? []) {
      map.set(route.slug, route)
    }
    return map
  }, [bulkData])

  const routesData = useMemo<RouteData[]>(
    () =>
      itemsWithRoutes.flatMap((item, i) => {
        const routeDetail = routesBySlug.get(item.routeSlug!)
        if (!routeDetail) return []
        const trackPoints = routeDetail.tracks?.flatMap((track) => track.line.coordinates) || []
        if (trackPoints.length === 0) return []
        return [
          {
            itemId: item.id,
            itemName: item.name,
            color: routeColor(i),
            route: routeDetail,
            trackPoints,
            distance: routeDetail.distance,
            elevationGain: routeDetail.elevationGain,
          },
        ]
      }),
    [itemsWithRoutes, routesBySlug]
  )

  // The extent to open on. Prefer the server-computed `extent` (built from the same decimated
  // geometry actually returned) over recomputing it client-side from `routesData`. Available on the
  // very first render that has routes — `useRoutesBulk` reports `isLoading` until every chunk has
  // landed — so the map is framed by `initialViewState` and never has to snap afterwards.
  const routesBounds = useMemo<LngLatBoundsLike | null>(() => {
    if (routesData.length === 0) return null
    return bulkData?.extent
      ? ([
          [bulkData.extent.minLon, bulkData.extent.minLat],
          [bulkData.extent.maxLon, bulkData.extent.maxLat],
        ] satisfies LngLatBoundsLike)
      : calculateBounds(routesData.flatMap((r) => r.trackPoints))
  }, [routesData, bulkData])

  const fitBoundsToRoutes = useCallback(() => {
    if (mapRef.current && routesBounds) {
      mapRef.current.fitBounds(routesBounds, { padding: ROUTES_FIT_PADDING, duration: 0 })
    }
  }, [routesBounds])

  // Frame the map ONCE per route set. The first frame is `initialViewState`'s doing, so this only
  // catches a *later* change of route set (`keepPreviousData` keeps the map mounted across one).
  // After that the camera belongs to the visitor: hovering or clicking a trace re-renders this
  // component, and re-running fitBounds there would snap their zoom back to the whole-ride extent
  // mid-inspection.
  const framedSlugsKeyRef = useRef<string | null>(null)
  useEffect(() => {
    if (routesData.length === 0) return
    const firstFrame = framedSlugsKeyRef.current === null
    if (framedSlugsKeyRef.current === dedupedSlugsKey) return
    framedSlugsKeyRef.current = dedupedSlugsKey
    // The mount is already framed by `initialViewState` — refitting would only fight it.
    if (!firstFrame) fitBoundsToRoutes()
  }, [dedupedSlugsKey, routesData, fitBoundsToRoutes])

  const visibleRoutes = useMemo(
    () => routesData.filter((r) => !hiddenItemIds.has(r.itemId)),
    [routesData, hiddenItemIds]
  )

  // Derive highlighted route from props or selected state, among the traces on screen
  const highlightedRoute = useMemo(() => {
    // Priority: prop > selected > first route
    const targetId = highlightedItemId ?? selectedRouteId
    if (targetId) {
      return visibleRoutes.find((r) => r.itemId === targetId) ?? visibleRoutes[0] ?? null
    }
    return visibleRoutes[0] ?? null
  }, [highlightedItemId, selectedRouteId, visibleRoutes])

  // One checkbox per trace in the basemap panel, once there is more than one to choose from
  const traceOptions = useMemo(
    () =>
      routesData.length > 1
        ? routesData.map((r) => ({
            id: r.itemId,
            label: r.itemName,
            color: r.color,
            visible: !hiddenItemIds.has(r.itemId),
          }))
        : undefined,
    [routesData, hiddenItemIds]
  )

  const handlePolylineClick = useCallback(
    (itemId: string) => {
      setSelectedRouteId(itemId)
      onItemSelect?.(itemId)
      if (onItemHover) {
        onItemHover(itemId)
      }
    },
    [onItemHover, onItemSelect]
  )

  // Handle click on route layers
  const handleClick = useCallback(
    (event: MapMouseEvent) => {
      if (!mapRef.current) return

      const layerIds = routesData.map((r) => `line-${r.itemId}`)
      const features = mapRef.current.queryRenderedFeatures(event.point, { layers: layerIds })

      if (features.length > 0) {
        const clickedId = features[0].layer.id.replace('line-', '')
        handlePolylineClick(clickedId)
      }
    },
    [routesData, handlePolylineClick]
  )

  // Handle mouse enter on route layers
  const handleMouseEnter = useCallback(() => {
    setCursor('pointer')
  }, [])

  // Handle mouse leave. Falls back to the *clicked* route rather than to nothing: a click is a
  // deliberate selection, and this map keeps rendering it highlighted, so clearing the parent's
  // highlight here would leave the trace lit on the map and the matching card dimmed beside it.
  const handleMouseLeave = useCallback(() => {
    setCursor('grab')
    if (onItemHover) {
      onItemHover(selectedRouteId)
    }
  }, [onItemHover, selectedRouteId])

  // Move the position cursor along the highlighted route, within a tolerance proportional to the
  // viewport (same rule as the single-route map) so it snaps only when the pointer is near it.
  const handleMapMouseMove = useCallback(
    (event: MapMouseEvent) => {
      const points = highlightedRoute?.trackPoints
      if (!mapRef.current || !points || points.length === 0 || tracksHidden) return

      const bounds = mapRef.current.getBounds()
      const sw = bounds.getSouthWest()
      const ne = bounds.getNorthEast()
      const mapViewSize = haversineDistance(sw.lng, sw.lat, ne.lng, ne.lat)

      const nearestIndex = findNearestPoint(
        points,
        event.lngLat.lat,
        event.lngLat.lng,
        mapViewSize / 20.0
      )
      setHoveredPointIndex(nearestIndex)
    },
    [highlightedRoute, tracksHidden]
  )

  const clearHoveredPoint = useCallback(() => setHoveredPointIndex(-1), [])

  // A cursor held on the previous route's geometry would land anywhere on the new one
  useEffect(() => {
    setHoveredPointIndex(-1)
  }, [highlightedRoute?.itemId])

  // Map → profile: mirror the cursor as a crosshair + tooltip on the chart (profile → map goes the
  // other way, through the chart's own `onHover`).
  useEffect(() => {
    const chart = chartRef.current as ChartWithCrosshair | null
    if (!chart) return

    const point = hoveredPointIndex >= 0 ? chart.getDatasetMeta(0).data[hoveredPointIndex] : null
    if (point) {
      chart.crosshair = { x: point.x, color: chartColors.crosshair }
      chart.tooltip?.setActiveElements([{ datasetIndex: 0, index: hoveredPointIndex }], {
        x: point.x,
        y: point.y,
      })
    } else {
      chart.crosshair = null
      chart.tooltip?.setActiveElements([], { x: 0, y: 0 })
    }
    chart.update()
  }, [hoveredPointIndex, chartColors.crosshair])

  // Create GeoJSON data for each route
  const routeGeoJSONs = useMemo(() => {
    return routesData.map((route) => ({
      itemId: route.itemId,
      color: route.color,
      geojson: routeToGeoJSON(route.route, { id: route.itemId }),
    }))
  }, [routesData])

  // Interactive layer IDs for hover detection
  const interactiveLayerIds = useMemo(() => {
    return routesData.map((r) => `line-${r.itemId}`)
  }, [routesData])

  // Prepare chart data from highlighted route
  const chartData: ChartData<'line'> | null = highlightedRoute
    ? {
        labels: highlightedRoute.trackPoints.map((p) => formatDistance(p[3])),
        datasets: [
          {
            label: 'Elevation',
            data: highlightedRoute.trackPoints.map((p) => p[2]),
            fill: true,
            backgroundColor: `${highlightedRoute.color}33`,
            borderColor: highlightedRoute.color,
            borderWidth: 2,
            pointRadius: 0,
            tension: 0.1,
          },
        ],
      }
    : null

  const yBounds = useMemo(
    () =>
      highlightedRoute
        ? getElevationAxisBounds(highlightedRoute.trackPoints.map((p) => p[2]))
        : null,
    [highlightedRoute]
  )

  const chartOptions: ChartOptions<'line'> = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false,
      },
      plugins: {
        legend: {
          display: false,
        },
        tooltip: {
          enabled: true,
          backgroundColor: chartColors.background,
          titleColor: chartColors.text,
          bodyColor: chartColors.text,
          borderColor: chartColors.grid,
          borderWidth: 1,
          callbacks: {
            title: (tooltipItems: TooltipItem<'line'>[]) => {
              if (tooltipItems.length > 0 && highlightedRoute) {
                const index = tooltipItems[0].dataIndex
                const point = highlightedRoute.trackPoints[index]
                return `${distance(point[3])}`
              }
              return ''
            },
            label: (item: TooltipItem<'line'>) => {
              return `${elevation(item.parsed.y ?? 0)}`
            },
          },
        },
      },
      scales: {
        x: {
          display: true,
          title: {
            display: true,
            text: `Distance (${config.distanceUnit})`,
            color: chartColors.text,
          },
          ticks: {
            maxTicksLimit: 10,
            color: chartColors.text,
          },
          grid: {
            color: chartColors.grid,
          },
        },
        y: {
          display: true,
          min: yBounds?.min,
          max: yBounds?.max,
          title: {
            display: true,
            text: `Elevation (${config.elevationUnit})`,
            color: chartColors.text,
          },
          ticks: {
            color: chartColors.text,
            // The bounds are the route's raw min/max, never round numbers — let Chart.js label
            // only the round ticks it picks inside the range.
            includeBounds: false,
          },
          grid: {
            color: chartColors.grid,
          },
        },
      },
      // Profile → map: the marker follows the point under the pointer, and leaving the strip
      // (Chart.js reports no active element) drops it.
      onHover: (_event: ChartEvent, activeElements: ActiveElement[]) => {
        setHoveredPointIndex(activeElements.length > 0 ? activeElements[0].index : -1)
      },
      animation: { duration: 0 },
    }),
    [chartColors, highlightedRoute, config, distance, elevation, yBounds]
  )

  if (isLoading) {
    return (
      <Center
        w="100%"
        h={mapHeight}
        bg="var(--mantine-color-default-hover)"
        style={{ borderRadius: 'var(--mantine-radius-sm)' }}
      >
        <Text c="dimmed">{t('loading')}</Text>
      </Center>
    )
  }

  if (routesData.length === 0) {
    return (
      <Center
        w="100%"
        h={mapHeight}
        bg="var(--mantine-color-default-hover)"
        style={{ borderRadius: 'var(--mantine-radius-sm)' }}
      >
        <Text c="dimmed">{t(`map.noRoutes`)}</Text>
      </Center>
    )
  }

  const hoveredPoint =
    hoveredPointIndex >= 0 ? (highlightedRoute?.trackPoints[hoveredPointIndex] ?? null) : null

  // Start and end markers: the first shown route's first point, the last shown route's last point
  const firstRoute = visibleRoutes[0]
  const lastRoute = visibleRoutes[visibleRoutes.length - 1]
  const startPoint = firstRoute?.trackPoints[0]
  const endPoint = lastRoute?.trackPoints[lastRoute.trackPoints.length - 1]

  return (
    <Box
      style={{
        border: '1px solid var(--mantine-color-default-border)',
        borderRadius: 'var(--mantine-radius-sm)',
        overflow: 'hidden',
      }}
    >
      {/* Map container */}
      <Box
        pos="relative"
        w="100%"
        h={mapHeight}
        className={colorScheme === 'dark' ? 'map-stack dark' : 'map-stack'}
        style={{ zIndex: 0 }}
      >
        <PedalonsMap
          ref={mapRef}
          initialViewState={{
            bounds: routesBounds ?? undefined,
            fitBoundsOptions: { padding: ROUTES_FIT_PADDING },
          }}
          cursor={cursor}
          onClick={handleClick}
          onMouseEnter={handleMouseEnter}
          onMouseLeave={handleMouseLeave}
          onMouseMove={handleMapMouseMove}
          onMouseOut={clearHoveredPoint}
          interactiveLayerIds={tracksHidden ? [] : interactiveLayerIds}
          traces={traceOptions}
          onTraceToggle={toggleTrace}
        >
          <HideTrackControl hidden={tracksHidden} onToggle={toggleTracksHidden} />

          {/* Room to tell a dozen overlaid traces apart. Fullscreens the map container only, so the
              elevation overlay — a sibling of the map, not a child — stays out of it. */}
          <FullscreenControl position="top-left" />

          {tracksHidden ? null : (
            <>
              {/* Render all routes */}
              {routeGeoJSONs.map((route) => {
                const isHighlighted = highlightedRoute?.itemId === route.itemId
                const visibility = hiddenItemIds.has(route.itemId) ? 'none' : 'visible'

                return (
                  <Source
                    key={`source-${route.itemId}`}
                    id={`route-${route.itemId}`}
                    type="geojson"
                    data={route.geojson}
                  >
                    <Layer
                      id={`line-${route.itemId}`}
                      type="line"
                      layout={{ visibility }}
                      paint={{
                        'line-color': route.color,
                        'line-width': isHighlighted ? 8 : 5,
                        'line-opacity': isHighlighted ? 0.9 : 0.5,
                      }}
                    />
                    {/* Which way the route runs: chevrons along it, in the order of its points */}
                    <Layer
                      id={`arrows-${route.itemId}`}
                      type="symbol"
                      layout={{ ...routeArrowLayout, visibility }}
                    />
                  </Source>
                )
              })}

              {startPoint && <StartMarker longitude={startPoint[0]} latitude={startPoint[1]} />}
              {endPoint && <EndMarker longitude={endPoint[0]} latitude={endPoint[1]} />}

              {/* Position cursor, shared with the elevation profile */}
              {hoveredPoint && (
                <HoverMarker longitude={hoveredPoint[0]} latitude={hoveredPoint[1]} />
              )}
            </>
          )}
        </PedalonsMap>

        {/* Elevation chart overlay, bottom-left: the control column is top-left, and the narrow
            width on a phone leaves the attribution's ⓘ (bottom-right) uncovered. */}
        {chartData && (
          <Paper
            pos="absolute"
            bottom={0}
            left={0}
            w={{ base: 'calc(100% - 40px)', sm: '50%', md: '40%' }}
            h={{ base: 120, sm: 140, md: 150 }}
            shadow="lg"
            style={{ zIndex: 1000, pointerEvents: 'auto', backgroundColor: chartColors.background }}
          >
            <Line
              ref={chartRef}
              data={chartData}
              options={chartOptions}
              plugins={[crosshairPlugin]}
            />
          </Paper>
        )}
      </Box>
    </Box>
  )
}
