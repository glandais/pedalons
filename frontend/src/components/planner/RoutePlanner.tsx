import { useCallback, useRef, useMemo, useState, useEffect } from 'react'
import { flushSync } from 'react-dom'
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
import {
  IconFileImport,
  IconFlagFilled,
  IconMapPinPlus,
  IconMaximize,
  IconPlayerPlayFilled,
  IconTrash,
} from '@tabler/icons-react'
import {
  ActionIcon,
  Box,
  Button,
  Group,
  Loader,
  Menu,
  Skeleton,
  Stack,
  Text,
  useMantineTheme,
} from '@mantine/core'
import { useMediaMatch } from '@/hooks/useResponsive'
import { PedalonsMap } from '../map/PedalonsMap'
import { MapControlButton, MapControlGroup } from '../map/MapControl'
import { HideTrackControl } from '../map/HideTrackControl'
import { LocateControl } from '../map/LocateControl'
import { MapSearchControl, type SearchedPlace } from '../map/MapSearchControl'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import { useDefaultMapView } from '@/hooks/useDefaultMapView'
import { useMapStyle } from '@/hooks/useMapStyle'
import { HoverMarker, KmMarkersLayer } from '../map/MapMarkers'
import { routeArrowLayout } from '../map/routeArrowLayout'
import type { ExpressionSpecification } from 'maplibre-gl'
import { surfaceColors } from '@/lib/plannerSurface'
import { DirectModeControl } from './DirectModeControl'
import { UndoRedoControl } from './UndoRedoControl'
import { RouterProfileSelector } from './RouterProfileSelector'
import { PlannerHelpControl } from './PlannerHelpControl'
import { RoutePlannerMiniMap } from './RoutePlannerMiniMap'
import { PlannerStatus, PlannerStatusChip } from './PlannerStatus'
import { calculateBounds } from '../map/mapUtils'
import { useHideTrackKey } from '../../hooks/useHideTrackKey'
import { useEdgeAutoPan } from '../../hooks/useEdgeAutoPan'
import { useKeyboardPointMove } from '../../hooks/useKeyboardPointMove'
import { markerRole } from './plannerMarker'
import { EDGE_PAN_ZONE_PX } from '@/lib/edgePan'
import { type RoutePlannerState } from '../../hooks/useRoutePlanner'
// maplibre-gl CSS is provided by maplibre-theme in index.css
import {
  cumulativeDistances,
  legBounds,
  nearestSegment,
  Point,
  Route,
  RoutePoint,
  spanBounds,
} from '@/lib/planner'
import {
  locateOnRoute,
  MAX_WAYPOINTS,
  projectOnRoute,
  type WaypointPlacement,
} from '@/lib/plannerWaypoints'
import { PlannerWaypointMarker } from './PlannerWaypointMarker'
import { getOverlayBg } from '@/lib/colors'
import { isEditableTarget } from '@/lib/editableTarget'
import { isApplePlatform } from '@/lib/platform'
import { panelJustDismissed } from '@/components/map/mapPanelState'

const DEFAULT_ZOOM = 12
/** The route line when it is not coloured by surface. */
const ROUTE_COLOR = '#4F46E5'

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
  /** Bumped by the owner after an import: the map frames the whole route. */
  fitRequest?: number
  /** Given where the map holds the tool: adds the « Import a GPX file » button to the control column. */
  onImport?: () => void
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  teamLocation?: [number, number] // [lng, lat] from team geometry
  /** Position of the entry of the elevation profile (not the map) that is hovered; null for none. */
  hoverPosition?: Point | null
  /** Reports the point of the route the cursor is nearest to on the map (-1: none). */
  onHoverIndex?: (index: number) => void
  /** « Add a route point » was chosen on a place of the line: the owner opens its form. */
  onWaypointAdd?: (at: WaypointPlacement) => void
  /** A route point was clicked (or Enter on it): the owner opens its form. */
  onWaypointOpen?: (key: string) => void
  /** A route point is to be removed (Delete on it): the owner removes it and offers to take it back. */
  onWaypointRemove?: (key: string) => void
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

/**
 * What the planner's menu is open on: a place of the line (where « Add a route point » puts one),
 * and, on a control point or an anchor of a loaded track, what deleting it would do.
 */
interface PlannerMenu {
  x: number
  y: number
  /** The route the menu was opened on: a menu left open over another route does nothing stale. */
  route: Route
  add?: WaypointPlacement
  remove?:
    | { kind: 'marker'; idx: number; zoom: number }
    | { kind: 'anchor'; start: RoutePoint; end: RoutePoint; direct: boolean }
  /** Opened from the keyboard: the focus enters the menu, and comes back to the marker. */
  byKeyboard?: boolean
}

/** A finger on the line, still enough to become a long press (RoutePlanner.tsx lineLongPress). */
const LINE_TOUCH_RADIUS_PX = 25
/** A mouse targets the line within this distance of the cursor. */
const LINE_CLICK_RADIUS_PX = 15

