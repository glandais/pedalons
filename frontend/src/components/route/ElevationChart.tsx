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
import {
  NEUTRAL_COLOR,
  getColorFromGradient,
  getElevationAxisBounds,
  getPointClimbGradient,
} from '../map/mapUtils'
import { crosshairPlugin, type ChartWithCrosshair } from './chartCrosshair'
import { useUnits } from '../../hooks/useUnits'
import { getOverlayBg } from '@/lib/colors'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { MappableRoute } from './RouteMapView'

// Register the shared Chart.js building blocks (line chart with fill + tooltip).
// chartjs-plugin-zoom is registered PER-INSTANCE (via the <Line plugins> prop) only when a
// consumer opts into zoom, so the embedded chart never pays for the zoom machinery.
ChartJS.register(CategoryScale, LinearScale, PointElement, LineElement, Title, Tooltip, Filler)

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
  function ElevationChart({ route, hoveredPointIndex, onHoverPoint, filled = true, zoom }, ref) {
    const { t } = useTranslation()
    const colorScheme = useResolvedColorScheme()
    const theme = useMantineTheme()
    const { config, distance: distanceFormat, elevation, formatDistance } = useUnits()
    const chartRef = useRef<ChartJS<'line'>>(null)

    // Callbacks are read through refs inside chart event handlers so their (often per-render)
    // identities never invalidate the chart options/plugins — rebuilding the chart mid-gesture
    // swallows wheel/pan events and breaks zoom compounding.
    const zoomEnabled = !!zoom
    const onHoverPointRef = useRef(onHoverPoint)
    const zoomRef = useRef(zoom)
    useEffect(() => {
      onHoverPointRef.current = onHoverPoint
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

    // Computed over the whole route, never the zoom window: an axis that rescales under a pan
    // gesture makes the profile look like it's breathing.
    const yBounds = useMemo(
      () => getElevationAxisBounds(trackPoints.map((p) => p[2])),
      [trackPoints]
    )

    // Displayed x-range, null = full route extent. Held in state (not just mutated on the chart
    // instance) so re-renders that reapply the options — hover updates, theme changes — keep the
    // current zoom instead of silently resetting it.
    const [xRange, setXRangeState] = useState<{ min: number; max: number } | null>(null)

    // Imperative x-range control for zoom sync
    useImperativeHandle(
      ref,
      () => ({
        setXRange: (min: number, max: number) => setXRangeState({ min, max }),
        resetXRange: () => setXRangeState(null),
      }),
      []
    )

    // Prepare chart data with per climb-part gradient coloring on a linear (distance-in-meters)
    // x-axis, which is what makes zoom sync against the map possible.
    const chartData: ChartData<'line'> = useMemo(
      () => ({
        datasets: [
          {
            label: 'Elevation',
            data: trackPoints.map((p) => ({ x: p[3], y: p[2] })),
            fill: filled,
            borderColor: (context: ScriptableContext<'line'>) => {
              const index = context.dataIndex
              if (index === undefined) return NEUTRAL_COLOR
              const gradient = getPointClimbGradient(trackPoints[index], climbs)
              return getColorFromGradient(gradient)
            },
            borderWidth: 2,
            pointRadius: 0,
            segment: {
              backgroundColor: filled
                ? (ctx: ScriptableLineSegmentContext) => {
                    const gradient = getPointClimbGradient(trackPoints[ctx.p0DataIndex], climbs)
                    return getColorFromGradient(gradient)
                  }
                : undefined,
              borderColor: (ctx: ScriptableLineSegmentContext) => {
                const gradient = getPointClimbGradient(trackPoints[ctx.p0DataIndex], climbs)
                return getColorFromGradient(gradient)
              },
            },
          },
        ],
      }),
      [trackPoints, climbs, filled]
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
              title: (items: TooltipItem<'line'>[]) => {
                if (items.length > 0) {
                  const index = items[0].dataIndex
                  const point = trackPoints[index]
                  return `${distanceFormat(point[3])}`
                }
                return ''
              },
              label: (item: TooltipItem<'line'>) => {
                const index = item.dataIndex
                const point = trackPoints[index]
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
              afterLabel: (item: TooltipItem<'line'>) => {
                const dist = trackPoints[item.dataIndex][3]
                const lines: string[] = []

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
                    onZoomComplete: ({ chart }: { chart: ChartJS }) => {
                      // Record the plugin-driven range so re-renders don't undo the gesture.
                      setXRangeState({ min: chart.scales.x.min, max: chart.scales.x.max })
                      zoomRef.current?.onMoveComplete(chart.scales.x.min, chart.scales.x.max)
                    },
                  },
                  pan: {
                    enabled: true,
                    mode: 'x' as const,
                    onPanStart: () => void zoomRef.current?.onMoveStart(),
                    onPanComplete: ({ chart }: { chart: ChartJS }) => {
                      setXRangeState({ min: chart.scales.x.min, max: chart.scales.x.max })
                      zoomRef.current?.onMoveComplete(chart.scales.x.min, chart.scales.x.max)
                    },
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
            min: xRange?.min ?? 0,
            max: xRange?.max ?? route.distance,
            title: {
              display: true,
              text: `Distance (${config.distanceUnit})`,
              color: chartColors.text,
            },
            ticks: {
              maxTicksLimit: 10,
              color: chartColors.text,
              callback: (value: string | number) => formatDistance(Number(value)),
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
              // The bounds are the route's raw min/max (-0.5 m…), never round numbers — let
              // Chart.js label only the round ticks it picks inside the range.
              includeBounds: false,
            },
            grid: {
              color: chartColors.grid,
            },
          },
        },
        onHover: (_event: ChartEvent, activeElements: ActiveElement[]) => {
          if (activeElements.length > 0) {
            const index = activeElements[0].index
            onHoverPointRef.current(index)

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
        animation: { duration: 0 },
      }),
      [
        trackPoints,
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
      ]
    )

    // Update chart crosshair when hovering over the map (bidirectional cursor sync)
    useEffect(() => {
      if (chartRef.current && hoveredPointIndex >= 0) {
        const chart = chartRef.current as ChartWithCrosshair
        const meta = chart.getDatasetMeta(0)
        const point = meta.data[hoveredPointIndex]
        if (point) {
          chart.crosshair = { x: point.x, color: chartColors.crosshair }
          chart.draw()

          // Show tooltip
          chart.tooltip?.setActiveElements([{ datasetIndex: 0, index: hoveredPointIndex }], {
            x: point.x,
            y: point.y,
          })
          chart.update()
        }
      } else if (chartRef.current) {
        const chart = chartRef.current as ChartWithCrosshair
        chart.crosshair = null
        chart.tooltip?.setActiveElements([], { x: 0, y: 0 })
        chart.update()
      }
    }, [hoveredPointIndex, chartColors.crosshair])

    const zoomPlugin = useZoomPlugin(zoomEnabled)
    const plugins = useMemo(
      () => (zoomEnabled && zoomPlugin ? [crosshairPlugin, zoomPlugin] : [crosshairPlugin]),
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
