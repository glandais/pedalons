import { useCallback, useRef, useMemo, useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Source,
  Layer,
  MapRef,
  MapMouseEvent,
  Marker,
  MarkerDragEvent,
  MapLayerTouchEvent,
} from 'react-map-gl/maplibre'
import { IconMaximize, IconTrash } from '@tabler/icons-react'
import { ActionIcon, Box, Button, Group, Loader, Menu, Skeleton, Stack, Text } from '@mantine/core'
import { useMediaMatch } from '@/hooks/useResponsive'
import { PedalonsMap } from '../map/PedalonsMap'
import { MapControlButton, MapControlGroup } from '../map/MapControl'
import { HideTrackControl } from '../map/HideTrackControl'
import { LocateControl } from '../map/LocateControl'
import { MapSearchControl, type SearchedPlace } from '../map/MapSearchControl'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { KmMarkersLayer } from '../map/MapMarkers'
import { routeArrowLayout } from '../map/routeArrowLayout'
import { UndoRedoControl } from './UndoRedoControl'
import { RouterProfileSelector } from './RouterProfileSelector'
import { PlannerHelpControl } from './PlannerHelpControl'
import { RoutePlannerMiniMap } from './RoutePlannerMiniMap'
import { PlannerStatus, PlannerStatusChip } from './PlannerStatus'
import { calculateBounds } from '../map/mapUtils'
import { useHideTrackKey } from '../../hooks/useHideTrackKey'
import { type RoutePlannerState } from '../../hooks/useRoutePlanner'
// maplibre-gl CSS is provided by maplibre-theme in index.css
import { legBounds, nearestSegment, Route, RoutePoint, spanBounds } from '@/lib/planner'
import { getOverlayBg } from '@/lib/colors'
import { isEditableTarget } from '@/lib/editableTarget'
import { isApplePlatform } from '@/lib/platform'
import { panelJustDismissed } from '@/components/map/mapPanelState'

const DEFAULT_ZOOM = 12

interface RoutePlannerProps {
  /** The planner's state, owned by the parent so it outlives this view being moved or hidden. */
  planner: RoutePlannerState
  /**
   * `inline`: in the form, with its status bar above the map. `fullscreen`: the map fills the
   * editor's dialog, the status lives in a chip (here on a mouse, in the parent on a finger).
   */
  layout: 'inline' | 'fullscreen'
  /**
   * Whether this view is on screen. A view kept mounted off-screen (a finger, fullscreen closed)
   * must not answer keyboard shortcuts: they would edit a route nobody sees.
   */
  active: boolean
  /** Given on a mouse, inline: adds the « Expand » button to the control column. */
  onExpand?: () => void
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  teamLocation?: [number, number] // [lng, lat] from team geometry
}

// The press is cancelled once the finger moves as far as maplibre needs to start a marker drag
// (the map's default clickTolerance), so the menu never opens on a press that became a drag.
const LONG_PRESS_MOVE_TOLERANCE_PX = 3
/** A finger grabs an anchor (the small white points of a loaded track) within this distance. */
const ANCHOR_TOUCH_RADIUS_PX = 22
/** An anchor grabbed but not moved further than this is a tap, not a drag. */
const ANCHOR_DRAG_TOLERANCE_PX = 3
/** After a long press opens the menu, the click its release may still produce is ignored this long. */
const LONG_PRESS_CLICK_GRACE_MS = 700

/** A long press on a finger opens the menu after this long without movement. */
const LONG_PRESS_MS = 500
/** A marker within this distance of the pointer has priority over the trace under it. */
const MARKER_PROXIMITY_PX = 20
/** A mouse targets an anchor within this distance (circle 5 px + 2 px stroke). */
const ANCHOR_CLICK_RADIUS_PX = 10

/** What the planner's menu is open on: a control point, or an anchor of a loaded track. */
type PlannerMenu =
  | { kind: 'marker'; x: number; y: number; idx: number; zoom: number }
  | {
      kind: 'anchor'
      x: number
      y: number
      start: RoutePoint
      end: RoutePoint
      direct: boolean
      /** The route the bounds were taken on: a menu left open over another route does nothing. */
      route: Route
    }

/**
 * Index of the visible anchor nearest `at` within `radiusPx`, or null (shared by a finger's touch
 * and a mouse's right click). Manual points are markers, not anchors; `importedOnly` also skips
 * the routed ones.
 */
function anchorAt(
  map: MapRef,
  route: Route,
  at: { x: number; y: number },
  radiusPx: number,
  zoom: number,
  importedOnly: boolean
): number | null {
  let grabbed: { idx: number; distance: number } | null = null
  for (let i = 0; i < route.points.length; i++) {
    const p = route.points[i]
    // The anchors the map shows at this zoom (the layer filter)
    if (p.manual || p.zoom > zoom || (importedOnly && !p.imported)) continue
    const projected = map.project([p.lng, p.lat])
    const distance = Math.hypot(projected.x - at.x, projected.y - at.y)
    if (distance < radiusPx && (!grabbed || distance < grabbed.distance)) {
      grabbed = { idx: i, distance }
    }
  }
  return grabbed ? grabbed.idx : null
}

