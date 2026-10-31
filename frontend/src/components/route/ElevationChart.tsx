import { forwardRef, useEffect, useImperativeHandle, useMemo, useRef, useState } from 'react'
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
  Plugin,
  ScriptableContext,
  ScriptableLineSegmentContext,
} from 'chart.js'
import { useTranslation } from 'react-i18next'
import { Box, Text, useMantineTheme } from '@mantine/core'
import { useDebouncedValue } from '@mantine/hooks'
import {
  NEUTRAL_COLOR,
  getColorFromGradient,
  elevationsInWindow,
  getElevationAxisBounds,
  getPointClimbGradient,
} from '../map/mapUtils'
import { crosshairPlugin, type ChartWithCrosshair } from './chartCrosshair'
import { waypointAt, waypointMarkersPlugin } from './waypointMarkersPlugin'
import { sortWaypoints, waypointTypeOf, waypointsNear } from '@/lib/waypoints'
import type { WaypointDto } from '@/api/dto'
import { useUnits } from '../../hooks/useUnits'
import { getOverlayBg } from '@/lib/colors'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { MappableRoute } from './RouteMapView'
import { breaksGradient, colorBreaks, sampleProfile, sampledIndexOf } from './profileSampling'
import {
  WIND_BAND_LABEL_PADDING,
  windBandColors,
  windBandPlugin,
  windBandRuns,
  type ProfileWind,
} from './windBand'
import { useWeatherLabels } from '../weather/useWeatherLabels'

// Register the shared Chart.js building blocks (line chart with fill + tooltip).
// chartjs-plugin-zoom is registered PER-INSTANCE (via the <Line plugins> prop) only when a
// consumer opts into zoom, so the embedded chart never pays for the zoom machinery.
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Filler)

/** Idle time after a zoom or pan before the profile is sampled for the new window. */
const SAMPLE_WINDOW_DEBOUNCE_MS = 250
/** Idle time after the last wheel notch or pinch step before a zoom gesture counts as complete. */
const ZOOM_COMPLETE_DEBOUNCE_MS = 250

/**
 * chartjs-plugin-zoom transitively imports hammerjs, which reads `window` at module load and
 * crashes SSR (the route's Suspense boundary falls back). Load it dynamically, client-side,
 * only when a chart opts into zoom; the chart remounts once it resolves (see the `key` on `<Line>`).
 */
function useZoomPlugin(enabled: boolean): Plugin<'line'> | null {
  const [plugin, setPlugin] = useState<Plugin<'line'> | null>(null)
  useEffect(() => {
    if (!enabled || plugin) return
    let cancelled = false
    void import('chartjs-plugin-zoom').then((module) => {
      if (!cancelled) setPlugin(() => module.default as Plugin<'line'>)
    })
    return () => {
      cancelled = true
    }
  }, [enabled, plugin])
  return plugin
}

/** Imperative controls for driving the chart x-range from a parent (used by the zoom-sync hook). */
export interface ElevationChartHandle {
  setXRange: (min: number, max: number) => void
  resetXRange: () => void
}

export interface ElevationChartProps {
  route: MappableRoute
  hoveredPointIndex: number
  onHoverPoint: (index: number) => void
  /** Fill each segment with its gradient color (prendslaroue look). Defaults to true. */
  filled?: boolean
  /** Draws the segment starting at this data index dashed (a straight line of the route planner). */
  dashedSegment?: (p0Index: number) => boolean
  /**
   * What colours the profile: the climb's grade (default) or, with `surfaceAt`, the surface of each
   * segment (route planner, WEB-100 C1a). The fill follows the line.
   */
  colorBy?: 'grade' | 'surface'
  /** The colour of the segment starting at this data index, when `colorBy` is `surface`. */
  surfaceAt?: (p0Index: number) => string
  /**
   * The Météo mode (ledger WEB-129): a band under the profile, tail / cross / head in the map's
   * colours, and the point's wind in the tooltip. The profile itself keeps `colorBy`.
   */
  wind?: ProfileWind
  /** The waypoint to highlight on the profile, if it is one of the route's. */
  selectedWaypoint?: WaypointDto | null
  /** A click on a waypoint marker of the profile. */
  onSelectWaypoint?: (waypoint: WaypointDto) => void
  /**
   * When provided, registers chartjs-plugin-zoom on this chart instance (wheel/pinch/pan, x-axis
   * only) and reports gesture boundaries so a parent can keep a map viewport in sync.
   */
  zoom?: {
    onMoveStart: () => void
    onMoveComplete: (min: number, max: number) => void
  }
}

