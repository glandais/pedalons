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
  straightEdgesMissingProfile,
  surfaceStats as computeSurfaceStats,
  withDirectProfiles,
  type DirectProfile,
  type PlannerSource,
  type SurfaceStats,
} from '@/lib/planner'
import {
  isElevationUnsupported,
  readDirectProfiles,
  type ElevationCache,
} from '@/lib/plannerElevation'
import { MAX_PLANNER_SOURCES, restorePlannerState, serializePlannerState } from '@/lib/plannerState'
import { RouterProfile, WaypointOrigin } from '@/api/dto'
import type {
  GeoPoint,
  GpxImportResponse,
  PlannerState,
  WaypointDto,
  WaypointRequest,
  WaypointType,
} from '@/api/dto'
import {
  MAX_WAYPOINTS,
  mergeImported,
  nextWaypointKey,
  placeWaypoints,
  toWaypointRequests,
  waypointFromDto,
  waypointFromImport,
  type PlacedWaypoint,
  type PlannerWaypoint,
  type WaypointPlacement,
} from '@/lib/plannerWaypoints'
import { importGpx as importGpxRequest } from '@/api/endpoints/router/router'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import { plannerErrorMessage } from '@/lib/plannerErrors'
import type { PlannerColorBy } from '@/lib/plannerSurface'
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
  /** The route points saved with the route or the preview: the planner opens with them. */
  initialWaypoints?: readonly WaypointDto[]
  /** Length (m) stored with them: the distances they carry were measured on it. */
  initialWaypointsTotal?: number
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
  /**
   * The complete list of the route points, with the ids of the existing ones, only when the user
   * touched them (an undo back to the opening list counts as not touched). Absent: the server keeps
   * them as they are.
   */
  waypoints?: WaypointRequest[]
}

/** What the planner tells about a file it imported, for the view to report. */
export interface GpxImportInfo {
  /** Name of the file: its metadata, else its first track, else its file name. */
  name: string
  /** Route points of the file that the list did not take (more than the 500 a route carries). */
  droppedWaypoints: number
  elevationFallback: boolean
  mode: 'replace' | 'append'
}

/** Biggest file the server takes (GpxLimits.MAX_GPX_SIZE_BYTES). */
export const MAX_IMPORT_BYTES = 10 * 1024 * 1024

/** Quiet time after the last change of the route before the relief of its straight edges is read. */
export const ELEVATION_DEBOUNCE_MS = 300

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
  /** Length of the route by surface class (C1a): paved, unpaved, unknown, off the network. */
  surfaceStats: SurfaceStats
  /** What the profile and the route line are coloured by. Display only: not in the history. */
  colorBy: PlannerColorBy
  setColorBy: (colorBy: PlannerColorBy) => void
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
  /** The author's route points, as edited (no router call, one history entry per operation). */
  waypoints: PlannerWaypoint[]
  /** The same, placed on the current route: distance along it, null off the track. */
  placedWaypoints: PlacedWaypoint[]
  /** Returns the key of the new point, null when refused (500 points, calculation in flight). */
  addWaypoint: (
    at: WaypointPlacement,
    fields: { type: WaypointType; name: string; description: string }
  ) => string | null
  updateWaypoint: (
    key: string,
    fields: Partial<{ type: WaypointType; name: string; description: string }>
  ) => boolean
  /** `distance`: along the route at the new position, null when it is off the track. */
  moveWaypoint: (key: string, position: Point, distance: number | null) => void
  /** True when the point was removed (false: refused while a calculation runs). */
  removeWaypoint: (key: string) => boolean
  clearRoute: () => void
  /**
   * Loads a GPX file: it replaces the route, or is added after its last point. Resolves with what
   * was loaded, null when nothing was (refused, failed, cancelled, or another operation running).
   */
  importGpx: (file: File, mode: 'replace' | 'append') => Promise<GpxImportInfo | null>
  undo: () => void
  redo: () => void
}

/**
 * One state of the history: the route and the route points as they were before an operation, and
 * whether that operation changed the track (a route point's operation does not).
 */