/** Both layers of the route line (plain and dashed): what hit tests and hover queries must target. */
const ROUTE_LINE_LAYERS = ['route-line', 'route-line-direct']

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
  onImport,
  fitRequest = 0,
  initialTrack,
  teamLocation,
  hoverPosition = null,
  onHoverIndex,
  onWaypointAdd,
  onWaypointOpen,
  onWaypointRemove,
}: RoutePlannerProps) {
  const { t } = useTranslation()
  const colorScheme = useResolvedColorScheme()
  const { darkBasemap } = useMapStyle()
  const theme = useMantineTheme()
  const mapRef = useRef<MapRef>(null)
  const mapContainerRef = useRef<HTMLDivElement>(null)

  const {
    route,
    controlPoints,
    routeGeoJson,
    routeLegsGeoJson,
    colorBy,
    directMode,
    setDirectMode,
    isLoading,
    error,
    routerProfile,
    setRouterProfile,
    routerTuning,
    setRouterTuning,
    resetRouterTuning,
    addControlPoint,
    insertControlPoint,
    updateControlPoint,
    removeControlPoint,
    removeAnchor,
    clearRoute,
    waypoints,
    placedWaypoints,
    moveWaypoint,
    canUndo,
    canRedo,
    undo,
    redo,
  } = planner

  // The route line: one colour, or the surface of each edge (a `match` on the features' `surface`)
  const lineColor = useMemo(() => {
    if (colorBy !== 'surface') return ROUTE_COLOR
    // Over the basemap: its tone decides, not the theme (a light basemap in dark mode, a satellite)
    const c = surfaceColors(theme, darkBasemap ? 'dark' : 'light')
    return [
      'match',
      ['get', 'surface'],
      'paved',
      c.paved,
      'unpaved',
      c.unpaved,
      'offNetwork',
      c.offNetwork,
      c.unknown,
    ] as ExpressionSpecification
  }, [colorBy, theme, darkBasemap])

  const getMapZoom = useCallback(() => mapRef.current?.getZoom() ?? DEFAULT_ZOOM, [])

  const defaultView = useDefaultMapView()

  // Press "h" to hide the trace and its markers, revealing the basemap underneath
  const [trackHidden, toggleTrackHidden] = useHideTrackKey(active)

  // Calculate initial view state from track bounds, team location, or the server's default centre.
  // Null while none of the three is known yet — the map waits rather than opening somewhere wrong.
  // The route as the map is built: a file imported while the editor was closed frames it too.
  const routeRef = useRef(route)
  useEffect(() => {
    routeRef.current = route
  })
  // Distance along the route at each of its points: what the gestures that place a route point
  // measure from. The ref lets the drag handlers (stable, called by the auto-pan) read the latest.
  const cum = useMemo(() => cumulativeDistances(route.points), [route])
  const waypointEnvRef = useRef({ route, cum })
  useEffect(() => {
    waypointEnvRef.current = { route, cum }
  })
  const initialViewState = useMemo(() => {
    if (!initialTrack || initialTrack.length === 0) {
      const built = routeRef.current.points
      if (built.length > 1) {
        return {
          bounds: calculateBounds(built.map((p) => [p.lng, p.lat])),
          fitBoundsOptions: { padding: 40, maxZoom: 15 },
        }
      }
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

  // An import frames the whole route, whatever the map was showing
  useEffect(() => {
    if (fitRequest === 0) return
    const points = routeRef.current.points
    if (points.length < 2) return
    mapRef.current?.fitBounds(calculateBounds(points.map((p) => [p.lng, p.lat])), {
      padding: 40,
      maxZoom: 15,
      duration: 0,
    })
  }, [fitRequest])

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

  // A route point being dragged: kept to the line (its projection, recomputed at every move) unless
  // Alt is held, then free, and « off the track » when the line is farther than 50 m. No request.
  const [draggingWaypoint, setDraggingWaypoint] = useState<{
    key: string
    lng: number
    lat: number
    free: boolean
    offTrack: boolean
  } | null>(null)
  const waypointDragRef = useRef<{ key: string; lng: number; lat: number; free: boolean } | null>(
    null
  )
  const waypointDragOriginRef = useRef<Point | null>(null)
  const waypointDragCancelledRef = useRef(false)
  const altKeyRef = useRef(false)

  /** Follows the pointer: the pin goes to the line, or to the pointer when Alt frees it. */
  const moveWaypointDrag = useCallback((key: string, lngLat: Point): Point => {
    const { route: current, cum: distances } = waypointEnvRef.current
    const free = altKeyRef.current || current.points.length < 2
    const projection = free ? null : projectOnRoute(current, distances, lngLat)
    const at = projection ?? lngLat
    const isFree = free || !projection
    waypointDragRef.current = { key, lng: at.lng, lat: at.lat, free: isFree }
    setDraggingWaypoint({
      key,
      lng: at.lng,
      lat: at.lat,
      free: isFree,
      offTrack: isFree && locateOnRoute(current, distances, at) === null,
    })
    return { lng: at.lng, lat: at.lat }
  }, [])

  // Scrolls the map while a dragged point sits at its edge. Each frame it moves the point with the
  // map (it stays under the finger or the mouse); the bounds of the gesture are frozen at its start
  // and never recomputed (panBy changes neither the route nor the zoom). flushSync: without it
  // React renders after the paint and the point trembles by a frame. A pointer gesture drags a
  // marker or a ghost, never both, so whichever is dragged follows.
  const handleAutoPan = useCallback(
    (lngLat: Point) => {
      flushSync(() => {
        setDraggingMarker((prev) => (prev ? { ...prev, lng: lngLat.lng, lat: lngLat.lat } : prev))
        setDraggingGhost((prev) => (prev ? { ...prev, lng: lngLat.lng, lat: lngLat.lat } : prev))
        if (waypointDragRef.current) moveWaypointDrag(waypointDragRef.current.key, lngLat)
      })
    },
    [moveWaypointDrag]
  )
  const autoPan = useEdgeAutoPan(mapRef, handleAutoPan)

  // Where a mouse- or finger-dragged marker started, and whether Escape abandoned that drag
  // (MapLibre has no way to cancel a marker drag: the marker is held at its origin until release)
  const markerDragOriginRef = useRef<Point | null>(null)
  const markerDragCancelledRef = useRef<{ origin: Point } | null>(null)
  // A mouse ghost drag abandoned by Escape: the click that may follow the release is not a point
  const gestureCancelledAt = useRef(0)

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
  const menuOpenedByPress = useRef(false)
  const clearAnchorPress = useCallback(() => {
    if (anchorPressTimer.current) clearTimeout(anchorPressTimer.current)
    anchorPressTimer.current = null
  }, [])

  // A finger held on the line (no marker, no anchor under it) opens the menu that adds a route
  // point. Unlike the others it does not take the touch: the map can still be panned until the
  // finger moves, which cancels the press.
  const linePress = useRef<{
    timer: ReturnType<typeof setTimeout>
    x: number
    y: number
    pointerId: number | null
  } | null>(null)
  const clearLinePress = useCallback(() => {
    if (linePress.current) clearTimeout(linePress.current.timer)
    linePress.current = null
  }, [])

  const clearLongPress = useCallback(() => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }
    longPressTouchStart.current = null
  }, [])

  // A press pending when the planner goes away must not fire on the unmounted view
  useEffect(
    () => () => {
      clearLongPress()
      clearAnchorPress()
      clearLinePress()
    },
    [clearLongPress, clearAnchorPress, clearLinePress]
  )

  // The long-press menu is portalled to body and this view outlives the fullscreen editor: when
  // the editor closes (browser back) or the view moves, the menu would hang on a detached target.
  useEffect(() => {
    setContextMenu(null)
    clearLongPress()
    clearAnchorPress()
    clearLinePress()
    menuOpenedByPress.current = false
    autoPan.end()
  }, [layout, active, clearLongPress, clearAnchorPress, clearLinePress, autoPan])

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
        const point = route.points[idx]
        setContextMenu({
          x,
          y,
          route,
          add: point ? { lng: point.lng, lat: point.lat, distance: cum[idx] } : undefined,
          remove: { kind: 'marker', idx, zoom },
        })
        longPressOpenedAt.current = Date.now()
        longPressTimer.current = null
      }, LONG_PRESS_MS)
    },
    [getMapZoom, route, cum]
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
    if (!m?.remove) return
    setContextMenu(null)
    if (m.remove.kind === 'marker') {
      removeControlPoint(m.remove.idx, directKeyRef.current, m.remove.zoom)
    } else if (m.route === route) {
      removeAnchor(m.remove.start, m.remove.end, m.remove.direct || directKeyRef.current)
    }
    // else: the route changed while the menu was open, its bounds are stale
  }, [contextMenu, removeControlPoint, removeAnchor, route])

  const handleContextMenuAdd = useCallback(() => {
    const m = contextMenu
    setContextMenu(null)
    // The placement is re-anchored on the route by the server at save time: no stale guard needed
    if (m?.add) onWaypointAdd?.(m.add)
  }, [contextMenu, onWaypointAdd])

  /** The menu of a control point from the keyboard (Menu key, Shift+F10): at the marker. */
  const returnFocusRef = useRef<HTMLElement | null>(null)
  const openMarkerMenu = useCallback(
    (idx: number, byKeyboard: boolean) => {
      const map = mapRef.current
      const point = route.points[idx]
      if (!map || !point || isLoading) return
      const { x, y } = map.project([point.lng, point.lat])
      returnFocusRef.current = byKeyboard ? (document.activeElement as HTMLElement | null) : null
      setHoverPoint(null)
      setContextMenu({
        x,
        y,
        route,
        add: { lng: point.lng, lat: point.lat, distance: cum[idx] },
        remove: { kind: 'marker', idx, zoom: getMapZoom() },
        byKeyboard,
      })
    },
    [route, cum, isLoading, getMapZoom]
  )

  // Opened from the keyboard, the menu takes the focus (its first item), and gives it back
  useEffect(() => {
    if (!contextMenu?.byKeyboard) return
    const frame = requestAnimationFrame(() =>
      document
        .querySelector<HTMLElement>('[data-planner-menu] [role="menuitem"]:not([disabled])')
        ?.focus()
    )
    return () => cancelAnimationFrame(frame)
  }, [contextMenu])

  // Straight-line mode: held while Ctrl OR Alt is down (Ctrl+click is a right click on macOS, hence
  // Alt). Read from the modifier flags of every key event, so a missed keyup cannot leave it stuck,
  // and cleared when the window loses focus (Alt-Tab, a native dialog) since no keyup follows then.
  // Undo/redo shortcuts live here too, but never fire from a text field (native text undo there).
  const directKeyRef = useRef(false)
  // Abandons the pointer gesture in progress, if any (set at every render: it reads their state)
  const cancelGestureRef = useRef<() => boolean>(() => false)
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      directKeyRef.current = e.ctrlKey || e.altKey
      altKeyRef.current = e.altKey
      if (!active || isEditableTarget(e.target)) return
      if (e.key === 'Escape') {
        if (cancelGestureRef.current()) e.preventDefault()
        return
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') {
        e.preventDefault()
        if (e.shiftKey) redo()
        else undo()
      }
    }
    const handleKeyUp = (e: KeyboardEvent) => {
      directKeyRef.current = e.ctrlKey || e.altKey
      altKeyRef.current = e.altKey
    }
    const handleBlur = () => {
      directKeyRef.current = false
      altKeyRef.current = false
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

  // Moving a point with the arrow keys. A burst of arrows moves the preview (the same one a drag
  // shows: marker, connection lines, bounds frozen at the first step); the route is computed once,
  // when the burst ends. The point keeps its id, so its marker keeps the focus.
  const keyboardMoveRef = useRef<{
    id: string
    idx: number
    route: Route
    start: RoutePoint | undefined
    end: RoutePoint | undefined
    origin: Point
    pos: Point
  } | null>(null)
  const keyboardTargetRef = useRef<RoutePoint | null>(null)
  const [keyboardMoving, setKeyboardMoving] = useState(false)

  const resetKeyboardMove = useCallback(() => {
    keyboardMoveRef.current = null
    setKeyboardMoving(false)
    setDraggingMarker(null)
    setStartDragPoint(undefined)
    setEndDragPoint(undefined)
  }, [])

  const keyboard = useKeyboardPointMove({
    onStep: (dx, dy) => {
      const map = mapRef.current
      if (!map) return
      let move = keyboardMoveRef.current
      if (!move) {
        const target = keyboardTargetRef.current
        // One routing operation at a time: the arrows are inert during a calculation
        if (!target || isLoading) return
        const { start, end } = legBounds(route, target.idx - 1, target.idx + 1)
        move = {
          id: target.id,
          idx: target.idx,
          route,
          start,
          end,
          origin: { lng: target.lng, lat: target.lat },
          pos: { lng: target.lng, lat: target.lat },
        }
        keyboardMoveRef.current = move
        clearLongPress()
        setContextMenu(null)
        setHoverPoint(null)
        setStartDragPoint(start)
        setEndDragPoint(end)
        setKeyboardMoving(true)
      }
      const p = map.project([move.pos.lng, move.pos.lat])
      const x = p.x + dx
      const y = p.y + dy
      const next = map.unproject([x, y])
      move.pos = { lng: next.lng, lat: next.lat }
      // Keeps the point in the frame: a point entering the edge zone brings the map along with it
      const container = map.getContainer()
      const zoneX = Math.min(EDGE_PAN_ZONE_PX, container.clientWidth / 4)
      const zoneY = Math.min(EDGE_PAN_ZONE_PX, container.clientHeight / 4)
      const overshoot = (v: number, zone: number, length: number) =>
        v < zone ? v - zone : v > length - zone ? v - (length - zone) : 0
      const panX = overshoot(x, zoneX, container.clientWidth)
      const panY = overshoot(y, zoneY, container.clientHeight)
      if (panX !== 0 || panY !== 0) map.panBy([panX, panY], { animate: false })
      setDraggingMarker({ idx: move.idx, lng: move.pos.lng, lat: move.pos.lat })
    },
    onCommit: () => {
      const move = keyboardMoveRef.current
      if (!move) return
      // Another gesture or an undo changed the route meanwhile: the bounds are not in it any more
      const stale = move.route !== route
      resetKeyboardMove()
      if (stale) return
      updateControlPoint(move.start, move.pos, move.end, false, move.id)
    },
    onCancel: resetKeyboardMove,
  })

  /** A pointer gesture, a new route or a change of view abandons a burst of arrows. */
  const cancelKeyboardMove = useCallback(() => {
    keyboard.cancel()
    if (keyboardMoveRef.current) resetKeyboardMove()
  }, [keyboard, resetKeyboardMove])

  // The route changed under an uncommitted burst (Ctrl+Z, another gesture): its bounds are stale
  useEffect(() => {
    if (keyboardMoveRef.current && keyboardMoveRef.current.route !== route) cancelKeyboardMove()
  }, [route, cancelKeyboardMove])
  useEffect(() => {
    cancelKeyboardMove()
  }, [layout, active, cancelKeyboardMove])

  const handleMarkerDragStart = useCallback(
    (idx: number) => (event: MarkerDragEvent) => {
      cancelKeyboardMove()
      clearLongPress()
      setContextMenu(null)
      // MapLibre emits dragstart after the first move: the origin is the point, not the event
      markerDragOriginRef.current = { lng: route.points[idx].lng, lat: route.points[idx].lat }
      markerDragCancelledRef.current = null
      setDraggingMarker({ idx, lng: event.lngLat.lng, lat: event.lngLat.lat })
      const { start, end } = legBounds(route, idx - 1, idx + 1)
      setStartDragPoint(start)
      setEndDragPoint(end)
      setHoverPoint(null)
      autoPan.begin(event.lngLat)
    },
    [route, clearLongPress, cancelKeyboardMove, autoPan]
  )

  const handleMarkerDrag = useCallback(
    (idx: number) => (event: MarkerDragEvent) => {
      const cancelled = markerDragCancelledRef.current
      if (cancelled) {
        // Escape abandoned the drag: the marker is held at its origin until the button is released
        event.target.setLngLat([cancelled.origin.lng, cancelled.origin.lat])
        return
      }
      autoPan.follow(event.lngLat)
      setDraggingMarker((prev) =>
        prev && prev.idx === idx ? { idx, lng: event.lngLat.lng, lat: event.lngLat.lat } : prev
      )
    },
    [autoPan]
  )

  const handleMarkerDragEnd = useCallback(
    (id: string) => (event: MarkerDragEvent) => {
      autoPan.end()
      const cancelled = markerDragCancelledRef.current
      markerDragOriginRef.current = null
      markerDragCancelledRef.current = null
      if (cancelled) {
        event.target.setLngLat([cancelled.origin.lng, cancelled.origin.lat])
        setDraggingMarker(null)
        setStartDragPoint(undefined)
        setEndDragPoint(undefined)
        return
      }
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
        directKeyRef.current,
        id
      )
      setDraggingMarker(null)
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
    },
    [updateControlPoint, startDragPoint, endDragPoint, route, autoPan]
  )

  // --- Dragging a route point ---
  const handleWaypointDragStart = useCallback(
    (key: string, event: MarkerDragEvent) => {
      cancelKeyboardMove()
      clearLongPress()
      clearLinePress()
      setContextMenu(null)
      setHoverPoint(null)
      const waypoint = waypoints.find((w) => w.key === key)
      waypointDragOriginRef.current = waypoint ? { lng: waypoint.lng, lat: waypoint.lat } : null
      waypointDragCancelledRef.current = false
      moveWaypointDrag(key, event.lngLat)
      autoPan.begin(event.lngLat)
    },
    [waypoints, cancelKeyboardMove, clearLongPress, clearLinePress, moveWaypointDrag, autoPan]
  )

  const handleWaypointDrag = useCallback(
    (key: string, event: MarkerDragEvent) => {
      const origin = waypointDragOriginRef.current
      if (waypointDragCancelledRef.current && origin) {
        // Escape abandoned the drag: the pin is held at its origin until the button is released
        event.target.setLngLat([origin.lng, origin.lat])
        return
      }
      autoPan.follow(event.lngLat)
      const at = moveWaypointDrag(key, event.lngLat)
      // Held on the line (or free under the pointer) while the pointer moves: no flicker
      event.target.setLngLat([at.lng, at.lat])
    },
    [autoPan, moveWaypointDrag]
  )

  const handleWaypointDragEnd = useCallback(
    (key: string, event: MarkerDragEvent) => {
      autoPan.end()
      const last = waypointDragRef.current
      const origin = waypointDragOriginRef.current
      const cancelled = waypointDragCancelledRef.current
      waypointDragRef.current = null
      waypointDragOriginRef.current = null
      waypointDragCancelledRef.current = false
      setDraggingWaypoint(null)
      if (cancelled || !last) {
        if (origin) event.target.setLngLat([origin.lng, origin.lat])
        return
      }
      const { route: current, cum: distances } = waypointEnvRef.current
      const hint = waypoints.find((w) => w.key === key)?.hint
      // On the line: the distance of the projection (no passage to choose). Free: the server's
      // rule, so the pin that lands within 50 m of the line is on it again
      const distance = last.free
        ? locateOnRoute(current, distances, last, hint)
        : (projectOnRoute(current, distances, last)?.distance ?? null)
      moveWaypoint(key, { lng: last.lng, lat: last.lat }, distance)
    },
    [autoPan, waypoints, moveWaypoint]
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
      // Only a real right click deletes (a billed request). The Menu key and Shift+F10 fire the
      // same event with another button: they open the menu instead.
      if (native.button !== 2) {
        openMarkerMenu(index, true)
        return
      }
      removeControlPoint(index, directKeyRef.current, getMapZoom())
    },
    [removeControlPoint, getMapZoom, openMarkerMenu]
  )

  // Right click on the map. On an imported anchor (a white point of a loaded track) the menu offers
  // to delete it (the bounds are frozen now, at the zoom the pointer saw, and shown while the menu
  // is open) and to add a route point; anywhere on the line, to add a route point.
  const handleMapContextMenu = useCallback(
    (event: MapMouseEvent) => {
      const native = event.originalEvent
      // MapLibre's simulated long press, or a finger's native one: the finger has its own menu
      if (isFingerEvent(native)) return
      // A marker is a child of the map's container: its own handler owns the event
      // Only the control points, the route points and « Start here » are interactive: the hover
      // ghost and the km labels are markers too, but their wrapper must not swallow the click
      // (same selector as the touch start).
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
      const rect = mapContainerRef.current?.getBoundingClientRect()
      const x = rect ? native.clientX - rect.left : native.clientX
      const y = rect ? native.clientY - rect.top : native.clientY

      let menu: PlannerMenu | null = null
      const i = anchorAt(map, route, event.point, ANCHOR_CLICK_RADIUS_PX, zoom, true)
      if (i !== null) {
        const { start, end } = spanBounds(route, i - 1, i + 1, zoom)
        if (start && end) {
          const anchor = route.points[i]
          menu = {
            x,
            y,
            route,
            add: { lng: anchor.lng, lat: anchor.lat, distance: cum[i] },
            remove: {
              kind: 'anchor',
              start,
              end,
              direct: native.altKey || (!isApplePlatform() && native.ctrlKey),
            },
          }
        }
      }
      if (!menu && routeGeoJson) {
        const bbox: [[number, number], [number, number]] = [
          [event.point.x - LINE_CLICK_RADIUS_PX, event.point.y - LINE_CLICK_RADIUS_PX],
          [event.point.x + LINE_CLICK_RADIUS_PX, event.point.y + LINE_CLICK_RADIUS_PX],
        ]
        if (map.queryRenderedFeatures(bbox, { layers: ROUTE_LINE_LAYERS }).length > 0) {
          const add = projectOnRoute(route, cum, event.lngLat)
          if (add) menu = { x, y, route, add }
        }
      }
      if (!menu) return
      native.preventDefault()
      returnFocusRef.current = null
      setHoverPoint(null)
      setContextMenu(menu)
    },
    [isFingerEvent, isLoading, controlPoints, getMapZoom, route, cum, routeGeoJson]
  )

  const handleMapClick = useCallback(
    (event: MapMouseEvent) => {
      // One routing operation at a time: clicks during a calculation are dropped
      if (isLoading) return

      // The press that dismissed a map panel is not a point to add
      if (panelJustDismissed()) return

      // Nor is a click the browser may still derive from a finger's anchor drag
      if (Date.now() - anchorDragEndedAt.current < 400) return

      // Nor is the one ending a ghost drag that Escape abandoned
      if (Date.now() - gestureCancelledAt.current < 400) return

      // Nor is the one on the « Start here » button (it adds the point itself, and stops the
      // click; this guard is the fallback should a click still come through)
      if (
        (event.originalEvent?.target as HTMLElement | null)?.closest?.(
          '.planner-start-here, .planner-waypoint'
        )
      ) {
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
          layers: ROUTE_LINE_LAYERS,
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
        onHoverIndex?.(-1)
        autoPan.follow(event.lngLat)
        setDraggingGhost((prev) =>
          prev ? { ...prev, lng: event.lngLat.lng, lat: event.lngLat.lat } : null
        )
        return
      }

      if (draggingMarker || draggingWaypoint) {
        onHoverIndex?.(-1)
        return
      }

      // Over a route point's pin: no ghost, so no insertion by dragging from under it
      if ((event.originalEvent?.target as HTMLElement | null)?.closest?.('.planner-waypoint')) {
        setHoverPoint(null)
        onHoverIndex?.(-1)
        return
      }

      // The ghost point is a mouse affordance (hover the trace, drag the ghost out). A tap sends a
      // compatibility mousemove before its click, with no pointer type of its own: showing the
      // ghost then would make the click below bail out, and the finger need a second tap on the
      // ghost to insert (seen on an iPhone). A finger inserts with one tap instead.
      if (isFingerEvent(event.originalEvent)) {
        if (hoverPoint) setHoverPoint(null)
        onHoverIndex?.(-1)
        return
      }

      if (!mapRef.current || !routeGeoJson) {
        onHoverIndex?.(-1)
        return
      }

      for (const point of controlPoints) {
        const projected = mapRef.current.project([point.lng, point.lat])
        const dx = projected.x - event.point.x
        const dy = projected.y - event.point.y
        const distance = Math.sqrt(dx * dx + dy * dy)
        if (distance < MARKER_PROXIMITY_PX) {
          setHoverPoint(null)
          onHoverIndex?.(-1)
          return
        }
      }

      const ROUTE_BUFFER_PX = LINE_CLICK_RADIUS_PX
      const bbox: [[number, number], [number, number]] = [
        [event.point.x - ROUTE_BUFFER_PX, event.point.y - ROUTE_BUFFER_PX],
        [event.point.x + ROUTE_BUFFER_PX, event.point.y + ROUTE_BUFFER_PX],
      ]
      const features = mapRef.current.queryRenderedFeatures(bbox, {
        layers: ROUTE_LINE_LAYERS,
      })

      if (features.length > 0) {
        const seg = nearestSegment(route, event.lngLat)
        if (seg) {
          setHoverPoint({ lng: seg.point.lng, lat: seg.point.lat, seg: seg.index })
          // The profile follows the end of the segment nearest to the cursor
          const a = route.points[seg.index]
          const b = route.points[seg.index + 1]
          const cos = Math.cos((event.lngLat.lat * Math.PI) / 180)
          const dist2 = (p: RoutePoint) =>
            ((p.lng - event.lngLat.lng) * cos) ** 2 + (p.lat - event.lngLat.lat) ** 2
          onHoverIndex?.(dist2(a) <= dist2(b) ? seg.index : seg.index + 1)
          return
        }
      }

      setHoverPoint(null)
      onHoverIndex?.(-1)
    },
    [
      route,
      routeGeoJson,
      draggingGhost,
      draggingMarker,
      draggingWaypoint,
      controlPoints,
      isCoarsePointer,
      isFingerEvent,
      hoverPoint,
      onHoverIndex,
      autoPan,
    ]
  )

  const handleMouseLeave = useCallback(() => {
    setHoverPoint(null)
    setCursorPosition(null)
    onHoverIndex?.(-1)
  }, [onHoverIndex])

  const handleMapMouseDown = useCallback(
    (event: MapMouseEvent) => {
      if (event.originalEvent.button !== 0) return
      if ((event.originalEvent.target as HTMLElement | null)?.closest?.('.planner-waypoint')) return
      if (!hoverPoint || isLoading) return

      event.preventDefault()
      cancelKeyboardMove()

      setDraggingGhost({
        lng: hoverPoint.lng,
        lat: hoverPoint.lat,
        idx: hoverPoint.seg,
      })
      const { start, end } = spanBounds(route, hoverPoint.seg, hoverPoint.seg + 1, getMapZoom())
      setStartDragPoint(start)
      setEndDragPoint(end)
      setHoverPoint(null)
      // Armed from the pointer, not from the snapped point (up to ROUTE_BUFFER_PX away)
      autoPan.begin(event.lngLat)
    },
    [hoverPoint, getMapZoom, route, isLoading, autoPan, cancelKeyboardMove]
  )

  const handleMouseUp = useCallback(() => {
    autoPan.end()
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
  }, [insertControlPoint, draggingGhost, startDragPoint, endDragPoint, autoPan])

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
      // The hook arms itself at the same 3 px as anchorTouchMoved
      autoPan.follow({ lng, lat })
      setDraggingGhost((prev) => (prev ? { ...prev, lng, lat } : null))
    },
    [clearAnchorPress, autoPan]
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
    autoPan.end()
    setDraggingGhost(null)
    setStartDragPoint(undefined)
    setEndDragPoint(undefined)
  }, [clearAnchorPress, autoPan])

  // Escape during a pointer gesture: the ghost, the finger's anchor or the dragged marker goes back
  // to where it was, with no request. (A burst of arrows handles its own Escape, on the marker.)
  // With no gesture in progress Escape does nothing here: panels, the menu and the search close
  // themselves.
  const cancelGesture = (): boolean => {
    if (draggingGhost) {
      if (anchorTouchStart.current) {
        cancelAnchorDrag()
      } else {
        autoPan.end()
        setDraggingGhost(null)
        setStartDragPoint(undefined)
        setEndDragPoint(undefined)
        gestureCancelledAt.current = Date.now()
      }
      return true
    }
    const waypointOrigin = waypointDragOriginRef.current
    if (draggingWaypoint && waypointOrigin && !waypointDragCancelledRef.current) {
      autoPan.end()
      waypointDragCancelledRef.current = true
      waypointDragRef.current = null
      setDraggingWaypoint((prev) =>
        prev
          ? {
              ...prev,
              lng: waypointOrigin.lng,
              lat: waypointOrigin.lat,
              free: false,
              offTrack: false,
            }
          : prev
      )
      return true
    }
    const origin = markerDragOriginRef.current
    if (draggingMarker && origin && !markerDragCancelledRef.current) {
      autoPan.end()
      markerDragCancelledRef.current = { origin }
      setDraggingMarker((prev) => (prev ? { ...prev, lng: origin.lng, lat: origin.lat } : prev))
      setStartDragPoint(undefined)
      setEndDragPoint(undefined)
      return true
    }
    return false
  }
  useEffect(() => {
    cancelGestureRef.current = cancelGesture
  })

  const handleMapTouchStart = useCallback(
    (event: MapLayerTouchEvent) => {
      const map = mapRef.current
      if (!map) return
      // A second finger is a pinch or a pan: whatever the first one had started is over
      if (event.points.length !== 1) {
        // Also stops the scrolling of a marker drag: its next drag events must not restart it
        autoPan.block()
        clearAnchorPress()
        clearLinePress()
        if (anchorTouchStart.current) cancelAnchorDrag()
        return
      }
      clearLinePress()
      if (isLoading || draggingMarker || draggingWaypoint) return
      cancelKeyboardMove()
      // A control point is a marker of its own, with its own drag and long press; « Start here »
      // is a button. Other markers (the km labels) are mere labels: one may sit on an anchor, and
      // must not keep the finger from grabbing it.
      const target = event.originalEvent.target as HTMLElement | null
      if (target?.closest?.('.maplibregl-marker [role="button"], .planner-start-here')) return

      const zoom = getMapZoom()
      const grabbed = anchorAt(map, route, event.point, ANCHOR_TOUCH_RADIUS_PX, zoom, false)
      if (grabbed === null) {
        // Not on an anchor: held on the line, the press offers to add a route point there. The map
        // still pans (no preventDefault); moving more than a few px, a second finger or lifting
        // the finger cancels it.
        if (!routeGeoJson) return
        const bbox: [[number, number], [number, number]] = [
          [event.point.x - LINE_TOUCH_RADIUS_PX, event.point.y - LINE_TOUCH_RADIUS_PX],
          [event.point.x + LINE_TOUCH_RADIUS_PX, event.point.y + LINE_TOUCH_RADIUS_PX],
        ]
        if (map.queryRenderedFeatures(bbox, { layers: ROUTE_LINE_LAYERS }).length === 0) return
        const pressed = { lng: event.lngLat.lng, lat: event.lngLat.lat }
        const touch = event.originalEvent.touches[0]
        const timer = setTimeout(() => {
          linePress.current = null
          const add = projectOnRoute(route, cum, pressed)
          if (!add) return
          const rect = mapContainerRef.current?.getBoundingClientRect()
          menuOpenedByPress.current = true
          longPressOpenedAt.current = Date.now()
          returnFocusRef.current = null
          setContextMenu({
            x: rect ? touch.clientX - rect.left : touch.clientX,
            y: rect ? touch.clientY - rect.top : touch.clientY,
            route,
            add,
          })
        }, LONG_PRESS_MS)
        linePress.current = {
          timer,
          x: touch.clientX,
          y: touch.clientY,
          pointerId: lastTouchPointerId.current,
        }
        return
      }

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
      // Armed from the finger, not from the anchor (up to ANCHOR_TOUCH_RADIUS_PX away)
      const finger = map.unproject(event.point)
      autoPan.begin({ lng: finger.lng, lat: finger.lat })

      // Held still on an anchor, the press opens its menu: add a route point there and, on an
      // imported one, delete it; the bounds are the ones frozen now.
      clearAnchorPress()
      const anchorTouch = event.originalEvent.touches[0]
      anchorPressTimer.current = setTimeout(() => {
        anchorPressTimer.current = null
        menuOpenedByPress.current = true
        anchorTouchStart.current = null
        anchorPointerId.current = null
        anchorTouchMoved.current = false
        autoPan.end()
        // The drag stops; its bounds stay, shown through the menu
        setDraggingGhost(null)
        setStartDragPoint(undefined)
        setEndDragPoint(undefined)
        const rect = mapContainerRef.current?.getBoundingClientRect()
        returnFocusRef.current = null
        setContextMenu({
          x: rect ? anchorTouch.clientX - rect.left : anchorTouch.clientX,
          y: rect ? anchorTouch.clientY - rect.top : anchorTouch.clientY,
          route,
          add: { lng: anchor.lng, lat: anchor.lat, distance: cum[grabbed] },
          remove:
            anchor.imported && start && end
              ? { kind: 'anchor', start, end, direct: false }
              : undefined,
        })
        longPressOpenedAt.current = Date.now()
      }, LONG_PRESS_MS)
    },
    [
      isLoading,
      draggingMarker,
      draggingWaypoint,
      routeGeoJson,
      cum,
      clearLinePress,
      getMapZoom,
      route,
      clearAnchorPress,
      cancelAnchorDrag,
      autoPan,
      cancelKeyboardMove,
    ]
  )

  const handleMapTouchMove = useCallback(
    (event: MapLayerTouchEvent) => {
      if (event.points.length > 1) {
        autoPan.block()
        clearAnchorPress()
        clearLinePress()
        // Only what this gesture started: a marker drag has its own bounds, a pinch must not clear them
        if (anchorTouchStart.current) cancelAnchorDrag()
        return
      }
      if (!anchorTouchStart.current) return
      event.preventDefault()
      followAnchorPress(event.point)
    },
    [clearAnchorPress, clearLinePress, cancelAnchorDrag, followAnchorPress, autoPan]
  )

  const handleMapTouchEnd = useCallback(
    (event: MapLayerTouchEvent) => {
      autoPan.end()
      clearLinePress()
      if (menuOpenedByPress.current) {
        menuOpenedByPress.current = false
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
    [handleMouseUp, cancelAnchorDrag, clearAnchorPress, clearLinePress, autoPan]
  )

  const handleMapTouchCancel = useCallback(() => {
    menuOpenedByPress.current = false
    clearLinePress()
    cancelAnchorDrag()
  }, [cancelAnchorDrag, clearLinePress])

  // After a Delete the focus goes to the neighbour point (the removed marker took it with it)
  const pendingFocusRef = useRef<number | null>(null)
  useEffect(() => {
    if (isLoading || pendingFocusRef.current === null) return
    const index = pendingFocusRef.current
    // Whatever the outcome (an error included), the wish is spent
    pendingFocusRef.current = null
    const focused = document.activeElement
    if (focused && focused !== document.body) return
    mapContainerRef.current
      ?.querySelector<HTMLElement>(`[data-planner-index="${index}"]`)
      ?.focus({ preventScroll: true })
  }, [isLoading, route])

  // MapLibre appends each new marker at the end of its container: the Tab order would not follow
  // the points once one is inserted in the middle. Put the wrappers back in the order of the points
  // (child effects ran first: a new marker is in the DOM). Moving an element drops its focus.
  const orderKey = controlPoints.map((p) => p.id).join()
  useEffect(() => {
    const container = mapContainerRef.current
    if (!container) return
    const wrappers = Array.from(container.querySelectorAll<HTMLElement>('[data-planner-index]'))
      .sort((a, b) => Number(a.dataset.plannerIndex) - Number(b.dataset.plannerIndex))
      .map((el) => el.closest<HTMLElement>('.maplibregl-marker'))
      .filter((el): el is HTMLElement => el !== null)
    const focused = document.activeElement as HTMLElement | null
    for (let i = 1; i < wrappers.length; i++) {
      const prev = wrappers[i - 1]
      if (!(prev.compareDocumentPosition(wrappers[i]) & Node.DOCUMENT_POSITION_FOLLOWING)) {
        prev.after(wrappers[i])
      }
    }
    if (focused && focused !== document.activeElement && focused.isConnected) {
      focused.focus({ preventScroll: true })
    }
  }, [orderKey])

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
  const menuBounds = contextMenu?.remove?.kind === 'anchor' ? contextMenu.remove : null
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
        // Leaving the map with the mouse: the map no longer receives its moves, the scrolling
        // stops (the gesture stays armed, coming back resumes it)
        onPointerLeave={(e: React.PointerEvent) => {
          if (e.pointerType === 'mouse') autoPan.stop()
        }}
        onPointerMoveCapture={(e: React.PointerEvent) => {
          lastPointerType.current = e.pointerType as PointerKind
          handleAnchorPointerMove(e)
          // The finger of a press on the line moved: it is a pan, not a press (read here, as the
          // touchmoves arrive late)
          const press = linePress.current
          if (
            press &&
            (press.pointerId === null || e.pointerId === press.pointerId) &&
            Math.hypot(e.clientX - press.x, e.clientY - press.y) >= LONG_PRESS_MOVE_TOLERANCE_PX
          ) {
            clearLinePress()
          }
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
            interactiveLayerIds={routeGeoJson ? ROUTE_LINE_LAYERS : []}
            cursor={
              isLoading
                ? 'progress'
                : draggingGhost || draggingMarker || draggingWaypoint
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

                <DirectModeControl directMode={directMode} onToggle={setDirectMode} />

                <HideTrackControl hidden={trackHidden} onToggle={toggleTrackHidden} />

                {onImport && (
                  <MapControlGroup>
                    <MapControlButton
                      label={t('planner.import')}
                      icon={<IconFileImport size={20} />}
                      onClick={onImport}
                      disabled={isLoading}
                    />
                  </MapControlGroup>
                )}

                <PlannerHelpControl />

                <RouterProfileSelector
                  currentProfile={routerProfile}
                  onProfileChange={setRouterProfile}
                  tuning={routerTuning}
                  onTuningChange={setRouterTuning}
                  onTuningReset={resetRouterTuning}
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
                {routeGeoJson && routeLegsGeoJson && (
                  <Source id="route" type="geojson" data={routeLegsGeoJson}>
                    <Layer
                      id="route-line"
                      type="line"
                      filter={['!=', ['get', 'direct'], true]}
                      paint={{
                        'line-color': lineColor,
                        'line-width': 5,
                        'line-opacity': 0.8,
                      }}
                    />
                    {/* Straight legs: dashed (dash lengths in line widths), apart from the green
                        4 px connection lines of a drag */}
                    <Layer
                      id="route-line-direct"
                      type="line"
                      filter={['==', ['get', 'direct'], true]}
                      paint={{
                        'line-color': lineColor,
                        'line-width': 5,
                        'line-opacity': 0.8,
                        'line-dasharray': [1.5, 1.5],
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

                {/* The point the elevation profile is hovering; never takes the pointer */}
                {hoverPosition && (
                  <HoverMarker
                    longitude={hoverPosition.lng}
                    latitude={hoverPosition.lat}
                    style={{ pointerEvents: 'none' }}
                    testId="planner-hover-marker"
                  />
                )}

                {/* Control point markers */}
                {controlPoints.map((point, index) => {
                  const total = controlPoints.length
                  const role = markerRole(index, total)

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
                      // Over the route points' pins (1): a control point is dragged first
                      style={{ zIndex: 2 }}
                      draggable={!isLoading}
                      onDragStart={handleMarkerDragStart(point.idx)}
                      onDrag={handleMarkerDrag(point.idx)}
                      onDragEnd={handleMarkerDragEnd(point.id)}
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
                        className="mantine-focus-auto"
                        data-planner-index={index}
                        aria-keyshortcuts="ArrowUp ArrowDown ArrowLeft ArrowRight Delete Shift+F10"
                        // Escape during a burst of arrows must not close a dialog around the map
                        // (Mantine listens on window, in the capture phase, and skips this target)
                        data-mantine-stop-propagation={keyboardMoving ? 'true' : undefined}
                        onKeyDown={(e: React.KeyboardEvent) => {
                          keyboardTargetRef.current = point
                          // The Menu key and Shift+F10: the same menu as a right click (add a
                          // route point here, delete the point)
                          if (e.key === 'ContextMenu' || (e.shiftKey && e.key === 'F10')) {
                            e.preventDefault()
                            e.stopPropagation()
                            openMarkerMenu(point.idx, true)
                            return
                          }
                          // First: it stops the arrows, Escape and Enter of a burst, which MapLibre
                          // (it pans the map by the arrows whatever the target) must never see
                          keyboard.onKeyDown(e)
                          if (e.key === 'Delete' || e.key === 'Backspace') {
                            if (isLoading || keyboard.pending()) return
                            e.preventDefault()
                            // The point after the removed one takes the focus, else the one before
                            if (total > 1) pendingFocusRef.current = Math.min(index, total - 2)
                            removeControlPoint(point.idx, directKeyRef.current, getMapZoom())
                          }
                        }}
                        onKeyUp={keyboard.onKeyUp}
                        onBlur={keyboard.onBlur}
                        aria-label={
                          role === 'start'
                            ? t('planner.marker.label.start', { index: index + 1, total })
                            : role === 'end'
                              ? t('planner.marker.label.end', { index: index + 1, total })
                              : t('planner.marker.label', { index: index + 1, total })
                        }
                        onContextMenu={handleMarkerRightClick(point.idx)}
                        onTouchStart={handleMarkerTouchStart(point.idx)}
                        onTouchMove={handleMarkerTouchMove}
                        onTouchEnd={handleMarkerTouchEnd}
                      >
                        <Box
                          w={24}
                          h={24}
                          style={{
                            backgroundColor:
                              role === 'start'
                                ? 'var(--mantine-color-green-filled)'
                                : role === 'end'
                                  ? 'var(--mantine-color-red-filled)'
                                  : 'var(--mantine-color-blue-filled)',
                            border: '2px solid white',
                            // Start and finish differ by shape as well as colour
                            borderRadius: role === 'end' ? 4 : '50%',
                            boxShadow: 'var(--mantine-shadow-lg)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'white',
                          }}
                        >
                          {role === 'start' && <IconPlayerPlayFilled size={12} aria-hidden />}
                          {role === 'end' && <IconFlagFilled size={12} aria-hidden />}
                        </Box>
                      </Box>
                    </Marker>
                  )
                })}

                {/* The author's route points: pins that follow the line, draggable */}
                {placedWaypoints.map((waypoint) => {
                  const drag = draggingWaypoint?.key === waypoint.key ? draggingWaypoint : null
                  return (
                    <PlannerWaypointMarker
                      key={waypoint.key}
                      waypoint={waypoint}
                      lng={drag ? drag.lng : waypoint.lng}
                      lat={drag ? drag.lat : waypoint.lat}
                      offTrack={drag ? drag.offTrack : waypoint.distance === null}
                      dragging={drag !== null}
                      locked={isLoading}
                      onOpen={(key) => onWaypointOpen?.(key)}
                      onRemove={(key) => onWaypointRemove?.(key)}
                      onDragStart={handleWaypointDragStart}
                      onDrag={handleWaypointDrag}
                      onDragEnd={handleWaypointDragEnd}
                    />
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
            if (opened) return
            const wasKeyboard = contextMenu?.byKeyboard
            setContextMenu(null)
            // Opened from a marker with the keyboard: the focus goes back to it
            if (wasKeyboard) returnFocusRef.current?.focus({ preventScroll: true })
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
          <Menu.Dropdown data-planner-menu>
            {contextMenu?.add && (
              <Menu.Item
                leftSection={<IconMapPinPlus size={16} />}
                onClick={handleContextMenuAdd}
                disabled={waypoints.length >= MAX_WAYPOINTS}
              >
                {t('planner.menu.addWaypoint')}
                {waypoints.length >= MAX_WAYPOINTS && (
                  <Text size="xs" c="dimmed">
                    {t('planner.menu.addWaypoint.full')}
                  </Text>
                )}
              </Menu.Item>
            )}
            {contextMenu?.remove && (
              <Menu.Item
                color="red"
                leftSection={<IconTrash size={16} />}
                onClick={handleContextMenuDelete}
              >
                {t('planner.menu.delete')}
              </Menu.Item>
            )}
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
