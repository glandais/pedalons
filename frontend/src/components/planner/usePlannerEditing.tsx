import { useCallback, useEffect, useId, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Group, Text } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { WaypointDto } from '@/api/dto'
import type { ImportGpxOptions, RoutePlannerState } from '@/hooks/useRoutePlanner'
import { cumulativeDistances, plannerRouteToMappable, type Route } from '@/lib/planner'
import { projectOnRoute, toWaypointDto, type WaypointPlacement } from '@/lib/plannerWaypoints'
import type { WaypointFormFields } from './PlannerWaypointForm'

const STRIP_COLLAPSED_KEY = 'pedalons-planner-profile-collapsed'

function readStripCollapsed(): boolean {
  try {
    return localStorage.getItem(STRIP_COLLAPSED_KEY) === '1'
  } catch {
    return false
  }
}

interface PlannerEditingOptions {
  /**
   * Receives the name of an imported file (its metadata, else its first track, else the file name):
   * the host fills its name field with it when that field is still empty.
   */
  onImportName?: (name: string) => void
}

/**
 * What every host of the planner does around the map, whatever shows it: the form of a route
 * point, the profile and the point hovered on it, clearing and removing with their « undo »
 * notification, and the import of a GPX file (replace or append). The site's form field
 * (`RoutePlannerField`) and the planner embedded in the mobile app (`src/embed/mobile-planner`)
 * both read it; `PlannerTouchFullscreen` and `PlannerEditingDialogs` render it
 * (docs/LEDGER_*.md WEB-183).
 */