interface PlannerEntry {
  route: Route
  waypoints: PlannerWaypoint[]
  track: boolean
}

function copyRoute(route: Route): Route {
  return { ...route, points: route.points.map((p) => ({ ...p })) }
}

const ROUTER_PROFILE_STORAGE_KEY = 'pedalons-router-profile'
const ROUTER_TUNING_STORAGE_KEY = 'pedalons-router-tuning'

function isRouterProfile(value: unknown): value is RouterProfile {
  return Object.values(RouterProfile).includes(value as RouterProfile)
}

export function useRoutePlanner(options?: UseRoutePlannerOptions): RoutePlannerState {
  const {
    initialState,
    initialTrack,
    initialAscend,
    teamSlug,
    initialWaypoints,
    initialWaypointsTotal,
  } = options || {}
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
  // The author's route points: an immutable list, replaced by every operation. A list that is not,
  // by identity, the one opened on is a list the user touched.
  const [openingWaypoints] = useState<PlannerWaypoint[]>(() =>
    (initialWaypoints ?? []).map((w) => waypointFromDto(w, initialWaypointsTotal))
  )
  const [waypoints, setWaypoints] = useState<PlannerWaypoint[]>(openingWaypoints)
  const waypointsRef = useRef(openingWaypoints)
  const [history, setHistory] = useState<PlannerEntry[]>([])
  const [future, setFuture] = useState<PlannerEntry[]>([])
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
  const historyRef = useRef<PlannerEntry[]>([])
  useEffect(() => {
    routeRef.current = route
    profileRef.current = routerProfile
    historyRef.current = history
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
      operation: (
        route: Route,
        signal: AbortSignal
      ) => Promise<Route | { route: Route; waypoints: PlannerWaypoint[] }>,
      fallbackKey?: TranslationKey
    ): Promise<boolean> => {
      if (inFlightRef.current) return false // lock

      const controller = new AbortController()
      inFlightRef.current = controller
      setIsLoading(true)
      setError(null)

      // Snapshot before the operation mutates the current route's points
      const snapshot = copyRoute(routeRef.current)
      const before = waypointsRef.current

      try {
        const outcome = await operation(routeRef.current, controller.signal)
        if (controller.signal.aborted) return false
        const newRoute = 'waypoints' in outcome ? outcome.route : outcome
        if (importedRef.current?.routes.has(routeRef.current))
          importedRef.current.routes.add(snapshot)
        setHistory((prev) => [...prev, { route: snapshot, waypoints: before, track: true }])
        setFuture([])
        if ('waypoints' in outcome && outcome.waypoints !== before) {
          waypointsRef.current = outcome.waypoints
          setWaypoints(outcome.waypoints)
        }
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

  // The relief of the straight edges (POST /api/router/elevation), read in the background and kept
  // for the session whatever the gestures do (undo, redo and a re-drawn edge find it again). It is
  // display data: applied to the route outside the history, never part of isDirty / canUndo.
  const elevationCacheRef = useRef<ElevationCache>(new Map())
  // An old backend (rolling deployment) answers 404/405: the feature is off for the session.
  const elevationOffRef = useRef(false)
  const elevationRunningRef = useRef(false)
  const elevationAbortRef = useRef<AbortController | null>(null)
  // Bumped when the cache changed: the effect below applies it
  const [elevationTick, setElevationTick] = useState(0)

  useEffect(
    () => () => {
      elevationAbortRef.current?.abort()
      elevationAbortRef.current = null
    },
    []
  )

  useEffect(() => {
    const cache = elevationCacheRef.current
    // (i) what the cache already knows, at once; not during an operation (it would replace the
    // route under it; the effect runs again with the route it produced)
    if (!inFlightRef.current) {
      const next = withDirectProfiles(route, (key) => {
        const known = cache.get(key)
        return known === 'failed' ? undefined : known
      })
      if (next !== route) {
        // An intact import is recognised by the identity of its route: the enriched one is the same file
        if (importedRef.current?.routes.has(route)) importedRef.current.routes.add(next)
        setRoute(next)
        return
      }
    }
    if (elevationOffRef.current) return
    if (!straightEdgesMissingProfile(route).some((edge) => !cache.has(edge.key))) return

    // (ii) one grouped request once the route stopped changing
    const timer = setTimeout(async () => {
      if (elevationRunningRef.current || elevationOffRef.current) return
      const edges = straightEdgesMissingProfile(routeRef.current).filter(
        (edge) => !cache.has(edge.key)
      )
      if (edges.length === 0) return
      elevationRunningRef.current = true
      const controller = new AbortController()
      elevationAbortRef.current = controller
      const read = new Map<string, DirectProfile>()
      let unsupported = false
      try {
        await readDirectProfiles(edges, teamSlug, read, controller.signal)
      } catch (e) {
        if (controller.signal.aborted) return
        // (iv) silent: the climb stays the net one between the ends
        unsupported = isElevationUnsupported(e)
        if (unsupported) elevationOffRef.current = true
      } finally {
        elevationRunningRef.current = false
      }
      for (const edge of edges) {
        const profile = read.get(edge.key)
        if (profile) cache.set(edge.key, profile)
        else if (!unsupported) cache.set(edge.key, 'failed')
      }
      // (iii) applied by the effect, which also waits for an operation in progress
      setElevationTick((n) => n + 1)
    }, ELEVATION_DEBOUNCE_MS)
    return () => clearTimeout(timer)
  }, [route, isLoading, elevationTick, teamSlug])

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
    const snapshot = copyRoute(routeRef.current)
    if (importedRef.current?.routes.has(routeRef.current)) importedRef.current.routes.add(snapshot)
    // The route points stay (off the track): clearing the line does not clear the author's work
    const entry: PlannerEntry = { route: snapshot, waypoints: waypointsRef.current, track: true }
    setHistory((prev) => [...prev, entry])
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
        // The file's route points join the list under the server's rule (a new file replaces the
        // imported ones and keeps the author's), within the 500 a route carries
        const merged = mergeImported(
          waypointsRef.current,
          (response.waypoints ?? []).map(waypointFromImport),
          mode
        )
        // Only an operation that went through leaves its sources behind
        sourcesRef.current.push(...sources)
        if (mode === 'replace' || route.points.length === 0)
          outcome.produced = { file, routes: new Set([next]) }
        outcome.info = {
          name: response.name,
          droppedWaypoints:
            Math.max(0, response.waypointCount - (response.waypoints?.length ?? 0)) +
            merged.dropped,
          elevationFallback: response.elevationFallback,
          mode,
        }
        return { route: next, waypoints: merged.waypoints }
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
    const entry = history[history.length - 1]
    // Taken now: the updaters run later, after the refs below moved
    const undone: PlannerEntry = {
      route: routeRef.current,
      waypoints: waypointsRef.current,
      track: entry.track,
    }
    setFuture((prev) => [undone, ...prev])
    setHistory((h) => h.slice(0, -1))
    waypointsRef.current = entry.waypoints
    setWaypoints(entry.waypoints)
    setRoute(entry.route)
  }, [history, cancelInFlight])

  const redo = useCallback(() => {
    if (inFlightRef.current) {
      cancelInFlight()
      return
    }
    if (future.length === 0) return
    const next = future[0]
    const redone: PlannerEntry = {
      route: routeRef.current,
      waypoints: waypointsRef.current,
      track: next.track,
    }
    setHistory((prev) => [...prev, redone])
    setFuture((f) => f.slice(1))
    waypointsRef.current = next.waypoints
    setWaypoints(next.waypoints)
    setRoute(next.route)
  }, [future, cancelInFlight])

  // --- The author's route points: no router, one history entry per operation ---
  const commitWaypoints = useCallback(
    (change: (list: PlannerWaypoint[]) => PlannerWaypoint[]): boolean => {
      // One operation at a time, like the gestures
      if (inFlightRef.current) return false
      const before = waypointsRef.current
      const after = change(before)
      if (after === before) return false
      // The history never holds the current route itself: add / insert mutate its points. The
      // current route keeps its identity, so an import left intact still is the file.
      const copy = copyRoute(routeRef.current)
      if (importedRef.current?.routes.has(routeRef.current)) importedRef.current.routes.add(copy)
      setHistory((prev) => [...prev, { route: copy, waypoints: before, track: false }])
      setFuture([])
      waypointsRef.current = after
      setWaypoints(after)
      return true
    },
    []
  )

  const addWaypoint = useCallback(
    (
      at: WaypointPlacement,
      fields: { type: WaypointType; name: string; description: string }
    ): string | null => {
      let created = null as string | null
      commitWaypoints((list) => {
        if (list.length >= MAX_WAYPOINTS) return list
        created = nextWaypointKey()
        return [
          ...list,
          {
            key: created,
            origin: WaypointOrigin.AUTHOR,
            type: fields.type,
            name: fields.name,
            description: fields.description,
            lng: at.lng,
            lat: at.lat,
            hint: { distance: at.distance, total: routeRef.current.dist },
          },
        ]
      })
      return created
    },
    [commitWaypoints]
  )

  const updateWaypoint = useCallback(
    (
      key: string,
      fields: Partial<{ type: WaypointType; name: string; description: string }>
    ): boolean => {
      // Refused during a calculation: the caller keeps the form, and what was typed, open
      if (inFlightRef.current) return false
      commitWaypoints((list) => {
        const i = list.findIndex((w) => w.key === key)
        if (i < 0) return list
        const current = list[i]
        const next = { ...current, ...fields }
        if (
          next.type === current.type &&
          next.name === current.name &&
          next.description === current.description
        ) {
          return list
        }
        return list.map((w, k) => (k === i ? next : w))
      })
      return true
    },
    [commitWaypoints]
  )

  const moveWaypoint = useCallback(
    (key: string, position: Point, distance: number | null) => {
      commitWaypoints((list) => {
        const i = list.findIndex((w) => w.key === key)
        if (i < 0) return list
        const current = list[i]
        if (current.lng === position.lng && current.lat === position.lat) return list
        // The hint follows the point while it is on the track; off it, it keeps the last passage
        const hint = distance !== null ? { distance, total: routeRef.current.dist } : current.hint
        return list.map((w, k) =>
          k === i ? { ...w, lng: position.lng, lat: position.lat, hint } : w
        )
      })
    },
    [commitWaypoints]
  )

  const removeWaypoint = useCallback(
    (key: string): boolean =>
      commitWaypoints((list) =>
        list.some((w) => w.key === key) ? list.filter((w) => w.key !== key) : list
      ),
    [commitWaypoints]
  )

  const placedWaypoints = useMemo(() => placeWaypoints(route, waypoints), [route, waypoints])

  const snapshot = useCallback((): PlannerSnapshot => {
    const current = routeRef.current
    return {
      // A route point's operation is in the history without having touched the track
      dirty: historyRef.current.some((entry) => entry.track),
      plannerState: serializePlannerState(current, sourcesRef.current, profileRef.current),
      ...(importedRef.current?.routes.has(current) && { file: importedRef.current.file }),
      points:
        current.points.length < 2 ? [] : current.points.map((p) => ({ lng: p.lng, lat: p.lat })),
      ...(waypointsRef.current !== openingWaypoints && {
        waypoints: toWaypointRequests(placeWaypoints(current, waypointsRef.current)),
      }),
    }
  }, [openingWaypoints])

  const routeGeoJson = useMemo(() => {
    if (route.points.length < 2) return null
    return geojson(route)
  }, [route])

  const routeLegsGeoJson = useMemo(() => {
    if (route.points.length < 2) return null
    return legsGeojson(route)
  }, [route])

  const directStats = useMemo(() => computeDirectStats(route), [route])
  const surfaceStats = useMemo(() => computeSurfaceStats(route), [route])
  const [colorBy, setColorBy] = useState<PlannerColorBy>('grade')

  return {
    route,
    routeLegsGeoJson,
    directStats,
    surfaceStats,
    colorBy,
    setColorBy,
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
    waypoints,
    placedWaypoints,
    addWaypoint,
    updateWaypoint,
    moveWaypoint,
    removeWaypoint,
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
