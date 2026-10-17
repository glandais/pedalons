import { useCallback, useRef, useMemo, useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Source,
  Layer,
  MapRef,
  MapMouseEvent,
  Marker,
  MarkerDragEvent,
} from 'react-map-gl/maplibre'
import { IconTrash } from '@tabler/icons-react'
import { ActionIcon, Box, Group, Loader, Skeleton, Stack, Text } from '@mantine/core'
import { PedalonsMap } from '../map/PedalonsMap'
import { HideTrackControl } from '../map/HideTrackControl'
import { MapSearchControl } from '../map/MapSearchControl'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { KmMarkersLayer } from '../map/MapMarkers'
import { routeArrowLayout } from '../map/routeArrowLayout'
import { UndoRedoControl } from './UndoRedoControl'
import { RouterProfileSelector } from './RouterProfileSelector'
import { RoutePlannerMiniMap } from './RoutePlannerMiniMap'
import { useUnits } from '../../hooks/useUnits'
import { useHideTrackKey } from '../../hooks/useHideTrackKey'
import {
  useRoutePlanner,
  findAnchorStartPoint,
  findAnchorEndPoint,
} from '../../hooks/useRoutePlanner'
import type { GeoPoint } from '@/api/dto'
// maplibre-gl CSS is provided by maplibre-theme in index.css
import { RoutePoint } from '@/lib/planner'
import { getOverlayBg } from '@/lib/colors'
import { around } from 'geokdbush'

const DEFAULT_ZOOM = 12

interface RoutePlannerProps {
  onPointsChange: (points: GeoPoint[]) => void
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  teamLocation?: [number, number] // [lng, lat] from team geometry
}

