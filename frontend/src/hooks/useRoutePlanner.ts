import { useState, useCallback, useEffect, useRef, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useLocalStorage } from '@mantine/hooks'
import {
  add,
  appendImport,
  computeRoute,
  createRoute,
  directStats as computeDirectStats,
  DirectStats,
  geojson,
  insert,
  legBounds,
  legsGeojson,
  LegProperties,
  Point,
  PlannerRefusedError,
  remove,
  restoreSourceSpan,
  routeFromSources,
  Route,
  RoutePoint,
  sourceFromImport,
  sourceOf,
  spanBounds,
  type PlannerSource,
} from '@/lib/planner'
import { MAX_PLANNER_SOURCES, restorePlannerState, serializePlannerState } from '@/lib/plannerState'
import { RouterProfile } from '@/api/dto'
import type { GeoPoint, GpxImportResponse, PlannerState } from '@/api/dto'
import { importGpx as importGpxRequest } from '@/api/endpoints/router/router'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import { plannerErrorMessage } from '@/lib/plannerErrors'
import {
  isTunable,
  PROFILE_DEFAULTS,
  sanitizeStore,
  sanitizeTuning,
  toRouterSettings,
  type RouterTuning,
  type RouterTuningStore,
  type TuningKey,
} from '@/lib/routerTuning'

export interface UseRoutePlannerOptions {
  /**
   * The saved editing state of the route: wins over `initialTrack`. The planner opens on it without
   * any request, and adopts its profile.
   */
  initialState?: PlannerState
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  /** D+ (m) stored for `initialTrack`: the loaded track's climb is scaled to it. */
  initialAscend?: number
  /** Team the route is drawn for; sent to the router, which checks the team's planner flag and rights. Absent from the GPX tools. */
  teamSlug?: string
}

/** What the form saves: taken at submit time, never while drawing. */
export interface PlannerSnapshot {
  /** Whether the route differs from the one the planner opened on. */
  dirty: boolean
  /** Null below two points or past the bounds of lib/plannerState.ts: send `points` instead. */
  plannerState: PlannerState | null
  points: GeoPoint[]
  /**
   * The file imported in place of the track, when the route is still exactly what it produced (any
   * gesture, an undo included, drops it): the form then uploads the file itself.
   */
  file?: File
}

/** What the planner tells about a file it imported, for the view to report. */
export interface GpxImportInfo {
  /** Name of the file: its metadata, else its first track, else its file name. */
  name: string
  waypointCount: number
  elevationFallback: boolean
  mode: 'replace' | 'append'
}

/** Biggest file the server takes (GpxLimits.MAX_GPX_SIZE_BYTES). */
export const MAX_IMPORT_BYTES = 10 * 1024 * 1024

const IMPORT_TOO_BIG_KEY = tRegister('planner.import.tooBig')
const IMPORT_FAILED_KEY = tRegister('planner.import.failed')
const IMPORT_TOO_MANY_KEY = tRegister('planner.import.tooManyTracks')

/** Everything the planner hook returns: the state a view of the planner is given. */
export interface RoutePlannerState {
  routeGeoJson: GeoJSON.LineString | null
  /** The route cut into straight / routed legs (rendering: dashed straight legs); null under two points. */
  routeLegsGeoJson: GeoJSON.FeatureCollection<GeoJSON.LineString, LegProperties> | null
  /** Length of the straight legs: total, longest one, count. */
  directStats: DirectStats
  /** "Straight line" toggle: every following gesture is drawn without the router, until switched off. */
  directMode: boolean
  setDirectMode: (on: boolean) => void
  route: Route
  controlPoints: RoutePoint[]
  isLoading: boolean
  error: string | null
  canUndo: boolean
  canRedo: boolean
  /** The route differs from the one the planner opened on (undoing back to the start makes it false). */
  isDirty: boolean
  /** The route, as the form saves it; computed on the call. */
  snapshot: () => PlannerSnapshot
  routerProfile: RouterProfile
  setRouterProfile: (profile: RouterProfile) => void
  /** The knobs the user set for the current profile; absent ones are the profile's values. */
  routerTuning: RouterTuning
  /** Sets one knob for the current profile; a value equal to the profile's is stored as absent. */
  setRouterTuning: (key: TuningKey, value: number) => void
  /** Back to the profile's values (current profile only). */
  resetRouterTuning: () => void
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
    direct?: boolean,
    /** Id of the point being moved: the moved point keeps it (marker not remounted, focus kept). */
    keepId?: string
  ) => void
  removeControlPoint: (index: number, direct?: boolean, zoom?: number) => void
  /** Removes what lies between two bounds frozen by the caller (a menu opened on an imported anchor). */
  removeAnchor: (start: RoutePoint, end: RoutePoint, direct?: boolean) => void
  clearRoute: () => void
  /**
   * Loads a GPX file: it replaces the route, or is added after its last point. Resolves with what
   * was loaded, null when nothing was (refused, failed, cancelled, or another operation running).
   */
  importGpx: (file: File, mode: 'replace' | 'append') => Promise<GpxImportInfo | null>
  undo: () => void
  redo: () => void
}