/** A gesture came from a finger (or pen) when its event says so, whatever the device. */
function isTouchGesture(event: Event | undefined): boolean {
  if (!event) return false
  if (typeof TouchEvent !== 'undefined' && event instanceof TouchEvent) return true
  const pointerType = (event as PointerEvent).pointerType
  return pointerType === 'touch' || pointerType === 'pen'
}

/** Pointer type of the press that started the gesture; `click` itself does not always carry it. */
type PointerKind = 'mouse' | 'touch' | 'pen' | ''

export function RoutePlanner({
  planner,
  layout,
  active,
  onExpand,
  initialTrack,
  teamLocation,
}: RoutePlannerProps) {
  const { t } = useTranslation()
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
    removeAnchor,
    clearRoute,
    canUndo,
    canRedo,
    undo,
    redo,
  } = planner

  const getMapZoom = useCallback(() => mapRef.current?.getZoom() ?? DEFAULT_ZOOM, [])

  const defaultView = useDefaultMapView()

  // Press "h" to hide the trace and its markers, revealing the basemap underneath
  const [trackHidden, toggleTrackHidden] = useHideTrackKey(active)

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

    // Fit the whole trace in the frame. The container has its real size when the map is built, so
    // the ratio of the screen (a phone in portrait included) is respected.
    return {
      bounds: calculateBounds(initialTrack),
      fitBoundsOptions: { padding: 40, maxZoom: 15 },
    }
  }, [initialTrack, teamLocation, defaultView])

  // The map lives in a container that changes size when this view moves between the form and the
  // fullscreen dialog. MapLibre's own observer notices; this also covers the frame the container
  // is re-attached, whose size the observer reports a tick late.
  useEffect(() => {
    const frame = requestAnimationFrame(() => mapRef.current?.resize())
    return () => cancelAnimationFrame(frame)
  }, [layout])

  // A place found by the search or by « my position », offered as the start of an empty trace:
  // the first point costs no routing request. Only proposed while the trace is empty.
  const [startCandidate, setStartCandidate] = useState<{ lng: number; lat: number } | null>(null)
  const noPointYet = controlPoints.length === 0
  const noPointYetRef = useRef(noPointYet)
  useEffect(() => {
    noPointYetRef.current = noPointYet
    // Whatever way the first point comes (this button or a click), the proposal is spent.
    if (!noPointYet) setStartCandidate(null)
  }, [noPointYet])
  // Moving between the form and the editor drops a proposal left on the map.
  useEffect(() => {
    setStartCandidate(null)
  }, [layout])
  const proposeStart = useCallback((place: { lng: number; lat: number }) => {
    if (noPointYetRef.current) setStartCandidate({ lng: place.lng, lat: place.lat })
  }, [])
  const handleSearchSelected = useCallback(
    (place: SearchedPlace) => proposeStart(place),
    [proposeStart]
  )
  const handleStartHere = useCallback(() => {
    if (!startCandidate) return
    addControlPoint({ lng: startCandidate.lng, lat: startCandidate.lat }, false)
    setStartCandidate(null)
  }, [startCandidate, addControlPoint])

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
    /** Start index of the segment the ghost sits on */
    seg: number
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

  // Layout (mini-map, help text, sizes) follows the primary pointer. It says nothing about which
  // device fires a given gesture: a hybrid laptop keeps both mouse and finger, so each gesture
  // decides from its own event (see isTouchGesture).
  const isCoarsePointer = useMediaMatch('(pointer: coarse)')

  // Long-press context menu state
  const [contextMenu, setContextMenu] = useState<PlannerMenu | null>(null)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const longPressTouchStart = useRef<{ x: number; y: number } | null>(null)

  const lastPointerType = useRef<PointerKind>('')
  /**
   * The event comes from a finger or a pen: its own pointer type says so, or, for the events that
   * carry none (`click`, the compatibility `mousemove` of a tap), the last pointer seen on the map.
   */
  const isFingerEvent = useCallback((event: Event | undefined) => {
    if (isTouchGesture(event)) return true
    if ((event as PointerEvent | undefined)?.pointerType) return false
    return lastPointerType.current === 'touch' || lastPointerType.current === 'pen'
  }, [])
  const longPressOpenedAt = useRef(0)

  // A press on an imported anchor opens its menu after LONG_PRESS_MS (its own timer: the markers'
  // long press has others), and the touchend that follows must not become a click.
  const anchorPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const anchorMenuOpenedByPress = useRef(false)
  const clearAnchorPress = useCallback(() => {
    if (anchorPressTimer.current) clearTimeout(anchorPressTimer.current)
    anchorPressTimer.current = null
  }, [])

  const clearLongPress = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }
    longPressTouchStart.current = null
  }, [])

  // The long-press menu is portalled to body and this view outlives the fullscreen editor: when
  // the editor closes (browser back) or the view moves, the menu would hang on a detached target.
  useEffect(() => {
    setContextMenu(null)
    clearLongPress()
    clearAnchorPress()
    anchorMenuOpenedByPress.current = false
  }, [layout, active, clearLongPress, clearAnchorPress])

  const handleMarkerTouchStart = useCallback(
    (idx: number) => (event: React.TouchEvent) => {
      const touch = event.touches[0]
      // The zoom is frozen at the press: the delete acts on what the finger saw
      const zoom = getMapZoom()
      longPressTouchStart.current = { x: touch.clientX, y: touch.clientY }
      longPressTimer.current = setTimeout(() => {
        const rect = mapContainerRef.current?.getBoundingClientRect()
        const x = rect ? touch.clientX - rect.left : touch.clientX
        const y = rect ? touch.clientY - rect.top : touch.clientY
        setContextMenu({ kind: 'marker', x, y, idx, zoom })
        longPressOpenedAt.current = Date.now()
        longPressTimer.current = null
      }, LONG_PRESS_MS)
    },
    [getMapZoom]
  )

  const handleMarkerTouchMove = useCallback(
    (event: React.TouchEvent) => {
      if (!longPressTouchStart.current) return
      const touch = event.touches[0]
      const dx = touch.clientX - longPressTouchStart.current.x
      const dy = touch.clientY - longPressTouchStart.current.y
      if (Math.sqrt(dx * dx + dy * dy) >= LONG_PRESS_MOVE_TOLERANCE_PX) {
        clearLongPress()
      }
    },
    [clearLongPress]
  )

  const handleMarkerTouchEnd = useCallback(
    (event: React.TouchEvent) => {
      // The finger lifted off a press that opened the menu: cancel the click the browser would
      // synthesise from it, which would reach the map and close the menu it just opened.
      if (longPressTouchStart.current && !longPressTimer.current) event.preventDefault()
      clearLongPress()
    },
    [clearLongPress]
  )

  const handleContextMenuDelete = useCallback(() => {
    const m = contextMenu
    if (!m) return
    setContextMenu(null)
    if (m.kind === 'marker') {
      removeControlPoint(m.idx, directKeyRef.current, m.zoom)
    } else if (m.route === route) {
      removeAnchor(m.start, m.end, m.direct || directKeyRef.current)
    }
    // else: the route changed while the menu was open, its bounds are stale
  }, [contextMenu, removeControlPoint, removeAnchor, route])

  // Straight-line mode: held while Ctrl OR Alt is down (Ctrl+click is a right click on macOS, hence
  // Alt). Read from the modifier flags of every key event, so a missed keyup cannot leave it stuck,
  // and cleared when the window loses focus (Alt-Tab, a native dialog) since no keyup follows then.
  // Undo/redo shortcuts live here too, but never fire from a text field (native text undo there).
  const directKeyRef = useRef(false)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      directKeyRef.current = e.ctrlKey || e.altKey
      if (!active || isEditableTarget(e.target)) return
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
        e.preventDefault()
        if (e.shiftKey) redo()
        else undo()
      }
    }
    const handleKeyUp = (e: KeyboardEvent) => {
      directKeyRef.current = e.ctrlKey || e.altKey
    }
    const handleBlur = () => {
      directKeyRef.current = false
    }
    window.addEventListener('keydown', handleKeyDown)
    window.addEventListener('keyup', handleKeyUp)
    window.addEventListener('blur', handleBlur)
    return () => {
      window.removeEventListener('keydown', handleKeyDown)
      window.removeEventListener('keyup', handleKeyUp)
      window.removeEventListener('blur', handleBlur)
    }
  }, [undo, redo, active])

  const handleMarkerDragStart = useCallback(
    (idx: number) => (event: MarkerDragEvent) => {
      clearLongPress()
      setContextMenu(null)
      setDraggingMarker({ idx, lng: event.lngLat.lng, lat: event.lngLat.lat })
      const { start, end } = legBounds(route, idx - 1, idx + 1)
      setStartDragPoint(start)
      setEndDragPoint(end)
      setHoverPoint(null)
    },
    [route, clearLongPress]
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
      // A drag whose bounds were cleared (a second finger cancelled it) must not rebuild the route
      // around the moved point alone
      if (!startDragPoint && !endDragPoint && route.points.length > 1) {
        setDraggingMarker(null)
        return
      }
      updateControlPoint(
        startDragPoint,
        { lng: event.lngLat.lng, lat: event.lngLat.lat },
        endDragPoint,
        directKeyRef.current
      )
      setDraggingMarker(null)
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
    },
    [updateControlPoint, startDragPoint, endDragPoint, route]
  )

  const handleMarkerRightClick = useCallback(
    (index: number) => (event: React.MouseEvent) => {
      event.preventDefault()
      // A long press on a finger fires a native contextmenu too: the long-press menu handles it,
      // deleting here would remove the point (a billed request) under the menu that is opening.
      const native = event.nativeEvent as PointerEvent
      if (
        isTouchGesture(native) ||
        longPressTouchStart.current !== null ||
        Date.now() - longPressOpenedAt.current < 1000
      ) {
        return
      }
      // macOS turns Ctrl+click into a right click: that is the straight-line gesture, not a delete.
      if (isApplePlatform() && event.ctrlKey && native.button === 0) return
      removeControlPoint(index, directKeyRef.current, getMapZoom())
    },
    [removeControlPoint, getMapZoom]
  )

  // Right click on an imported anchor (a white point of a loaded track): offers to delete it. The
  // bounds are frozen now, at the zoom the pointer saw, and shown while the menu is open.
  const handleMapContextMenu = useCallback(
    (event: MapMouseEvent) => {
      const native = event.originalEvent
      // MapLibre's simulated long press, or a finger's native one: the finger has its own menu
      if (isFingerEvent(native)) return
      // A marker is a child of the map's container: its own handler owns the event
      // Only the control points and « Start here » are interactive: the hover ghost and the km
      // labels are markers too, but their wrapper must not swallow the click (same selector as the
      // touch start).
      if (
        (native.target as HTMLElement | null)?.closest?.(
          '.maplibregl-marker [role="button"], .planner-start-here'
        )
      ) {
        return
      }
      // macOS turns Ctrl+click into a right click: that is the straight-line gesture
      if (isApplePlatform() && native.ctrlKey && native.button === 0) return
      const map = mapRef.current
      if (isLoading || !map) return
      // A marker has priority over the anchor under it
      if (
        controlPoints.some((p) => {
          const projected = map.project([p.lng, p.lat])
          return (
            Math.hypot(projected.x - event.point.x, projected.y - event.point.y) <
            MARKER_PROXIMITY_PX
          )
        })
      ) {
        return
      }
      const zoom = getMapZoom()
      const i = anchorAt(map, route, event.point, ANCHOR_CLICK_RADIUS_PX, zoom, true)
      if (i === null) return
      const { start, end } = spanBounds(route, i - 1, i + 1, zoom)
      if (!start || !end) return
      native.preventDefault()
      const rect = mapContainerRef.current?.getBoundingClientRect()
      const x = rect ? native.clientX - rect.left : native.clientX
      const y = rect ? native.clientY - rect.top : native.clientY
      setHoverPoint(null)
      setContextMenu({
        kind: 'anchor',
        x,
        y,
        start,
        end,
        direct: native.altKey || (!isApplePlatform() && native.ctrlKey),
        route,
      })
    },
    [isFingerEvent, isLoading, controlPoints, getMapZoom, route]
  )

  const handleMapClick = useCallback(
    (event: MapMouseEvent) => {
      // One routing operation at a time: clicks during a calculation are dropped
      if (isLoading) return

      // The press that dismissed a map panel is not a point to add
      if (panelJustDismissed()) return

      // Nor is a click the browser may still derive from a finger's anchor drag
      if (Date.now() - anchorDragEndedAt.current < 400) return

      // Nor is the one on the « Start here » button (it adds the point itself, and stops the
      // click; this guard is the fallback should a click still come through)
      if ((event.originalEvent?.target as HTMLElement | null)?.closest?.('.planner-start-here')) {
        return
      }

      // Close context menu on any map click — but not on the click a long press ends with, should
      // the browser still emit one (touchend's preventDefault is the first line of defence)
      if (contextMenu && Date.now() - longPressOpenedAt.current < LONG_PRESS_CLICK_GRACE_MS) return
      if (contextMenu) {
        setContextMenu(null)
        return
      }

      // On touch: check if tap is near the route line for insertion
      const fromFinger = isFingerEvent(event.originalEvent)

      // A mouse over the trace inserts by dragging the ghost point, not by clicking
      if (hoverPoint && !fromFinger) return

      if (fromFinger && mapRef.current && routeGeoJson && route.points.length > 0) {
        const TOUCH_BUFFER_PX = 25
        const bbox: [[number, number], [number, number]] = [
          [event.point.x - TOUCH_BUFFER_PX, event.point.y - TOUCH_BUFFER_PX],
          [event.point.x + TOUCH_BUFFER_PX, event.point.y + TOUCH_BUFFER_PX],
        ]
        const features = mapRef.current.queryRenderedFeatures(bbox, {
          layers: ['route-line'],
        })
        if (features.length > 0) {
          const seg = nearestSegment(route, event.lngLat)
          if (seg) {
            const { start, end } = spanBounds(route, seg.index, seg.index + 1, getMapZoom())
            insertControlPoint(start, { lng: event.lngLat.lng, lat: event.lngLat.lat }, end, false)
            return
          }
        }
      }

      addControlPoint({ lng: event.lngLat.lng, lat: event.lngLat.lat }, directKeyRef.current)
    },
    [
      addControlPoint,
      hoverPoint,
      contextMenu,
      routeGeoJson,
      route,
      insertControlPoint,
      getMapZoom,
      isLoading,
      isFingerEvent,
    ]
  )

  const handleMouseMove = useCallback(
    (event: MapMouseEvent) => {
      if (!isCoarsePointer && !isTouchGesture(event.originalEvent)) {
        setCursorPosition({ lng: event.lngLat.lng, lat: event.lngLat.lat })
      }

      if (draggingGhost) {
        setDraggingGhost((prev) =>
          prev ? { ...prev, lng: event.lngLat.lng, lat: event.lngLat.lat } : null
        )
        return
      }

      if (draggingMarker) return

      // The ghost point is a mouse affordance (hover the trace, drag the ghost out). A tap sends a
      // compatibility mousemove before its click, with no pointer type of its own: showing the
      // ghost then would make the click below bail out, and the finger need a second tap on the
      // ghost to insert (seen on an iPhone). A finger inserts with one tap instead.
      if (isFingerEvent(event.originalEvent)) {
        if (hoverPoint) setHoverPoint(null)
        return
      }

      if (!mapRef.current || !routeGeoJson) return

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
        const seg = nearestSegment(route, event.lngLat)
        if (seg) {
          setHoverPoint({ lng: seg.point.lng, lat: seg.point.lat, seg: seg.index })
          return
        }
      }

      setHoverPoint(null)
    },
    [
      route,
      routeGeoJson,
      draggingGhost,
      draggingMarker,
      controlPoints,
      isCoarsePointer,
      isFingerEvent,
      hoverPoint,
    ]
  )

  const handleMouseLeave = useCallback(() => {
    setHoverPoint(null)
    setCursorPosition(null)
  }, [])

  const handleMapMouseDown = useCallback(
    (event: MapMouseEvent) => {
      if (event.originalEvent.button !== 0) return
      if (!hoverPoint || isLoading) return

      event.preventDefault()

      setDraggingGhost({
        lng: hoverPoint.lng,
        lat: hoverPoint.lat,
        idx: hoverPoint.seg,
      })
      const { start, end } = spanBounds(route, hoverPoint.seg, hoverPoint.seg + 1, getMapZoom())
      setStartDragPoint(start)
      setEndDragPoint(end)
      setHoverPoint(null)
    },
    [hoverPoint, getMapZoom, route, isLoading]
  )

  const handleMouseUp = useCallback(() => {
    if (draggingGhost) {
      insertControlPoint(
        startDragPoint,
        { lng: draggingGhost.lng, lat: draggingGhost.lat },
        endDragPoint,
        directKeyRef.current
      )
      setDraggingGhost(null)
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
    }
  }, [insertControlPoint, draggingGhost, startDragPoint, endDragPoint])

  // A finger drags an anchor the way a mouse drags the ghost point: the trace between the two
  // neighbouring anchors is routed again through where the finger lifts (two requests). Only a
  // press on an anchor starts it; anywhere else on the trace, the finger pans the map as usual.
  const anchorTouchStart = useRef<{ x: number; y: number } | null>(null)
  const anchorTouchMoved = useRef(false)
  const anchorDragEndedAt = useRef(0)
  // The finger's moves are read from its pointer events too: the browser holds back the touchmoves
  // of a touch whose touchstart it was not asked to cancel until they leave its slop (about 15 px),
  // so a short move would never stop the long press. The touchstart is left alone: its click is
  // what inserts a point on a tap.
  const lastTouchPointerId = useRef<number | null>(null)
  const anchorPointerId = useRef<number | null>(null)

  /** Follows the finger of an anchor press: past the tolerance it is a drag, never a long press. */
  const followAnchorPress = useCallback(
    (point: { x: number; y: number }) => {
      const start = anchorTouchStart.current
      const map = mapRef.current
      if (!start || !map) return
      if (Math.hypot(point.x - start.x, point.y - start.y) > ANCHOR_DRAG_TOLERANCE_PX) {
        anchorTouchMoved.current = true
        clearAnchorPress()
      }
      const { lng, lat } = map.unproject([point.x, point.y])
      setDraggingGhost((prev) => (prev ? { ...prev, lng, lat } : null))
    },
    [clearAnchorPress]
  )

  const handleAnchorPointerMove = useCallback(
    (event: React.PointerEvent) => {
      if (anchorPointerId.current === null || event.pointerId !== anchorPointerId.current) return
      const rect = mapRef.current?.getContainer().getBoundingClientRect()
      if (!rect) return
      followAnchorPress({ x: event.clientX - rect.left, y: event.clientY - rect.top })
    },
    [followAnchorPress]
  )

  const cancelAnchorDrag = useCallback(() => {
    clearAnchorPress()
    anchorTouchStart.current = null
    anchorPointerId.current = null
    anchorTouchMoved.current = false
    setDraggingGhost(null)
    setStartDragPoint(undefined)
    setEndDragPoint(undefined)
  }, [clearAnchorPress])

  const handleMapTouchStart = useCallback(
    (event: MapLayerTouchEvent) => {
      const map = mapRef.current
      if (!map) return
      // A second finger is a pinch or a pan: whatever the first one had started is over
      if (event.points.length !== 1) {
        clearAnchorPress()
        if (anchorTouchStart.current) cancelAnchorDrag()
        return
      }
      if (isLoading || draggingMarker) return
      // A control point is a marker of its own, with its own drag and long press; « Start here »
      // is a button. Other markers (the km labels) are mere labels: one may sit on an anchor, and
      // must not keep the finger from grabbing it.
      const target = event.originalEvent.target as HTMLElement | null
      if (target?.closest?.('.maplibregl-marker [role="button"], .planner-start-here')) return

      const zoom = getMapZoom()
      const grabbed = anchorAt(map, route, event.point, ANCHOR_TOUCH_RADIUS_PX, zoom, false)
      if (grabbed === null) return

      // The press is the anchor's: the map does not pan
      event.preventDefault()
      const anchor = route.points[grabbed]
      anchorTouchStart.current = { x: event.point.x, y: event.point.y }
      anchorPointerId.current = lastTouchPointerId.current
      anchorTouchMoved.current = false
      setDraggingGhost({ lng: anchor.lng, lat: anchor.lat, idx: grabbed })
      const { start, end } = spanBounds(route, grabbed - 1, grabbed + 1, zoom)
      setStartDragPoint(start)
      setEndDragPoint(end)

      // Held still on an imported anchor, the press opens its delete menu; the bounds are the
      // ones frozen now.
      clearAnchorPress()
      if (anchor.imported && start && end) {
        const touch = event.originalEvent.touches[0]
        anchorPressTimer.current = setTimeout(() => {
          anchorPressTimer.current = null
          anchorMenuOpenedByPress.current = true
          anchorTouchStart.current = null
          anchorPointerId.current = null
          anchorTouchMoved.current = false
          // The drag stops; its bounds stay, shown through the menu
          setDraggingGhost(null)
          setStartDragPoint(undefined)
          setEndDragPoint(undefined)
          const rect = mapContainerRef.current?.getBoundingClientRect()
          setContextMenu({
            kind: 'anchor',
            x: rect ? touch.clientX - rect.left : touch.clientX,
            y: rect ? touch.clientY - rect.top : touch.clientY,
            start,
            end,
            direct: false,
            route,
          })
          longPressOpenedAt.current = Date.now()
        }, LONG_PRESS_MS)
      }
    },
    [isLoading, draggingMarker, getMapZoom, route, clearAnchorPress, cancelAnchorDrag]
  )

  const handleMapTouchMove = useCallback(
    (event: MapLayerTouchEvent) => {
      if (event.points.length > 1) {
        clearAnchorPress()
        // Only what this gesture started: a marker drag has its own bounds, a pinch must not clear them
        if (anchorTouchStart.current) cancelAnchorDrag()
        return
      }
      if (!anchorTouchStart.current) return
      event.preventDefault()
      followAnchorPress(event.point)
    },
    [clearAnchorPress, cancelAnchorDrag, followAnchorPress]
  )

  const handleMapTouchEnd = useCallback(
    (event: MapLayerTouchEvent) => {
      if (anchorMenuOpenedByPress.current) {
        anchorMenuOpenedByPress.current = false
        // The browser's event, not MapLibre's: this is what cancels the click the touch would
        // synthesise, which would close the menu and insert a point
        event.originalEvent.preventDefault()
        return
      }
      clearAnchorPress()
      if (!anchorTouchStart.current) return
      if (anchorTouchMoved.current) {
        anchorDragEndedAt.current = Date.now()
        anchorTouchStart.current = null
        anchorPointerId.current = null
        anchorTouchMoved.current = false
        handleMouseUp()
      } else {
        // A tap on an anchor: no drag, the tap inserts a point there like anywhere on the trace
        cancelAnchorDrag()
      }
    },
    [handleMouseUp, cancelAnchorDrag, clearAnchorPress]
  )

  const handleMapTouchCancel = useCallback(() => {
    anchorMenuOpenedByPress.current = false
    cancelAnchorDrag()
  }, [cancelAnchorDrag])

  // A finger in the fullscreen editor: its tools are in the dialog's bottom bar, not on the map.
  const touchFullscreen = layout === 'fullscreen' && isCoarsePointer

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

  // While an anchor's menu is open its bounds show, joined by the line the delete would route
  const menuBounds = contextMenu?.kind === 'anchor' ? contextMenu : null
  const shownStart = startDragPoint ?? menuBounds?.start
  const shownEnd = endDragPoint ?? menuBounds?.end

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

    if (menuBounds) {
      return {
        dragConnectionLines: {
          type: 'FeatureCollection' as const,
          features: [
            {
              type: 'Feature' as const,
              geometry: {
                type: 'LineString' as const,
                coordinates: [
                  [menuBounds.start.lng, menuBounds.start.lat],
                  [menuBounds.end.lng, menuBounds.end.lat],
                ],
              },
              properties: {},
            },
          ],
        },
      }
    }

    return { dragConnectionLines: null }
  }, [draggingMarker, draggingGhost, startDragPoint, endDragPoint, menuBounds])

  return (
    <Stack gap={0} h="100%">
      {/* Compact toolbar: a fixed height (the tallest content, the clear button), so the map below
          is not resized when the first point makes the bar grow. Fullscreen has none: the dialog's
          toolbar and a status chip say the same. */}
      {layout === 'inline' && (
        <Group
          h={48}
          justify="space-between"
          align="center"
          wrap="nowrap"
          gap="sm"
          px="sm"
          bg="var(--mantine-color-body)"
          style={{ flexShrink: 0, borderBottom: '1px solid var(--mantine-color-default-border)' }}
        >
          <PlannerStatus
            pointCount={controlPoints.length}
            isLoading={isLoading}
            error={error}
            stats={route.points.length >= 2 ? routeStats : undefined}
          />
          {controlPoints.length > 0 && (
            <ActionIcon
              variant="subtle"
              color="gray"
              onClick={clearRoute}
              title={t('planner.clear')}
              aria-label={t('planner.clear')}
              style={{ flexShrink: 0 }}
            >
              <IconTrash size={14} />
            </ActionIcon>
          )}
        </Group>
      )}

      {/* Map */}
      <Box
        ref={mapContainerRef}
        onPointerDownCapture={(e: React.PointerEvent) => {
          lastPointerType.current = e.pointerType as PointerKind
          // Comes before its touchstart: the pointer an anchor press will follow
          if (e.pointerType === 'touch' || e.pointerType === 'pen') {
            lastTouchPointerId.current = e.pointerId
          }
        }}
        // Moves too: a mouse hovering after a finger tap must be recognised as a mouse again, and
        // the compatibility mousemove a tap produces (Safari sends one before its click) as a finger.
        onPointerMoveCapture={(e: React.PointerEvent) => {
          lastPointerType.current = e.pointerType as PointerKind
          handleAnchorPointerMove(e)
        }}
        onKeyDownCapture={(e: React.KeyboardEvent) => {
          // Inline, this map sits inside the editor's <form>: Enter in the search box would submit
          // it (implicit submission). The search box still gets the key and selects its result.
          if (e.key === 'Enter' && (e.target as HTMLElement).closest?.('.maplibre-search-box')) {
            e.preventDefault()
          }
        }}
        pos="relative"
        className={colorScheme === 'dark' ? 'dark' : undefined}
        style={{ flex: 1, minHeight: 0 }}
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
            onTouchStart={handleMapTouchStart}
            onTouchMove={handleMapTouchMove}
            onTouchEnd={handleMapTouchEnd}
            onTouchCancel={handleMapTouchCancel}
            onContextMenu={handleMapContextMenu}
            interactiveLayerIds={routeGeoJson ? ['route-line'] : []}
            cursor={
              isLoading
                ? 'progress'
                : draggingGhost || draggingMarker
                  ? 'grabbing'
                  : hoverPoint
                    ? 'pointer'
                    : 'crosshair'
            }
          >
            <MapSearchControl onResultSelected={handleSearchSelected} />

            {/* One shot, not tracked: it is only there to find where to start. */}
            <LocateControl
              onGeolocate={(e) => proposeStart({ lng: e.coords.longitude, lat: e.coords.latitude })}
            />

            {/* On a finger, fullscreen, undo / redo / profile / help live in the dialog's bottom
                bar (44 px targets): the column keeps the zoom and the basemap only. */}
            {!touchFullscreen && (
              <>
                <UndoRedoControl canUndo={canUndo} canRedo={canRedo} onUndo={undo} onRedo={redo} />

                <HideTrackControl hidden={trackHidden} onToggle={toggleTrackHidden} />

                <PlannerHelpControl />

                <RouterProfileSelector
                  currentProfile={routerProfile}
                  onProfileChange={setRouterProfile}
                />
              </>
            )}

            {onExpand && (
              <MapControlGroup>
                <MapControlButton
                  label={t('planner.expand')}
                  icon={<IconMaximize size={20} />}
                  onClick={onExpand}
                />
              </MapControlGroup>
            )}

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
                        // Bigger on a finger, which can grab them (handleMapTouchStart)
                        'circle-radius': isCoarsePointer ? 8 : 5,
                        'circle-color': 'white',
                        'circle-stroke-width': isCoarsePointer ? 3 : 2,
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
                      draggable={!isLoading}
                      onDragStart={handleMarkerDragStart(point.idx)}
                      onDrag={handleMarkerDrag(point.idx)}
                      onDragEnd={handleMarkerDragEnd()}
                    >
                      <Box
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                          cursor: isLoading ? 'progress' : isDragging ? 'grabbing' : 'grab',
                          width: 44,
                          height: 44,
                          pointerEvents: 'auto',
                        }}
                        role="button"
                        tabIndex={0}
                        onKeyDown={(e: React.KeyboardEvent) => {
                          if ((e.key === 'Delete' || e.key === 'Backspace') && !isLoading) {
                            e.preventDefault()
                            removeControlPoint(point.idx, directKeyRef.current, getMapZoom())
                          }
                        }}
                        aria-label={t('planner.marker.label', { index: index + 1 })}
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

                {/* « Start here »: offered on a found place while the trace is empty */}
                {startCandidate && noPointYet && (
                  <Marker
                    longitude={startCandidate.lng}
                    latitude={startCandidate.lat}
                    anchor="bottom"
                    className="planner-start-here"
                  >
                    <Stack gap={4} align="center">
                      <Button
                        size="xs"
                        onClick={(event) => {
                          // React listens on the marker's element (the portal it renders into),
                          // below MapLibre's listener on the canvas container. Stop the click
                          // here: the marker is gone once the point is added, so the map would
                          // see a detached target and add a second point of its own.
                          event.stopPropagation()
                          handleStartHere()
                        }}
                      >
                        {t('planner.startHere')}
                      </Button>
                      <Box
                        w={14}
                        h={14}
                        style={{
                          backgroundColor: 'var(--mantine-color-green-filled)',
                          border: '2px solid white',
                          borderRadius: '50%',
                          boxShadow: 'var(--mantine-shadow-md)',
                          marginBottom: -7,
                        }}
                      />
                    </Stack>
                  </Marker>
                )}

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
                {shownStart && (
                  <Marker
                    key={`bbox-boundary-start`}
                    longitude={shownStart.lng}
                    latitude={shownStart.lat}
                    anchor="center"
                  >
                    <Box
                      data-testid="planner-bound"
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
                {shownEnd && (
                  <Marker
                    key={`bbox-boundary-end`}
                    longitude={shownEnd.lng}
                    latitude={shownEnd.lat}
                    anchor="center"
                  >
                    <Box
                      data-testid="planner-bound"
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

        {/* Calculation in progress: the map is locked until the router answers */}
        {isLoading && (
          <Box
            pos="absolute"
            top="50%"
            left="50%"
            p="xs"
            bg={getOverlayBg(colorScheme)}
            role="status"
            aria-label={t('planner.calculating')}
            style={{
              transform: 'translate(-50%, -50%)',
              borderRadius: 'var(--mantine-radius-md)',
              boxShadow: 'var(--mantine-shadow-lg)',
              pointerEvents: 'none',
              zIndex: 10,
            }}
          >
            <Loader size="md" />
          </Box>
        )}

        {/* Long-press menu: a Mantine Menu anchored on a 1px target at the press point, so it
            portals out of the map and flips by itself near the edges */}
        <Menu
          opened={contextMenu !== null}
          onChange={(opened) => {
            if (!opened) setContextMenu(null)
          }}
          withinPortal
          position="top"
          middlewares={{ flip: true, shift: true }}
        >
          <Menu.Target>
            <Box
              pos="absolute"
              w={1}
              h={1}
              style={{
                left: contextMenu?.x ?? 0,
                top: contextMenu?.y ?? 0,
                pointerEvents: 'none',
              }}
            />
          </Menu.Target>
          <Menu.Dropdown>
            <Menu.Item
              color="red"
              leftSection={<IconTrash size={16} />}
              onClick={handleContextMenuDelete}
            >
              {t('planner.menu.delete')}
            </Menu.Item>
          </Menu.Dropdown>
        </Menu>

        {/* Mini-map: desktop only, follows cursor */}
        {!isCoarsePointer && cursorPosition && (
          <RoutePlannerMiniMap center={cursorPosition} routeGeoJson={routeGeoJson} />
        )}

        {/* Bottom centre: the status chip (fullscreen, mouse) and the first-use instructions. */}
        {(controlPoints.length === 0 || (layout === 'fullscreen' && !isCoarsePointer)) && (
          <Stack
            pos="absolute"
            bottom={16}
            left={16}
            right={16}
            gap="xs"
            align="center"
            style={{ pointerEvents: 'none' }}
          >
            {layout === 'fullscreen' &&
              !isCoarsePointer &&
              (controlPoints.length > 0 || isLoading || error) && (
                <PlannerStatusChip
                  pointCount={controlPoints.length}
                  isLoading={isLoading}
                  error={error}
                  stats={route.points.length >= 2 ? routeStats : undefined}
                />
              )}
            {controlPoints.length === 0 && (
              <Box
                px="md"
                py="xs"
                bg={getOverlayBg(colorScheme)}
                style={{
                  borderRadius: 'var(--mantine-radius-md)',
                  boxShadow: 'var(--mantine-shadow-lg)',
                }}
              >
                <Text size="sm" c="dimmed">
                  {isCoarsePointer ? t('planner.instructions.touch') : t('planner.instructions')}
                </Text>
              </Box>
            )}
          </Stack>
        )}
      </Box>
    </Stack>
  )
}