export function usePlannerEditing(
  planner: RoutePlannerState,
  { onImportName }: PlannerEditingOptions = {}
) {
  const { t } = useTranslation()
  const { controlPoints, route } = planner
  // The profile of the route: one entry per point, and the samples of the straight edges whose
  // relief was read. Shared by the strip (which draws it) and the hover (which translates it).
  // The route points ride along, placed on the route: the profile marks them, and a click on one of
  // its markers (an object of this list) is found again by identity.
  const { placedWaypoints } = planner
  const waypointDtos = useMemo(() => placedWaypoints.map(toWaypointDto), [placedWaypoints])
  const waypointKeyOf = useMemo(
    () => new Map<WaypointDto, string>(waypointDtos.map((dto, i) => [dto, placedWaypoints[i].key])),
    [waypointDtos, placedWaypoints]
  )
  const mappable = useMemo(() => plannerRouteToMappable(route, waypointDtos), [route, waypointDtos])
  // The form of a route point: a new one on a place of the line, or an existing one by its key
  const [waypointForm, setWaypointForm] = useState<
    { mode: 'create'; at: WaypointPlacement } | { mode: 'edit'; key: string } | null
  >(null)
  // Fresh state for every opening of the form (a closing one may still be on screen)
  const [waypointFormSeq, setWaypointFormSeq] = useState(0)
  const editedWaypoint =
    waypointForm?.mode === 'edit'
      ? (placedWaypoints.find((w) => w.key === waypointForm.key) ?? null)
      : null
  // Undone away under the form: nothing left to edit
  const waypointFormOpen =
    waypointForm?.mode === 'create' || (waypointForm?.mode === 'edit' && editedWaypoint !== null)
  const selectedWaypoint = editedWaypoint
    ? (waypointDtos[placedWaypoints.indexOf(editedWaypoint)] ?? null)
    : null
  const openWaypointCreate = useCallback((at: WaypointPlacement) => {
    setWaypointFormSeq((n) => n + 1)
    setWaypointForm({ mode: 'create', at })
  }, [])
  const openWaypointEdit = useCallback((key: string) => {
    setWaypointFormSeq((n) => n + 1)
    setWaypointForm({ mode: 'edit', key })
  }, [])
  const handleSelectWaypoint = useCallback(
    (dto: WaypointDto) => {
      const key = waypointKeyOf.get(dto)
      if (key) openWaypointEdit(key)
    },
    [waypointKeyOf, openWaypointEdit]
  )
  // The point hovered, on the map or on the profile: an index of the profile, valid for the
  // route it was reported on only (any edit drops it). The source matters: the profile follows
  // both, but only a profile hover draws a marker on the map (the ghost point is the map's own).
  const [hover, setHover] = useState<{
    route: Route
    index: number
    source: 'map' | 'profile'
  }>({ route, index: -1, source: 'map' })
  const hoveredIndex = hover.route === route ? hover.index : -1
  const hoverPosition =
    hover.source === 'profile' && hoveredIndex >= 0
      ? (mappable?.positions[hoveredIndex] ?? null)
      : null
  const reportHover = useCallback(
    (source: 'map' | 'profile') => (index: number) =>
      setHover((prev) =>
        prev.route === route && prev.index === index && prev.source === source
          ? prev
          : { route, index, source }
      ),
    [route]
  )
  const handleHoverIndex = useMemo(() => reportHover('profile'), [reportHover])
  const reportMapHover = useMemo(() => reportHover('map'), [reportHover])
  // The map reports an index of route.points: the profile has more entries than the route
  const handleMapHoverIndex = useCallback(
    (index: number) =>
      reportMapHover(index < 0 ? -1 : (mappable?.profileIndexOfRoute[index] ?? -1)),
    [reportMapHover, mappable]
  )
  // On a finger, folded by the summary button of the bottom bar (`PlannerBottomBar`), which
  // controls the element holding the strip (docs/LEDGER_*.md WEB-157).
  const stripId = useId()
  const [stripCollapsed, setStripCollapsed] = useState(readStripCollapsed)
  const toggleStrip = useCallback(() => {
    const next = !stripCollapsed
    setStripCollapsed(next)
    try {
      localStorage.setItem(STRIP_COLLAPSED_KEY, next ? '1' : '0')
    } catch {
      // storage unavailable: the choice lasts the session only
    }
  }, [stripCollapsed])

  // Clear without confirmation (undoing is one tap): the notification offers to take it back.
  const undoRef = useRef(planner.undo)
  useEffect(() => {
    undoRef.current = planner.undo
  })
  const { clearRoute } = planner
  const clearedNotificationId = useRef<string | null>(null)
  const handleClear = useCallback(() => {
    clearRoute()
    const id = `planner-cleared-${Date.now()}`
    clearedNotificationId.current = id
    notifications.show({
      id,
      autoClose: 6000,
      message: (
        <Group justify="space-between" wrap="nowrap" gap="sm">
          <Text size="sm">{t('planner.cleared')}</Text>
          <Button
            size="compact-sm"
            variant="light"
            onClick={() => {
              undoRef.current()
              notifications.hide(id)
            }}
          >
            {t('planner.cleared.undo')}
          </Button>
        </Group>
      ),
    })
  }, [clearRoute, t])

  // « Undo » of the notification takes back the clearing, not whatever came last: once the track
  // changes again (a new point), the offer is withdrawn.
  useEffect(() => {
    const id = clearedNotificationId.current
    if (id && controlPoints.length > 0) {
      clearedNotificationId.current = null
      notifications.hide(id)
    }
  }, [controlPoints.length])

  // Removing a route point needs no confirmation (undoing is one tap): the notification offers to
  // take it back, and is withdrawn once anything else changes.
  const removedNotice = useRef<{
    id: string
    after?: { waypoints: unknown; route: Route }
  } | null>(null)
  const { removeWaypoint } = planner
  const handleWaypointRemove = useCallback(
    (key: string) => {
      if (!removeWaypoint(key)) return
      const id = `planner-waypoint-removed-${Date.now()}`
      removedNotice.current = { id }
      notifications.show({
        id,
        autoClose: 6000,
        message: (
          <Group justify="space-between" wrap="nowrap" gap="sm">
            <Text size="sm">{t('planner.waypoint.deleted')}</Text>
            <Button
              size="compact-sm"
              variant="light"
              onClick={() => {
                // Only while the removal is still the last thing done
                const after = removedNotice.current?.after
                if (
                  after &&
                  after.waypoints === waypointsNowRef.current &&
                  after.route === routeNowRef.current
                ) {
                  undoRef.current()
                }
                notifications.hide(id)
              }}
            >
              {t('planner.cleared.undo')}
            </Button>
          </Group>
        ),
      })
    },
    [removeWaypoint, t]
  )
  const waypointsNowRef = useRef(planner.waypoints)
  const routeNowRef = useRef(route)
  useEffect(() => {
    waypointsNowRef.current = planner.waypoints
    routeNowRef.current = route
    const notice = removedNotice.current
    if (!notice) return
    if (!notice.after) {
      // The render that shows the removal itself
      notice.after = { waypoints: planner.waypoints, route }
      return
    }
    if (notice.after.waypoints !== planner.waypoints || notice.after.route !== route) {
      removedNotice.current = null
      notifications.hide(notice.id)
    }
  }, [planner.waypoints, route])

  const closeWaypointForm = useCallback(() => setWaypointForm(null), [])
  const { addWaypoint, updateWaypoint, moveWaypoint } = planner
  const submitWaypointForm = useCallback(
    (fields: WaypointFormFields) => {
      // Refused while a calculation runs: the form stays open with what was typed
      const applied =
        waypointForm?.mode === 'create'
          ? addWaypoint(waypointForm.at, fields) !== null
          : waypointForm?.mode === 'edit'
            ? updateWaypoint(waypointForm.key, fields)
            : true
      if (applied) setWaypointForm(null)
    },
    [waypointForm, addWaypoint, updateWaypoint]
  )
  const snapWaypoint = useCallback(() => {
    if (!editedWaypoint) return
    const onRoute = projectOnRoute(route, cumulativeDistances(route.points), editedWaypoint)
    if (onRoute) moveWaypoint(editedWaypoint.key, onRoute, onRoute.distance)
    setWaypointForm(null)
  }, [editedWaypoint, route, moveWaypoint])
  const deleteWaypointFromForm = useCallback(() => {
    if (waypointForm?.mode === 'edit') handleWaypointRemove(waypointForm.key)
    setWaypointForm(null)
  }, [waypointForm, handleWaypointRemove])

  // --- Import of a GPX file ---
  // A file waiting for the user to say whether it replaces the route or is added to it.
  const [pendingFile, setPendingFile] = useState<File | null>(null)
  const onImportNameRef = useRef(onImportName)
  useEffect(() => {
    onImportNameRef.current = onImportName
  })
  const { importGpx } = planner
  const [fitRequest, setFitRequest] = useState(0)
  const runImport = useCallback(
    async (file: File, mode: 'replace' | 'append', options?: ImportGpxOptions) => {
      const info = await importGpx(file, mode, options)
      if (!info) return
      setFitRequest((n) => n + 1)
      onImportNameRef.current?.(info.name)
      if (info.elevationFallback) {
        notifications.show({ message: t('planner.import.elevationFallback'), color: 'yellow' })
      }
      // The file's route points join the list (they are saved with it); only the ones past the
      // 500 a route carries are left out
      if (info.droppedWaypoints > 0) {
        notifications.show({
          message: t('planner.import.waypointsDropped', { count: info.droppedWaypoints }),
          color: 'yellow',
        })
      }
    },
    [importGpx, t]
  )
  /** A file the user chose, wherever the host got it from (a file input, the app's picker). */
  const offerFile = (file: File) => {
    // Nothing to lose on an empty route (or a lone point): no question
    if (route.points.length >= 2) setPendingFile(file)
    else void runImport(file, 'replace')
  }
  const choosePendingFile = (mode: 'replace' | 'append') => {
    const file = pendingFile
    setPendingFile(null)
    if (file) void runImport(file, mode)
  }
  const dismissPendingFile = useCallback(() => setPendingFile(null), [])

  const stats =
    route.points.length >= 2 ? { distance: route.dist, ascend: route.ascend } : undefined

  return {
    mappable,
    stats,
    // The profile and what is hovered on it
    hoveredIndex,
    hoverPosition,
    handleHoverIndex,
    handleMapHoverIndex,
    stripId,
    stripCollapsed,
    toggleStrip,
    // The route points and their form
    selectedWaypoint,
    handleSelectWaypoint,
    openWaypointCreate,
    openWaypointEdit,
    handleWaypointRemove,
    waypointForm,
    waypointFormSeq,
    waypointFormOpen,
    editedWaypoint,
    closeWaypointForm,
    submitWaypointForm,
    snapWaypoint,
    deleteWaypointFromForm,
    // Clearing
    handleClear,
    // Import of a GPX file
    fitRequest,
    runImport,
    offerFile,
    pendingFile,
    choosePendingFile,
    dismissPendingFile,
  }
}

export type PlannerEditing = ReturnType<typeof usePlannerEditing>