export const ElevationChart = forwardRef<ElevationChartHandle, ElevationChartProps>(
  function ElevationChart(
    {
      route,
      hoveredPointIndex,
      onHoverPoint,
      filled = true,
      dashedSegment,
      colorBy = 'grade',
      surfaceAt,
      wind,
      selectedWaypoint = null,
      onSelectWaypoint,
      zoom,
    },
    ref
  ) {
    const { t } = useTranslation()
    const colorScheme = useResolvedColorScheme()
    const theme = useMantineTheme()
    const { config, distance: distanceFormat, elevation, formatDistance } = useUnits()
    const { relativeWind: relativeWindLabel } = useWeatherLabels()
    const chartRef = useRef<ChartJS<'line'>>(null)

    // Callbacks are read through refs inside chart event handlers so their (often per-render)
    // identities never invalidate the chart options/plugins — rebuilding the chart mid-gesture
    // swallows wheel/pan events and breaks zoom compounding.
    const zoomEnabled = !!zoom
    const onHoverPointRef = useRef(onHoverPoint)
    const zoomRef = useRef(zoom)
    const onSelectWaypointRef = useRef(onSelectWaypoint)
    useEffect(() => {
      onHoverPointRef.current = onHoverPoint
      onSelectWaypointRef.current = onSelectWaypoint
      zoomRef.current = zoom
    })

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

    // Flatten all track points and climbs from multiple tracks
    const trackPoints = useMemo(
      () => route.tracks.flatMap((track) => track.line.coordinates) || [],
      [route.tracks]
    )
    const climbs = useMemo(() => route.tracks.flatMap((track) => track.climbs), [route.tracks])
    const xs = useMemo(() => Float64Array.from(trackPoints, (p) => p[3]), [trackPoints])
    const ys = useMemo(() => Float64Array.from(trackPoints, (p) => p[2]), [trackPoints])

    // Waypoints on the track only: one that is off it (no distance) has no place on the profile.
    const markers = useMemo(
      () => sortWaypoints(route.waypoints ?? []).filter((w) => w.distance != null),
      [route.waypoints]
    )

    // Displayed x-range, null = full route extent. Held in state (not just mutated on the chart
    // instance) so re-renders that reapply the options — hover updates, theme changes — keep the
    // current zoom instead of silently resetting it.
    const [xRange, setXRangeState] = useState<{ min: number; max: number } | null>(null)
    // The range the chart shows right now: moved at every wheel notch and pan frame, where the
    // state above only follows once the gesture completes. The x options read it through getters,
    // at each chart.update, so a re-render committed mid-gesture never puts a stale range back.
    const liveRange = useRef<{ min: number; max: number } | null>(null)
    const followChart = (chart: ChartJS) => {
      liveRange.current = { min: chart.scales.x.min, max: chart.scales.x.max }
    }
    const completeTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
    const clearCompleteTimer = () => {
      if (completeTimer.current !== null) clearTimeout(completeTimer.current)
      completeTimer.current = null
    }
    // Once per gesture: records the range in state (sampling, y-axis) and hands it to the parent.
    const completeMove = (chart: ChartJS) => {
      clearCompleteTimer()
      followChart(chart)
      const { min, max } = chart.scales.x
      setXRangeState({ min, max })
      zoomRef.current?.onMoveComplete(min, max)
    }
    useEffect(() => clearCompleteTimer, [])

    // Imperative x-range control for zoom sync
    useImperativeHandle(
      ref,
      () => ({
        setXRange: (min: number, max: number) => {
          liveRange.current = { min, max }
          setXRangeState({ min, max })
        },
        resetXRange: () => {
          liveRange.current = null
          setXRangeState(null)
        },
      }),
      []
    )

    // The colour (and dash) of the segment starting at each point, worked out once: the scriptable
    // options below run per segment on every draw.
    const bySurface = colorBy === 'surface' && surfaceAt !== undefined
    const colors = useMemo(
      () =>
        trackPoints.map((p, i) =>
          bySurface ? surfaceAt(i) : getColorFromGradient(getPointClimbGradient(p, climbs))
        ),
      [trackPoints, climbs, bySurface, surfaceAt]
    )
    const dashed = useMemo(
      () => (dashedSegment ? trackPoints.map((_, i) => dashedSegment(i)) : null),
      [trackPoints, dashedSegment]
    )
    const styles = useMemo(
      () => (dashed ? colors.map((c, i) => (dashed[i] ? `${c} dashed` : c)) : colors),
      [colors, dashed]
    )

    // The points drawn, as indices into `trackPoints`: a long route is thinned to the resolution
    // of the strip, sampled again for the zoom window (profileSampling.ts). Every index the chart
    // hands back (data, tooltip, hover) goes through it.
    // Sampled again once the gesture settles, not at every wheel notch: the window's margin covers
    // the moves in between.
    const [sampleWindow] = useDebouncedValue(xRange, SAMPLE_WINDOW_DEBOUNCE_MS)

    // Fitted to what the zoom window shows, so a zoomed-in climb fills the strip — but on the
    // debounced window, once the gesture settles: an axis that rescales at every wheel notch or
    // pan frame makes the profile look like it's breathing.
    const yBounds = useMemo(
      () => getElevationAxisBounds(elevationsInWindow(xs, ys, sampleWindow)),
      [xs, ys, sampleWindow]
    )
    const sources = useMemo(
      () => sampleProfile(xs, ys, styles, sampleWindow),
      [xs, ys, styles, sampleWindow]
    )

    // Prepare chart data with per climb-part gradient coloring on a linear (distance-in-meters)
    // x-axis, which is what makes zoom sync against the map possible. The colours are a canvas
    // gradient with hard stops, built again only when the axis moves: one path to stroke and fill.
    // Dashes need per-segment styles; only the route planner draws them, on short routes.
    const breaks = useMemo(() => colorBreaks(xs, colors), [xs, colors])

    // The wind band, from the full-resolution points (never the thinned ones): each stretch starts
    // and ends at the distance of the very points the map colours, track by track.
    const trackSizes = useMemo(
      () => route.tracks.map((track) => track.line.coordinates.length),
      [route.tracks]
    )
    const windRuns = useMemo(
      () => (wind ? windBandRuns(xs, windBandColors(wind, xs.length), trackSizes) : null),
      [wind, xs, trackSizes]
    )
    const chartData: ChartData<'line'> = useMemo(() => {
      let cached: { key: string; gradient: CanvasGradient } | null = null
      const gradient = (context: ScriptableContext<'line'>) => {
        const { chart } = context
        const area = chart.chartArea
        const x = chart.scales?.x
        if (!area || !x) return colors[0] ?? NEUTRAL_COLOR
        const key = `${area.left} ${area.right} ${x.min} ${x.max}`
        if (cached?.key !== key) {
          cached = {
            key,
            gradient: breaksGradient(chart.ctx, breaks, area.left, area.right, (v) =>
              x.getPixelForValue(v)
            ),
          }
        }
        return cached.gradient
      }
      return {
        datasets: [
          {
            label: 'Elevation',
            data: sources.map((i) => ({ x: xs[i], y: ys[i] })),
            fill: filled,
            borderColor: gradient,
            backgroundColor: filled ? gradient : undefined,
            borderWidth: 2,
            pointRadius: 0,
            // Static, so Chart.js shares one options object across the (invisible) points instead
            // of resolving the scriptable gradient for each; the tooltip reads `colors` itself.
            pointBorderColor: NEUTRAL_COLOR,
            pointBackgroundColor: NEUTRAL_COLOR,
            segment: dashed
              ? {
                  borderDash: (ctx: ScriptableLineSegmentContext) =>
                    dashed[sources[ctx.p0DataIndex]] ? [6, 4] : undefined,
                }
              : undefined,
          },
        ],
      }
    }, [sources, xs, ys, colors, breaks, dashed, filled])

    const chartOptions: ChartOptions<'line'> = useMemo(
      () => ({
        responsive: true,
        maintainAspectRatio: false,
        // The points are already { x, y }, sorted by distance: no parsing, no sort check.
        parsing: false,
        normalized: true,
        interaction: {
          mode: 'index',
          intersect: false,
        },
        plugins: {
          legend: {
            display: false,
          },
          waypointMarkers: { markers, selected: selectedWaypoint },
          windBand: { runs: windRuns ?? [] },
          tooltip: {
            enabled: true,
            backgroundColor: chartColors.background,
            titleColor: chartColors.text,
            bodyColor: chartColors.text,
            borderColor: chartColors.grid,
            borderWidth: 1,
            callbacks: {
              title: (items: TooltipItem<'line'>[]) => {
                if (items.length > 0) {
                  const point = trackPoints[sources[items[0].dataIndex]]
                  return `${distanceFormat(point[3])}`
                }
                return ''
              },
              labelColor: (item: TooltipItem<'line'>) => {
                const color = colors[sources[item.dataIndex]] ?? NEUTRAL_COLOR
                return { borderColor: color, backgroundColor: color }
              },
              label: (item: TooltipItem<'line'>) => {
                const point = trackPoints[sources[item.dataIndex]]
                // Grade of the climb part the point falls in (matching prendslaroue's precision).
                const gradient = getPointClimbGradient(point, climbs)

                let label = `${elevation(item.parsed.y ?? 0)}`
                if (gradient !== 0) {
                  label += ` (${gradient.toFixed(1)}%)`
                }
                return label
              },
              // Climb index + per-part breakdown, à la prendslaroue:
              //   Montée (i/n) : <gain> / <length> (<avg>%)
              //   Partie (j/m) : <length> (<grade>%)
              // The waypoints about there: « Ravitaillement : Café du Port ».
              footer: (items: TooltipItem<'line'>[]) => {
                if (items.length === 0) return []
                const dist = xs[sources[items[0].dataIndex]]
                const x = xRange ?? { min: 0, max: route.distance }
                const tolerance = Math.max(50, (x.max - x.min) / 150)
                return waypointsNear(markers, dist, tolerance).map((w) => {
                  const type = t(`routes.waypoints.type.${waypointTypeOf(w.type)}`)
                  return w.name ? t('routes.waypoints.tooltipNamed', { type, name: w.name }) : type
                })
              },
              afterLabel: (item: TooltipItem<'line'>) => {
                const source = sources[item.dataIndex]
                const dist = xs[source]
                const lines: string[] = []
                // In words, never by the band's colour alone: « Vent de face »
                const kind = wind?.winds[source]
                // In the Météo mode only; a wind no stretch covers, or one this build does not know,
                // says so rather than leave the band's neutral blue unexplained.
                if (wind) {
                  const label = kind ? relativeWindLabel(kind) : ''
                  lines.push(label || t('rides.weather.relativeWindUnknown'))
                }

                for (let ci = 0; ci < climbs.length; ci++) {
                  const climb = climbs[ci]
                  if (dist < climb.startDistance || dist > climb.endDistance) continue

                  // docs/LEDGER_*.md API-10: a climb named by the waypoint at its top says so.
                  lines.push(
                    t(climb.name ? 'map.tooltip.climbNamed' : 'map.tooltip.climb', {
                      name: climb.name,
                      index: ci + 1,
                      total: climbs.length,
                      gain: elevation(climb.elevationGain),
                      distance: distanceFormat(climb.endDistance - climb.startDistance),
                      gradient: climb.averageGradient.toFixed(1),
                    })
                  )

                  if (climb.parts.length > 1) {
                    for (let pi = 0; pi < climb.parts.length; pi++) {
                      const part = climb.parts[pi]
                      if (dist < part.startDistance || dist > part.endDistance) continue
                      lines.push(
                        t('map.tooltip.part', {
                          index: pi + 1,
                          total: climb.parts.length,
                          distance: distanceFormat(part.endDistance - part.startDistance),
                          gradient: part.grade.toFixed(1),
                        })
                      )
                      break
                    }
                  }
                  break
                }
                return lines
              },
            },
          },
          ...(zoomEnabled
            ? {
                zoom: {
                  zoom: {
                    wheel: { enabled: true },
                    pinch: { enabled: true },
                    mode: 'x' as const,
                    onZoomStart: () => void zoomRef.current?.onMoveStart(),
                    // Not the plugin's onZoomComplete: its debounce is rebuilt at every chart
                    // update, so it fires once per wheel notch instead of once per gesture.
                    onZoom: ({ chart }: { chart: ChartJS }) => {
                      followChart(chart)
                      clearCompleteTimer()
                      completeTimer.current = setTimeout(
                        () => completeMove(chart),
                        ZOOM_COMPLETE_DEBOUNCE_MS
                      )
                    },
                  },
                  pan: {
                    enabled: true,
                    mode: 'x' as const,
                    onPanStart: () => void zoomRef.current?.onMoveStart(),
                    onPan: ({ chart }: { chart: ChartJS }) => followChart(chart),
                    onPanComplete: ({ chart }: { chart: ChartJS }) => completeMove(chart),
                  },
                  limits: {
                    x: { min: 0, max: route.distance, minRange: 1000 },
                  },
                },
              }
            : {}),
        },
        scales: {
          x: {
            type: 'linear',
            display: true,
            // Pin the axis to the route extent (or the synced zoom window) so the profile always
            // fills the strip instead of the axis auto-rounding past the last point.
            get min() {
              return liveRange.current?.min ?? 0
            },
            get max() {
              return liveRange.current?.max ?? route.distance
            },
            title: {
              display: true,
              text: `Distance (${config.distanceUnit})`,
              color: chartColors.text,
            },
            ticks: {
              maxTicksLimit: 10,
              color: chartColors.text,
              callback: (value: string | number) => formatDistance(Number(value)),
              // Room for the wind band between the plot and the labels, the tick marks off
              ...(windRuns ? { padding: WIND_BAND_LABEL_PADDING } : {}),
            },
            grid: {
              color: chartColors.grid,
              ...(windRuns ? { drawTicks: false } : {}),
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
              // The bounds are the route's raw min/max (-0.5 m…), never round numbers — let
              // Chart.js label only the round ticks it picks inside the range.
              includeBounds: false,
            },
            grid: {
              color: chartColors.grid,
            },
          },
        },
        onClick: (event: ChartEvent, _elements: ActiveElement[], chart: ChartJS) => {
          if (event.x == null) return
          const waypoint = waypointAt(markers, chart.scales.x, event.x)
          if (waypoint) onSelectWaypointRef.current?.(waypoint)
        },
        onHover: (event: ChartEvent, activeElements: ActiveElement[], chart: ChartJS) => {
          if (event.native && chart.canvas) {
            chart.canvas.style.cursor =
              event.x != null && waypointAt(markers, chart.scales.x, event.x) ? 'pointer' : ''
          }
          if (activeElements.length > 0) {
            const index = activeElements[0].index
            onHoverPointRef.current(sources[index])

            // Update crosshair position
            if (chartRef.current) {
              const chart = chartRef.current as ChartWithCrosshair
              const meta = chart.getDatasetMeta(0)
              const point = meta.data[index]
              if (point) {
                chart.crosshair = { x: point.x, color: chartColors.crosshair }
                chart.draw()
              }
            }
          }
        },
        // false, not a zero duration: with a duration Chart.js still builds an animation per
        // property of every point on each update — 10× the cost of the update itself.
        animation: false,
      }),
      [
        trackPoints,
        xs,
        sources,
        colors,
        climbs,
        chartColors,
        config,
        distanceFormat,
        elevation,
        formatDistance,
        zoomEnabled,
        route.distance,
        xRange,
        yBounds,
        t,
        markers,
        selectedWaypoint,
        wind,
        windRuns,
        relativeWindLabel,
      ]
    )

    // Update chart crosshair when hovering over the map (bidirectional cursor sync). A redraw, never
    // an update: the tooltip lays itself out in setActiveElements, and an update re-lays the whole
    // dataset out — on every mouse move.
    useEffect(() => {
      const chart = chartRef.current as ChartWithCrosshair | null
      if (!chart) return
      const index = sampledIndexOf(sources, xs, hoveredPointIndex)
      const point = index >= 0 ? chart.getDatasetMeta(0).data[index] : undefined
      if (point) {
        // At the hovered point's own distance, which the thinned profile may not carry.
        chart.crosshair = {
          x: chart.scales.x.getPixelForValue(xs[hoveredPointIndex]),
          color: chartColors.crosshair,
        }
        chart.tooltip?.setActiveElements([{ datasetIndex: 0, index }], { x: point.x, y: point.y })
      } else {
        chart.crosshair = null
        chart.tooltip?.setActiveElements([], { x: 0, y: 0 })
      }
      chart.draw()
    }, [hoveredPointIndex, chartColors.crosshair, sources, xs])

    const zoomPlugin = useZoomPlugin(zoomEnabled)
    const plugins = useMemo(
      () =>
        zoomEnabled && zoomPlugin
          ? [crosshairPlugin, waypointMarkersPlugin, windBandPlugin, zoomPlugin]
          : [crosshairPlugin, waypointMarkersPlugin, windBandPlugin],
      [zoomEnabled, zoomPlugin]
    )

    // docs/LEDGER_*.md WEB-80: react-chartjs-2 hands `plugins` to Chart.js only when it creates the chart, and the zoom
    // plugin resolves after the mount: without the remount the instance never carries it and the
    // wheel, pinch and pan do nothing. The x-range lives in this component's state, so the remount
    // keeps it. The empty-track guard lives in the parent; rendering with 0 points is harmless.
    // docs/LEDGER_*.md LEGAL-18: the elevations come from IGN's LiDAR HD (Licence Ouverte Etalab
    // 2.0, which requires naming the source) and Mapterhorn; the credit sits on the profile it covers.
    return (
      <Box pos="relative" h="100%" w="100%">
        <Line
          key={zoomPlugin ? 'zoom' : 'static'}
          ref={chartRef}
          data={chartData}
          options={chartOptions}
          plugins={plugins}
        />
        <Text pos="absolute" top={2} right={8} c="dimmed" fz={10} style={{ pointerEvents: 'none' }}>
          {t('map.elevationCredit')}
        </Text>
      </Box>
    )
  }
)