export function RoutePlanner({ onPointsChange, initialTrack, teamLocation }: RoutePlannerProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const colorScheme = useResolvedColorScheme()
  const mapRef = useRef<MapRef>(null)
  const mapContainerRef = useRef<HTMLDivElement>(null)

  const {
    route,
    controlPoints,
    routeGeoJson,
    isLoading,
    error,
    routerProfile,
    setRouterProfile,
    addControlPoint,
    insertControlPoint,
    updateControlPoint,
    removeControlPoint,
    clearRoute,
    canUndo,
    canRedo,
    undo,
    redo,
  } = useRoutePlanner({ initialTrack })

  const getMapZoom = useCallback(() => mapRef.current?.getZoom() ?? DEFAULT_ZOOM, [])

  const defaultView = useDefaultMapView()

  // Press "h" to hide the trace and its markers, revealing the basemap underneath
  const [trackHidden, toggleTrackHidden] = useHideTrackKey()

  // Calculate initial view state from track bounds, team location, or the server's default centre.
  // Null while none of the three is known yet — the map waits rather than opening somewhere wrong.
  const initialViewState = useMemo(() => {
    if (!initialTrack || initialTrack.length === 0) {
      if (teamLocation) {
        return { longitude: teamLocation[0], latitude: teamLocation[1], zoom: DEFAULT_ZOOM }
      }
      // Keeps the served zoom: a site pinned to one team opens tighter than a whole deployment.
      return defaultView
    }

    // Calculate bounds
    let minLng = Infinity,
      maxLng = -Infinity,
      minLat = Infinity,
      maxLat = -Infinity
    for (const coord of initialTrack) {
      minLng = Math.min(minLng, coord[0])
      maxLng = Math.max(maxLng, coord[0])
      minLat = Math.min(minLat, coord[1])
      maxLat = Math.max(maxLat, coord[1])
    }

    // Center and approximate zoom
    const centerLng = (minLng + maxLng) / 2
    const centerLat = (minLat + maxLat) / 2
    const lngSpan = maxLng - minLng
    const latSpan = maxLat - minLat
    const maxSpan = Math.max(lngSpan, latSpan)

    // Approximate zoom level based on span
    let zoom = 12
    if (maxSpan > 1) zoom = 7
    else if (maxSpan > 0.5) zoom = 8
    else if (maxSpan > 0.2) zoom = 9
    else if (maxSpan > 0.1) zoom = 10
    else if (maxSpan > 0.05) zoom = 11

    return {
      longitude: centerLng,
      latitude: centerLat,
      zoom,
    }
  }, [initialTrack, teamLocation, defaultView])

  // Notify parent when route changes - pass the complete computed path
  useEffect(() => {
    if (!routeGeoJson || routeGeoJson.coordinates.length < 2) {
      onPointsChange([])
      return
    }
    const allPoints: GeoPoint[] = routeGeoJson.coordinates.map((coords) => ({
      lng: coords[0],
      lat: coords[1],
    }))
    onPointsChange(allPoints)
  }, [routeGeoJson, onPointsChange])

  // Cursor position for mini-map (desktop only)
  const [cursorPosition, setCursorPosition] = useState<{ lng: number; lat: number } | null>(null)

  // State for effective start on edition
  const [startDragPoint, setStartDragPoint] = useState<RoutePoint | undefined>(undefined)

  // State for effective end on edition
  const [endDragPoint, setEndDragPoint] = useState<RoutePoint | undefined>(undefined)

  // State for hover marker on route segments
  const [hoverPoint, setHoverPoint] = useState<{
    lng: number
    lat: number
    idx: number
  } | null>(null)

  // State for dragging a ghost point (before insertion)
  const [draggingGhost, setDraggingGhost] = useState<{
    lng: number
    lat: number
    idx: number
  } | null>(null)

  // Track which marker is being dragged and its current position
  const [draggingMarker, setDraggingMarker] = useState<{
    lng: number
    lat: number
    idx: number
  } | null>(null)

  // Touch device detection
  const [isTouchDevice] = useState(() => typeof window !== 'undefined' && 'ontouchstart' in window)

  // Long-press context menu state
  const [contextMenu, setContextMenu] = useState<{
    x: number
    y: number
    idx: number
  } | null>(null)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const longPressTouchStart = useRef<{ x: number; y: number } | null>(null)

  const clearLongPress = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }
    longPressTouchStart.current = null
  }, [])

  const handleMarkerTouchStart = useCallback(
    (idx: number) => (event: React.TouchEvent) => {
      const touch = event.touches[0]
      longPressTouchStart.current = { x: touch.clientX, y: touch.clientY }
      longPressTimer.current = setTimeout(() => {
        const rect = mapContainerRef.current?.getBoundingClientRect()
        const x = rect ? touch.clientX - rect.left : touch.clientX
        const y = rect ? touch.clientY - rect.top : touch.clientY
        setContextMenu({ x, y, idx })
        longPressTimer.current = null
      }, 500)
    },
    []
  )

  const handleMarkerTouchMove = useCallback(
    (event: React.TouchEvent) => {
      if (!longPressTouchStart.current) return
      const touch = event.touches[0]
      const dx = touch.clientX - longPressTouchStart.current.x
      const dy = touch.clientY - longPressTouchStart.current.y
      if (Math.sqrt(dx * dx + dy * dy) > 10) {
        clearLongPress()
      }
    },
    [clearLongPress]
  )

  const handleMarkerTouchEnd = useCallback(() => {
    clearLongPress()
  }, [clearLongPress])

  const handleContextMenuDelete = useCallback(() => {
    if (!contextMenu) return
    removeControlPoint(contextMenu.idx, ctrlKeyRef.current, getMapZoom())
    setContextMenu(null)
  }, [contextMenu, removeControlPoint, getMapZoom])

  // Track Ctrl key state for direct line mode + undo/redo shortcuts
  const ctrlKeyRef = useRef(false)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Control') ctrlKeyRef.current = true
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
        e.preventDefault()
        undo()
      }
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && e.shiftKey) {
        e.preventDefault()
        redo()
      }
    }
    const handleKeyUp = (e: KeyboardEvent) => {
      if (e.key === 'Control') ctrlKeyRef.current = false
    }
    window.addEventListener('keydown', handleKeyDown)
    window.addEventListener('keyup', handleKeyUp)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      window.removeEventListener('keyup', handleKeyUp)
    }
  }, [undo, redo])

  const handleMarkerDragStart = useCallback(
    (idx: number) => (event: MarkerDragEvent) => {
      setDraggingMarker({ idx, lng: event.lngLat.lng, lat: event.lngLat.lat })
      const zoom = getMapZoom()
      setStartDragPoint(findAnchorStartPoint(route, idx, zoom))
      setEndDragPoint(findAnchorEndPoint(route, idx, zoom))
      setHoverPoint(null)
    },
    [route, getMapZoom]
  )

  const handleMarkerDrag = useCallback(
    (idx: number) => (event: MarkerDragEvent) => {
      setDraggingMarker((prev) =>
        prev && prev.idx === idx ? { idx, lng: event.lngLat.lng, lat: event.lngLat.lat } : prev
      )
    },
    []
  )

  const handleMarkerDragEnd = useCallback(
    () => (event: MarkerDragEvent) => {
      updateControlPoint(
        startDragPoint,
        { lng: event.lngLat.lng, lat: event.lngLat.lat },
        endDragPoint,
        ctrlKeyRef.current
      )
      setDraggingMarker(null)
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
    },
    [updateControlPoint, startDragPoint, endDragPoint]
  )

  const handleMarkerRightClick = useCallback(
    (index: number) => (event: React.MouseEvent) => {
      event.preventDefault()
      removeControlPoint(index, ctrlKeyRef.current, getMapZoom())
    },
    [removeControlPoint, getMapZoom]
  )

  const handleMapClick = useCallback(
    (event: MapMouseEvent) => {
      // Close context menu on any map click
      if (contextMenu) {
        setContextMenu(null)
        return
      }

      if (hoverPoint) return

      // On touch: check if tap is near the route line for insertion
      if (isTouchDevice && mapRef.current && routeGeoJson && route.points.length > 0) {
        const TOUCH_BUFFER_PX = 25
        const bbox: [[number, number], [number, number]] = [
          [event.point.x - TOUCH_BUFFER_PX, event.point.y - TOUCH_BUFFER_PX],
          [event.point.x + TOUCH_BUFFER_PX, event.point.y + TOUCH_BUFFER_PX],
        ]
        const features = mapRef.current.queryRenderedFeatures(bbox, {
          layers: ['route-line'],
        })
        if (features.length > 0) {
          const nearestIds = around(route.index, event.lngLat.lng, event.lngLat.lat, 1, 1)
          if (nearestIds.length === 1) {
            const nearestId = nearestIds[0]
            const zoom = getMapZoom()
            const start = findAnchorStartPoint(route, nearestId, zoom)
            const end = findAnchorEndPoint(route, nearestId, zoom)
            insertControlPoint(start, { lng: event.lngLat.lng, lat: event.lngLat.lat }, end, false)
            return
          }
        }
      }

      addControlPoint({ lng: event.lngLat.lng, lat: event.lngLat.lat }, ctrlKeyRef.current)
    },
    [
      addControlPoint,
      hoverPoint,
      contextMenu,
      routeGeoJson,
      route,
      insertControlPoint,
      getMapZoom,
      isTouchDevice,
    ]
  )

  const handleMouseMove = useCallback(
    (event: MapMouseEvent) => {
      if (!isTouchDevice) {
        setCursorPosition({ lng: event.lngLat.lng, lat: event.lngLat.lat })
      }

      if (draggingGhost) {
        setDraggingGhost((prev) =>
          prev ? { ...prev, lng: event.lngLat.lng, lat: event.lngLat.lat } : null
        )
        return
      }

      if (draggingMarker) return

      if (!mapRef.current || !routeGeoJson) return

      const MARKER_PROXIMITY_PX = 20
      for (const point of controlPoints) {
        const projected = mapRef.current.project([point.lng, point.lat])
        const dx = projected.x - event.point.x
        const dy = projected.y - event.point.y
        const distance = Math.sqrt(dx * dx + dy * dy)
        if (distance < MARKER_PROXIMITY_PX) {
          setHoverPoint(null)
          return
        }
      }

      const ROUTE_BUFFER_PX = 15
      const bbox: [[number, number], [number, number]] = [
        [event.point.x - ROUTE_BUFFER_PX, event.point.y - ROUTE_BUFFER_PX],
        [event.point.x + ROUTE_BUFFER_PX, event.point.y + ROUTE_BUFFER_PX],
      ]
      const features = mapRef.current.queryRenderedFeatures(bbox, {
        layers: ['route-line'],
      })

      if (features.length > 0) {
        const nearestIds = around(route.index, event.lngLat.lng, event.lngLat.lat, 1, 1)
        if (nearestIds.length === 1) {
          const nearestId = nearestIds[0]
          setHoverPoint({
            lng: route.points[nearestId].lng,
            lat: route.points[nearestId].lat,
            idx: nearestIds[0],
          })
          return
        }
      }

      setHoverPoint(null)
    },
    [route, routeGeoJson, draggingGhost, draggingMarker, controlPoints, isTouchDevice]
  )

  const handleMouseLeave = useCallback(() => {
    setHoverPoint(null)
    setCursorPosition(null)
  }, [])

  const handleMapMouseDown = useCallback(
    (event: MapMouseEvent) => {
      if (event.originalEvent.button !== 0) return
      if (!hoverPoint) return

      event.preventDefault()

      setDraggingGhost({
        lng: hoverPoint.lng,
        lat: hoverPoint.lat,
        idx: hoverPoint.idx,
      })
      const zoom = getMapZoom()
      setStartDragPoint(findAnchorStartPoint(route, hoverPoint.idx, zoom))
      setEndDragPoint(findAnchorEndPoint(route, hoverPoint.idx, zoom))
      setHoverPoint(null)
    },
    [hoverPoint, getMapZoom, route]
  )

  const handleMouseUp = useCallback(() => {
    if (draggingGhost) {
      insertControlPoint(
        startDragPoint,
        { lng: draggingGhost.lng, lat: draggingGhost.lat },
        endDragPoint,
        ctrlKeyRef.current
      )
      setDraggingGhost(null)
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
    }
  }, [insertControlPoint, draggingGhost, startDragPoint, endDragPoint])

  const routeStats = {
    distance: route.dist,
    ascend: route.ascend,
  }

  // Anchor points: non-manual simplified route points, each tagged with their min zoom level.
  // The MapLibre filter [">=", ["zoom"], ["get", "zoom"]] shows them natively as the map zooms.
  const anchorGeoJson = useMemo(() => {
    if (!routeGeoJson) return null
    return {
      type: 'FeatureCollection' as const,
      features: route.points
        .filter((p) => !p.manual)
        .map((p) => ({
          type: 'Feature' as const,
          geometry: { type: 'Point' as const, coordinates: [p.lng, p.lat] },
          properties: { zoom: p.zoom },
        })),
    }
  }, [route.points, routeGeoJson])

  // Compute connection lines and boundary points when dragging
  const { dragConnectionLines } = useMemo(() => {
    // Connection lines for dragging existing marker
    if (draggingMarker || draggingGhost) {
      const { lng, lat } = (draggingMarker || draggingGhost)!
      const features: GeoJSON.Feature<GeoJSON.LineString>[] = []

      if (startDragPoint) {
        features.push({
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [startDragPoint.lng, startDragPoint.lat],
              [lng, lat],
            ],
          },
          properties: {},
        })
      }

      if (endDragPoint) {
        features.push({
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [lng, lat],
              [endDragPoint.lng, endDragPoint.lat],
            ],
          },
          properties: {},
        })
      }

      return {
        dragConnectionLines: { type: 'FeatureCollection' as const, features },
      }
    }

    return { dragConnectionLines: null }
  }, [draggingMarker, draggingGhost, startDragPoint, endDragPoint])

  return (
    <Stack gap={0} h="100%">
      {/* Compact toolbar */}
      <Group
        justify="space-between"
        px="sm"
        py="xs"
        bg="var(--mantine-color-body)"
        style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}
      >
        <Group>
          {controlPoints.length > 0 && (
            <Text size="sm" c="dimmed">
              {t('planner.pointCount', { count: controlPoints.length })}
            </Text>
          )}
          {isLoading && (
            <Group gap="xs" c="primary">
              <Loader size="xs" />
              <Text size="sm">{t('planner.calculating')}</Text>
            </Group>
          )}
          {error && (
            <Text size="sm" c="red">
              {error}
            </Text>
          )}
          {route.points.length >= 2 && (
            <Group gap="xs">
              <Text size="sm" fw={500}>
                {distance(routeStats.distance)}
              </Text>
              <Text size="sm" c="green">
                +{elevation(routeStats.ascend)}
              </Text>
            </Group>
          )}
        </Group>
        {controlPoints.length > 0 && (
          <ActionIcon variant="subtle" color="gray" onClick={clearRoute} title={t('planner.clear')}>
            <IconTrash size={14} />
          </ActionIcon>
        )}
      </Group>

      {/* Map */}
      <Box
        ref={mapContainerRef}
        pos="relative"
        className={colorScheme === 'dark' ? 'dark' : undefined}
        style={{ flex: 1 }}
      >
        {!initialViewState ? (
          // No track, no team location, and /api/config hasn't said where to open yet.
          <Skeleton h="100%" w="100%" radius={0} />
        ) : (
          <PedalonsMap
            ref={mapRef}
            initialViewState={initialViewState}
            onClick={handleMapClick}
            onMouseDown={handleMapMouseDown}
            onMouseMove={handleMouseMove}
            onMouseLeave={handleMouseLeave}
            onMouseUp={handleMouseUp}
            interactiveLayerIds={routeGeoJson ? ['route-line'] : []}
            cursor={draggingGhost ? 'grabbing' : hoverPoint ? 'pointer' : 'crosshair'}
          >
            <MapSearchControl />

            <UndoRedoControl canUndo={canUndo} canRedo={canRedo} onUndo={undo} onRedo={redo} />

            <HideTrackControl hidden={trackHidden} onToggle={toggleTrackHidden} />

            <RouterProfileSelector
              currentProfile={routerProfile}
              onProfileChange={setRouterProfile}
            />

            {!trackHidden && (
              <>
                {/* Route line */}
                {routeGeoJson && (
                  <Source id="route" type="geojson" data={routeGeoJson}>
                    <Layer
                      id="route-line"
                      type="line"
                      paint={{
                        'line-color': '#4F46E5',
                        'line-width': 5,
                        'line-opacity': 0.8,
                      }}
                    />
                    <Layer id="route-arrows" type="symbol" layout={routeArrowLayout} />
                  </Source>
                )}

                {/* Anchor points: visible at their computed min zoom level */}
                {anchorGeoJson && (
                  <Source id="anchors" type="geojson" data={anchorGeoJson}>
                    <Layer
                      id="anchor-points"
                      type="circle"
                      filter={['>=', ['zoom'], ['get', 'zoom']]}
                      paint={{
                        'circle-radius': 5,
                        'circle-color': 'white',
                        'circle-stroke-width': 2,
                        'circle-stroke-color': '#4F46E5',
                        'circle-opacity': 0.9,
                      }}
                    />
                  </Source>
                )}

                {/* Km markers */}
                {routeGeoJson && route.dist > 0 && (
                  <KmMarkersLayer coords={routeGeoJson.coordinates} totalDistanceM={route.dist} />
                )}

                {/* Drag connection lines */}
                {dragConnectionLines && (
                  <Source id="drag-connections" type="geojson" data={dragConnectionLines}>
                    <Layer
                      id="drag-connection-line"
                      type="line"
                      paint={{
                        'line-color': '#10B981',
                        'line-width': 3,
                        'line-dasharray': [4, 4],
                        'line-opacity': 1,
                      }}
                    />
                  </Source>
                )}

                {/* Control point markers */}
                {controlPoints.map((point, index) => {
                  const isFirst = index === 0
                  const isLast = index === controlPoints.length - 1 && controlPoints.length > 1

                  let markerColor = 'var(--mantine-color-blue-filled)'
                  if (isFirst) markerColor = 'var(--mantine-color-green-filled)'
                  else if (isLast) markerColor = 'var(--mantine-color-red-filled)'

                  // Use dragging position if this marker is being dragged
                  const isDragging = draggingMarker?.idx === point.idx
                  const lng = isDragging ? draggingMarker.lng : point.lng
                  const lat = isDragging ? draggingMarker.lat : point.lat

                  return (
                    <Marker
                      key={point.id}
                      longitude={lng}
                      latitude={lat}
                      anchor="center"
                      draggable
                      onDragStart={handleMarkerDragStart(point.idx)}
                      onDrag={handleMarkerDrag(point.idx)}
                      onDragEnd={handleMarkerDragEnd()}
                    >
                      <Box
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: 'grab',
                          width: 44,
                          height: 44,
                          pointerEvents: 'auto',
                        }}
                        onContextMenu={handleMarkerRightClick(point.idx)}
                        onTouchStart={handleMarkerTouchStart(point.idx)}
                        onTouchMove={handleMarkerTouchMove}
                        onTouchEnd={handleMarkerTouchEnd}
                      >
                        <Box
                          w={24}
                          h={24}
                          style={{
                            backgroundColor: markerColor,
                            border: '2px solid white',
                            borderRadius: '50%',
                            boxShadow: 'var(--mantine-shadow-lg)',
                          }}
                        />
                      </Box>
                    </Marker>
                  )
                })}

                {/* Ghost marker for inserting new points on route */}
                {(hoverPoint || draggingGhost) && (
                  <Marker
                    longitude={(draggingGhost || hoverPoint)!.lng}
                    latitude={(draggingGhost || hoverPoint)!.lat}
                    anchor="center"
                  >
                    <Box
                      w={20}
                      h={20}
                      style={{
                        backgroundColor: draggingGhost
                          ? 'var(--mantine-primary-color-filled)'
                          : 'var(--mantine-primary-color-light-color)',
                        border: '2px solid white',
                        borderRadius: '50%',
                        boxShadow: 'var(--mantine-shadow-lg)',
                        opacity: draggingGhost ? 1 : 0.7,
                        pointerEvents: 'none',
                        transition: 'opacity 150ms',
                      }}
                    />
                  </Marker>
                )}

                {/* Bbox boundary markers showing effective start/end during drag */}
                {startDragPoint && (
                  <Marker
                    key={`bbox-boundary-start`}
                    longitude={startDragPoint.lng}
                    latitude={startDragPoint.lat}
                    anchor="center"
                  >
                    <Box
                      w={14}
                      h={14}
                      style={{
                        backgroundColor: '#10B981',
                        border: '2px solid white',
                        borderRadius: '50%',
                        boxShadow: 'var(--mantine-shadow-sm)',
                        pointerEvents: 'none',
                      }}
                    />
                  </Marker>
                )}
                {endDragPoint && (
                  <Marker
                    key={`bbox-boundary-end`}
                    longitude={endDragPoint.lng}
                    latitude={endDragPoint.lat}
                    anchor="center"
                  >
                    <Box
                      w={14}
                      h={14}
                      style={{
                        backgroundColor: '#10B981',
                        border: '2px solid white',
                        borderRadius: '50%',
                        boxShadow: 'var(--mantine-shadow-sm)',
                        pointerEvents: 'none',
                      }}
                    />
                  </Marker>
                )}
              </>
            )}
          </PedalonsMap>
        )}

        {/* Long-press context menu for touch devices */}
        {contextMenu && (
          <Box
            pos="absolute"
            px="xs"
            py={4}
            bg="var(--mantine-color-body)"
            style={{
              left: contextMenu.x,
              top: contextMenu.y,
              transform: 'translate(-50%, -120%)',
              zIndex: 10,
              borderRadius: 'var(--mantine-radius-md)',
              boxShadow: 'var(--mantine-shadow-md)',
              border: '1px solid var(--mantine-color-default-border)',
            }}
          >
            <Group
              gap="xs"
              style={{ cursor: 'pointer' }}
              c="red"
              onClick={handleContextMenuDelete}
              px="xs"
              py={6}
            >
              <IconTrash size={16} />
              <Text size="sm">{t('planner.menu.delete')}</Text>
            </Group>
          </Box>
        )}

        {/* Mini-map: desktop only, follows cursor */}
        {!isTouchDevice && cursorPosition && (
          <RoutePlannerMiniMap center={cursorPosition} routeGeoJson={routeGeoJson} />
        )}

        {/* Instructions overlay */}
        {controlPoints.length === 0 && (
          <Box
            pos="absolute"
            bottom={16}
            left="50%"
            px="md"
            py="xs"
            bg={getOverlayBg(colorScheme)}
            style={{
              transform: 'translateX(-50%)',
              borderRadius: 'var(--mantine-radius-md)',
              boxShadow: 'var(--mantine-shadow-lg)',
            }}
          >
            <Text size="sm" c="dimmed">
              {isTouchDevice ? t('planner.instructions.touch') : t('planner.instructions')}
            </Text>
          </Box>
        )}
      </Box>
    </Stack>
  )
}
