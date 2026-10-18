import { useState, useCallback, useEffect, useRef, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocalStorage } from '@mantine/hooks'
import {
  add,
  computeRoute,
  createRoute,
  geojson,
  insert,
  legBounds,
  Point,
  remove,
  Route,
  RoutePoint,
  spanBounds,
} from '@/lib/planner'
import { RouterProfile } from '@/api/dto'
import { plannerErrorMessage } from '@/lib/plannerErrors'

export interface UseRoutePlannerOptions {
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  /** Team the route is drawn for; sent to the router, which checks the team's planner flag and rights. Absent from the GPX tools. */
  teamSlug?: string
}

/** Everything the planner hook returns: the state a view of the planner is given. */
export interface RoutePlannerState {
  routeGeoJson: GeoJSON.LineString | null
  route: Route
  controlPoints: RoutePoint[]
  isLoading: boolean
  error: string | null
  canUndo: boolean
  canRedo: boolean
  routerProfile: RouterProfile
  setRouterProfile: (profile: RouterProfile) => void
  addControlPoint: (p: Point, direct?: boolean) => void
  insertControlPoint: (
    start: RoutePoint | undefined,
    p: Point,
    end: RoutePoint | undefined,
    direct?: boolean
  ) => void
  updateControlPoint: (
    start: RoutePoint | undefined,
    p: Point,
    end: RoutePoint | undefined,
    direct?: boolean
  ) => void
  removeControlPoint: (index: number, direct?: boolean, zoom?: number) => void
  /** Removes what lies between two bounds frozen by the caller (a menu opened on an imported anchor). */
  removeAnchor: (start: RoutePoint, end: RoutePoint, direct?: boolean) => void
  clearRoute: () => void
  undo: () => void
  redo: () => void
}

const ROUTER_PROFILE_STORAGE_KEY = 'pedalons-router-profile'

function isRouterProfile(value: unknown): value is RouterProfile {
  return Object.values(RouterProfile).includes(value as RouterProfile)
}