const ROUTER_PROFILE_STORAGE_KEY = 'pedalons-router-profile'
const ROUTER_TUNING_STORAGE_KEY = 'pedalons-router-tuning'

function isRouterProfile(value: unknown): value is RouterProfile {
  return Object.values(RouterProfile).includes(value as RouterProfile)
}

export function useRoutePlanner(options?: UseRoutePlannerOptions): RoutePlannerState {
  const { initialState, initialTrack, initialAscend, teamSlug } = options || {}
  const { t } = useTranslation()
  // Remembered across sessions; a stale or hand-edited value falls back to the default.
  const [storedProfile, setStoredProfile] = useLocalStorage<RouterProfile>({
    key: ROUTER_PROFILE_STORAGE_KEY,
    defaultValue: RouterProfile.FASTBIKE,
    getInitialValueInEffect: false,
  })
  // Per profile: the knobs of the bicycle profiles. Same distrust of the stored value.
  const [storedTuning, setStoredTuning] = useLocalStorage<RouterTuningStore>({
    key: ROUTER_TUNING_STORAGE_KEY,
    defaultValue: {},
    getInitialValueInEffect: false,
  })
  // Lasts the editing session only: not stored (a forgotten mode would silently draw straight
  // lines next time) and not part of the history. The ref keeps the callbacks stable.
  const [directMode, setDirectModeState] = useState(false)
  const directModeRef = useRef(false)
  const setDirectMode = useCallback((on: boolean) => {
    directModeRef.current = on
    setDirectModeState(on)
  }, [])
  const routerProfile = isRouterProfile(storedProfile) ? storedProfile : RouterProfile.FASTBIKE
  const useHills = sanitizeTuning(storedTuning, routerProfile).useHills
  const useRoads = sanitizeTuning(storedTuning, routerProfile).useRoads
  const routerTuning = useMemo<RouterTuning>(
    () => ({
      ...(useHills !== undefined && { useHills }),
      ...(useRoads !== undefined && { useRoads }),
    }),
    [useHills, useRoads]
  )
  const routerSettings = useMemo(
    () => toRouterSettings(routerProfile, routerTuning),
    [routerProfile, routerTuning]
  )

  // What the planner opens on, computed once: the saved state, else the loaded track as an import
  // of a single piece (with the indices that let a deletion give the file back), else nothing.
  const [initial] = useState<{ route: Route; sources: PlannerSource[] }>(() => {
    if (initialState) {
      try {
        return restorePlannerState(initialState)
      } catch (e) {
        console.warn('planner: the saved state cannot be read, opening the track as an import', e)
      }
    }
    if (initialTrack) {
      return {
        route: createRoute(initialTrack, initialAscend, 0),
        sources: [sourceOf(initialTrack, initialAscend)],
      }
    }
    return { route: computeRoute([]), sources: [] }
  })
  // The loaded tracks, whole. Only ever appended to (later steps add some), and never part of the
  // history: the indices of `sourceId` stay valid for every snapshot.
  const sourcesRef = useRef<PlannerSource[]>(initial.sources)
  const [route, setRoute] = useState<Route>(initial.route)
  const [history, setHistory] = useState<Route[]>([])
  const [future, setFuture] = useState<Route[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const canUndo = history.length > 0
  const canRedo = future.length > 0
  const isDirty = history.length > 0

  // The profile of a saved state is adopted once, on opening: re-routing a piece of a gravel route
  // stays gravel. The other settings are not saved and not touched.
  const adoptedProfile = useRef(false)
  useEffect(() => {
    if (adoptedProfile.current) return
    adoptedProfile.current = true
    if (initialState && isRouterProfile(initialState.profile)) {
      setStoredProfile(initialState.profile)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- on opening only
  }, [])

  const controlPoints = route.points.filter(
    (point, i) => i === 0 || i === route.points.length - 1 || point.manual
  )

  const routeRef = useRef(route)
  const profileRef = useRef(routerProfile)
  const historyLengthRef = useRef(0)
  useEffect(() => {
    routeRef.current = route
    profileRef.current = routerProfile
    historyLengthRef.current = history.length
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

  // Like a profile change: no re-routing, no request, not in the history. Only what is drawn next
  // is routed with the new setting.
  const setRouterTuning = useCallback(
    (key: TuningKey, value: number) => {
      if (!isTunable(routerProfile) || !Number.isFinite(value)) return
      cancelInFlight()
      const clamped = Math.min(1, Math.max(0, value))
      setStoredTuning((previous) => {
        const next = { ...sanitizeTuning(previous, routerProfile) }
        if (clamped === PROFILE_DEFAULTS[routerProfile]?.[key]) delete next[key]
        else next[key] = clamped
        return { ...sanitizeStore(previous), [routerProfile]: next }
      })
    },
    [cancelInFlight, routerProfile, setStoredTuning]
  )

  const resetRouterTuning = useCallback(() => {
    cancelInFlight()
    setStoredTuning((previous) => ({ ...sanitizeStore(previous), [routerProfile]: {} }))
  }, [cancelInFlight, routerProfile, setStoredTuning])

  // Generic executor for all route operations
  // The file imported in place of the track and the routes that are exactly what it produced: the
  // route itself, and the history copies taken of it, so an undo back to it gives the file again.
  const importedRef = useRef<{ file: File; routes: Set<Route> } | null>(null)

  const executeRouteOperation = useCallback(
    async (
      operation: (route: Route, signal: AbortSignal) => Promise<Route>,
      fallbackKey?: TranslationKey
    ): Promise<boolean> => {
      if (inFlightRef.current) return false // lock

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
        if (controller.signal.aborted) return false
        if (importedRef.current?.routes.has(routeRef.current))
          importedRef.current.routes.add(snapshot)
        setHistory((prev) => [...prev, snapshot])
        setFuture([])
        setRoute(newRoute)
        return true
      } catch (e) {
        if (controller.signal.aborted) return false
        setError(plannerErrorMessage(e, t, teamSlug, fallbackKey))
        return false
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
      const straight = direct || directModeRef.current
      executeRouteOperation((route, signal) =>
        add(route, p, routerSettings, straight, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerSettings, teamSlug]
  )

  // Insert a new control point after the given index (returns the new point for immediate dragging)
  const insertControlPoint = useCallback(
    (start: RoutePoint | undefined, p: Point, end: RoutePoint | undefined, direct = false) => {
      const straight = direct || directModeRef.current
      executeRouteOperation((route, signal) =>
        insert(route, start, p, end, routerSettings, straight, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerSettings, teamSlug]
  )

  const updateControlPoint = useCallback(
    (
      start: RoutePoint | undefined,
      p: Point,
      end: RoutePoint | undefined,
      direct = false,
      keepId?: string
    ) => {
      const straight = direct || directModeRef.current
      executeRouteOperation((route, signal) =>
        insert(route, start, p, end, routerSettings, straight, signal, teamSlug, keepId)
      )
    },
    [executeRouteOperation, routerSettings, teamSlug]
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
      const straight = direct || directModeRef.current
      // Between two points of the same import, the file is given back: no request. This comes
      // before the inheritance of a straight span (a point inserted as straight lines on an import
      // gives the file back, not a straight line); an explicit straight line still wins.
      const source =
        !straight && start && end && start.imported && end.imported && start.sourceId !== undefined
          ? sourcesRef.current[start.sourceId]
          : undefined
      if (
        source &&
        start!.sourceId === end!.sourceId &&
        start!.sourceIdx !== undefined &&
        end!.sourceIdx !== undefined &&
        start!.sourceIdx < end!.sourceIdx
      ) {
        executeRouteOperation(async (route, signal) => {
          signal.throwIfAborted()
          return restoreSourceSpan(route, start!, end!, source)
        })
        return
      }
      executeRouteOperation((route, signal) =>
        remove(route, start, end, routerSettings, straight, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerSettings, teamSlug]
  )

  const removeAnchor = useCallback(
    (start: RoutePoint, end: RoutePoint, direct = false) => {
      const straight = direct || directModeRef.current
      // Never gives the file back: smoothing an imported anchor must re-route, giving the file
      // back would change nothing
      executeRouteOperation((route, signal) =>
        remove(route, start, end, routerSettings, straight, signal, teamSlug)
      )
    },
    [executeRouteOperation, routerSettings, teamSlug]
  )

  const clearRoute = useCallback(() => {
    cancelInFlight()
    const snapshot: Route = {
      ...routeRef.current,
      points: routeRef.current.points.map((p) => ({ ...p })),
    }
    if (importedRef.current?.routes.has(routeRef.current)) importedRef.current.routes.add(snapshot)
    setHistory((prev) => [...prev, snapshot])
    setFuture([])
    setRoute(computeRoute([]))
    setError(null)
  }, [cancelInFlight])

  // The last answer of the import endpoint, by identity of the file: a retry (a join that failed)
  // does not send the file again.
  const importCacheRef = useRef<{ key: string; response: GpxImportResponse } | null>(null)
  const importGpx = useCallback(
    async (file: File, mode: 'replace' | 'append'): Promise<GpxImportInfo | null> => {
      const outcome: {
        info: GpxImportInfo | null
        produced: { file: File; routes: Set<Route> } | null
      } = { info: null, produced: null }
      const applied = await executeRouteOperation(async (route, signal) => {
        if (file.size > MAX_IMPORT_BYTES) throw new PlannerRefusedError(IMPORT_TOO_BIG_KEY)
        const key = `${file.name}|${file.size}|${file.lastModified}`
        let response = importCacheRef.current?.key === key ? importCacheRef.current.response : null
        if (!response) {
          response = await importGpxRequest(
            { gpxFile: file, teamSlug },
            { skipErrorToast: true },
            signal
          )
          importCacheRef.current = { key, response }
        }
        signal.throwIfAborted()
        const kept = mode === 'append' ? route.points : []
        const referenced = new Set(kept.map((p) => p.sourceId).filter((id) => id !== undefined))
        if (referenced.size + response.tracks.length > MAX_PLANNER_SOURCES) {
          throw new PlannerRefusedError(IMPORT_TOO_MANY_KEY)
        }
        const sources = response.tracks.map(sourceFromImport)
        const firstId = sourcesRef.current.length
        const imported = routeFromSources(sources, firstId)
        const next =
          mode === 'append'
            ? await appendImport(
                route,
                imported,
                routerSettings,
                directModeRef.current,
                signal,
                teamSlug
              )
            : imported
        signal.throwIfAborted()
        // Only an operation that went through leaves its sources behind
        sourcesRef.current.push(...sources)
        if (mode === 'replace' || route.points.length === 0)
          outcome.produced = { file, routes: new Set([next]) }
        outcome.info = {
          name: response.name,
          waypointCount: response.waypointCount,
          elevationFallback: response.elevationFallback,
          mode,
        }
        return next
      }, IMPORT_FAILED_KEY)
      if (!applied) return null
      importedRef.current = outcome.produced
      return outcome.info
    },
    [executeRouteOperation, routerSettings, teamSlug]
  )

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

  const snapshot = useCallback((): PlannerSnapshot => {
    const current = routeRef.current
    return {
      dirty: historyLengthRef.current > 0,
      plannerState: serializePlannerState(current, sourcesRef.current, profileRef.current),
      ...(importedRef.current?.routes.has(current) && { file: importedRef.current.file }),
      points:
        current.points.length < 2 ? [] : current.points.map((p) => ({ lng: p.lng, lat: p.lat })),
    }
  }, [])

  const routeGeoJson = useMemo(() => {
    if (route.points.length < 2) return null
    return geojson(route)
  }, [route])

  const routeLegsGeoJson = useMemo(() => {
    if (route.points.length < 2) return null
    return legsGeojson(route)
  }, [route])

  const directStats = useMemo(() => computeDirectStats(route), [route])

  return {
    route,
    routeLegsGeoJson,
    directStats,
    directMode,
    setDirectMode,
    controlPoints,
    routeGeoJson,
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
    importGpx,
    canUndo,
    canRedo,
    isDirty,
    snapshot,
    undo,
    redo,
  }
}