export function useRoutePlanner(options?: UseRoutePlannerOptions): RoutePlannerState {
  const { initialTrack, teamSlug } = options || {}
  const { t } = useTranslation()
  // Remembered across sessions; a stale or hand-edited value falls back to the default.
  const [storedProfile, setStoredProfile] = useLocalStorage<RouterProfile>({
    key: ROUTER_PROFILE_STORAGE_KEY,
    defaultValue: RouterProfile.FASTBIKE,
    getInitialValueInEffect: false,
  })
  const routerProfile = isRouterProfile(storedProfile) ? storedProfile : RouterProfile.FASTBIKE

  const [route, setRoute] = useState<Route>(
    initialTrack ? createRoute(initialTrack) : computeRoute([])
  )
  const [history, setHistory] = useState<Route[]>([])
  const [future, setFuture] = useState<Route[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const canUndo = history.length > 0
  const canRedo = future.length > 0

  const controlPoints = route.points.filter(
    (point, i) => i === 0 || i === route.points.length - 1 || point.manual
  )

  const routeRef = useRef(route)
  useEffect(() => {
    routeRef.current = route
  })

  // The operation in flight, if any. Routing is billed per request, so:
  //  - a user gesture (add, insert, move, remove) arriving while one is in flight is IGNORED (lock),
  //    never queued nor run concurrently; the UI also disables the gestures while isLoading;
  //  - an in-flight operation is CANCELLED (AbortController, propagated down to the HTTP request)
  //    when the gesture that supersedes it is not a routing one (undo, redo, clear), when the
  //    profile changes (its result would be computed for the wrong profile) and on unmount.
  // A cancelled operation touches neither the history nor the route and shows no error.
  const inFlightRef = useRef<AbortController | null>(null)

  const cancelInFlight = useCallback(() => {
    const controller = inFlightRef.current
    if (!controller) return
    inFlightRef.current = null
    controller.abort()
    setIsLoading(false)
  }, [])

  useEffect(
    () => () => {
      inFlightRef.current?.abort()
      inFlightRef.current = null
    },
    []
  )

  const setRouterProfile = useCallback(
    (profile: RouterProfile) => {
      cancelInFlight()
      setStoredProfile(profile)
    },
    [cancelInFlight, setStoredProfile]
  )

  // Generic executor for all route operations
  const executeRouteOperation = useCallback(
    async (operation: (route: Route, signal: AbortSignal) => Promise<Route>) => {
      if (inFlightRef.current) return // lock

      const controller = new AbortController()
      inFlightRef.current = controller
      setIsLoading(true)
      setError(null)

      // Snapshot before the operation mutates the current route's points
      const snapshot: Route = {
        ...routeRef.current,
        points: routeRef.current.points.map((p) => ({ ...p })),
      }

      try {
        const newRoute = await operation(routeRef.current, controller.signal)
        if (controller.signal.aborted) return
        setHistory((prev) => [...prev, snapshot])
        setFuture([])
        setRoute(newRoute)
      } catch (e) {
        if (controller.signal.aborted) return
        setError(plannerErrorMessage(e, t, teamSlug))
      } finally {
        // Only the operation still in flight owns the loading state (a cancelled one already reset it)
        if (inFlightRef.current === controller) {
          inFlightRef.current = null
          setIsLoading(false)
        }
      }
    },
    [t, teamSlug]
  )

  const addControlPoint = useCallback(
    (p: Point, direct = false) => {
      executeRouteOperation((route, signal) =>
        add(route, p, routerProfile, direct, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerProfile, teamSlug]
  )

  // Insert a new control point after the given index (returns the new point for immediate dragging)
  const insertControlPoint = useCallback(
    (start: RoutePoint | undefined, p: Point, end: RoutePoint | undefined, direct?: boolean) => {
      executeRouteOperation((route, signal) =>
        insert(route, start, p, end, routerProfile, direct, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerProfile, teamSlug]
  )

  const updateControlPoint = useCallback(
    (start: RoutePoint | undefined, p: Point, end: RoutePoint | undefined, direct?: boolean) => {
      executeRouteOperation((route, signal) =>
        insert(route, start, p, end, routerProfile, direct, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerProfile, teamSlug]
  )

  const removeControlPoint = useCallback(
    (index: number, direct = false, zoom = 0) => {
      // Bounds on the route the operation works on, not on a render's closure
      const r = routeRef.current
      const last = r.points.length - 1
      const { start, end } =
        index > 0 && index < last
          ? legBounds(r, index - 1, index + 1) // an inner point: the leg between its neighbours
          : spanBounds(r, index - 1, index + 1, zoom) // first or last: cut at the zoom of the gesture
      executeRouteOperation((route, signal) =>
        remove(route, start, end, routerProfile, direct, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerProfile, teamSlug]
  )

  const removeAnchor = useCallback(
    (start: RoutePoint, end: RoutePoint, direct = false) => {
      executeRouteOperation((route, signal) =>
        remove(route, start, end, routerProfile, direct, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerProfile, teamSlug]
  )

  const clearRoute = useCallback(() => {
    cancelInFlight()
    const snapshot: Route = {
      ...routeRef.current,
      points: routeRef.current.points.map((p) => ({ ...p })),
    }
    setHistory((prev) => [...prev, snapshot])
    setFuture([])
    setRoute(computeRoute([]))
    setError(null)
  }, [cancelInFlight])

  const undo = useCallback(() => {
    // While a calculation runs, undo only abandons it: the previous gesture is already applied
    // and is not what the user is retracting.
    if (inFlightRef.current) {
      cancelInFlight()
      return
    }
    if (history.length === 0) return
    setFuture((prev) => [routeRef.current, ...prev])
    const prev = history[history.length - 1]
    setHistory((h) => h.slice(0, -1))
    setRoute(prev)
  }, [history, cancelInFlight])

  const redo = useCallback(() => {
    if (inFlightRef.current) {
      cancelInFlight()
      return
    }
    if (future.length === 0) return
    setHistory((prev) => [...prev, routeRef.current])
    const next = future[0]
    setFuture((f) => f.slice(1))
    setRoute(next)
  }, [future, cancelInFlight])

  const routeGeoJson = useMemo(() => {
    if (route.points.length < 2) return null
    return geojson(route)
  }, [route])

  return {
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
  }
}
