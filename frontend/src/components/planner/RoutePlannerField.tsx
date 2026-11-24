import {
  useCallback,
  useEffect,
  useImperativeHandle,
  useLayoutEffect,
  useRef,
  useState,
  type Ref,
} from 'react'
import { createPortal } from 'react-dom'
import { useQueryClient } from '@tanstack/react-query'
import { useTranslation } from 'react-i18next'
import { IconAlertTriangle, IconArrowLeft, IconTrash } from '@tabler/icons-react'
import { ActionIcon, Alert, Box, Button, Group, Modal } from '@mantine/core'
import type { GeoPoint, PlannerState } from '@/api/dto'
import { useHistoryOverlay } from '@/hooks/useHistoryOverlay'
import { useMediaMatch } from '@/hooks/useResponsive'
import {
  useRoutePlanner,
  type ImportGpxOptions,
  type PlannerSnapshot,
} from '@/hooks/useRoutePlanner'

/**
 * A generated route (WEB-179): a replacing import that keeps no file, so the save sends the planner
 * state, and whose source is marked as the generator's, so that state counts in the planner quota.
 */
const GENERATED_IMPORT: ImportGpxOptions = { keepFile: false, generated: true }
import { PlannerQuotaModal } from './PlannerQuotaModal'
import { invalidatePlannerQuota } from '@/lib/plannerQuota'
import { useUnits } from '@/hooks/useUnits'
import type { WaypointDto } from '@/api/dto'
import { DIRECT_WARNING_METERS } from '@/lib/planner'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { decode2 } from '@/lib/polyline'
import { gpxFromLine } from '@/lib/routeGenerator'
import { PlannerEditingDialogs } from './PlannerEditingDialogs'
import { PlannerElevationStrip } from './PlannerElevationStrip'
import { PlannerTouchFullscreen } from './PlannerTouchFullscreen'
import { RoutePlanner } from './RoutePlanner'
import { RoutePlannerPreview } from './RoutePlannerPreview'
import { usePlannerEditing } from './usePlannerEditing'

const STRIP_HEIGHT = 160

/** What a form reads from the planner when it saves. */
export interface RoutePlannerHandle {
  snapshot: () => PlannerSnapshot
}

interface RoutePlannerFieldProps {
  /**
   * The saved editing state of the route being edited: the planner opens on it, without any
   * request. Wins over `initialTrack`, which still frames the map.
   */
  initialState?: PlannerState
  /** Read at submit time: the state to save, and whether the route changed. */
  plannerRef?: Ref<RoutePlannerHandle>
  /** Receives the computed path whenever it changes; empty below two points. */
  onPointsChange: (points: GeoPoint[]) => void
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  /** D+ (m) stored for that track: the reference the loaded track's climb is scaled to. */
  initialAscend?: number
  /** The route points saved with the route or preview: the planner opens with them. */
  initialWaypoints?: readonly WaypointDto[]
  /** Length (m) stored with them: the reference their distances were measured on. */
  initialWaypointsTotal?: number
  teamLocation?: [number, number] // [lng, lat] from team geometry
  /** Team the route is drawn for (team route editor); absent from the GPX tools. Sent to the router. */
  teamSlug?: string
  /** Name of the route being edited, shown in the fullscreen toolbar. */
  title?: string
  /** Tells the form whether the fullscreen editor is open (its Escape must not close the form). */
  onFullscreenChange?: (opened: boolean) => void
  /** Tells the form whether a calculation is in flight: its save waits for it. */
  onBusyChange?: (busy: boolean) => void
  /**
   * Receives the name of an imported file (its metadata, else its first track, else the file name):
   * the form fills its name field with it when that field is still empty.
   */
  onImportName?: (name: string) => void
  /**
   * A counter the form bumps on a deliberate gesture (the « draw on the map » button): on a finger
   * each bump opens the fullscreen editor. Never opens by itself on load.
   */
  openRequest?: number
  /**
   * A route generated from the team's own roads, to load in place of the track (route generator,
   * ledger WEB-179). Handled once per `seq`; the points are loaded as an import that keeps no file,
   * so the save sends the planner state and draws the planner quota.
   */
  importRequest?: PlannerImportRequest
  /** Told once the request is taken, so the host drops it: the field unmounts when the source switches. */
  onImportHandled?: (seq: number) => void
}

/** A generated route handed to the planner: `seq` is bumped for each new candidate. */
export interface PlannerImportRequest {
  seq: number
  /** Polyline of precision 6 (latitude then longitude). */
  polyline: string
  /** Name written in the GPX, the form fills its empty name field with it. */
  name: string
  /**
   * Replace the route on screen without asking: the person already chose this track to replace
   * the saved one (« Modifier » of a retouch, ledger `WEB-203`).
   */
  replace?: boolean
}

/**
 * The route planner of a form: owns the planner's state and shows it in the form (a map on a
 * mouse, a still preview on a finger) or in a fullscreen editor above the form.
 *
 * <p>There is only ever one MapLibre instance. {@link RoutePlanner} is rendered once, into a host
 * element React does not manage, which this component moves between the form's slot and the
 * dialog's slot: the WebGL canvas, the view, the history and the pending gesture survive the move.
 * The planner state lives here, above both, so closing the dialog (or never opening it) costs no
 * routing request. On a finger the map is not even built until the editor is first opened.
 */
export function RoutePlannerField({
  initialState,
  plannerRef,
  onPointsChange,
  initialTrack,
  initialAscend,
  initialWaypoints,
  initialWaypointsTotal,
  teamLocation,
  teamSlug,
  title,
  onFullscreenChange,
  onBusyChange,
  onImportName,
  openRequest,
  importRequest,
  onImportHandled,
}: RoutePlannerFieldProps) {
  const { t } = useTranslation()
  const planner = useRoutePlanner({
    initialState,
    initialTrack,
    initialAscend,
    teamSlug,
    initialWaypoints,
    initialWaypointsTotal,
  })
  const { snapshot } = planner
  useImperativeHandle(plannerRef, () => ({ snapshot }), [snapshot])
  // A calculation refused at a spent quota: the quota the entry points read is stale (used < limit)
  // and refreshed, as a refused save does (usePlannerQuotaRefusal) — else they stay enabled and
  // every further attempt meets the same dialog (docs/LEDGER_*.md BILL-10).
  const queryClient = useQueryClient()
  const { quotaRefusal } = planner
  useEffect(() => {
    if (!quotaRefusal) return
    if (quotaRefusal.scope === 'PERSONAL') invalidatePlannerQuota(queryClient)
    else if (teamSlug) invalidatePlannerQuota(queryClient, teamSlug)
  }, [quotaRefusal, queryClient, teamSlug])
  const { routeGeoJson, controlPoints, route, isLoading, directStats } = planner
  const { distance } = useUnits()
  const isCoarse = useMediaMatch('(pointer: coarse)')
  const { opened, open, close } = useHistoryOverlay()
  // What the planner does around the map: shared with its other host, the page the mobile app
  // embeds (docs/LEDGER_*.md WEB-183).
  const editing = usePlannerEditing(planner, { onImportName })
  const {
    mappable,
    hoveredIndex,
    hoverPosition,
    handleHoverIndex,
    handleMapHoverIndex,
    selectedWaypoint,
    handleSelectWaypoint,
    openWaypointCreate,
    openWaypointEdit,
    handleWaypointRemove,
    waypointFormOpen,
    handleClear,
    fitRequest,
    runImport,
    offerFile,
  } = editing
  const panelState = useMapPanelState()
  const { setOpenId } = panelState

  // Notify the form when the route changes: the complete computed path
  useEffect(() => {
    if (!routeGeoJson || routeGeoJson.coordinates.length < 2) {
      onPointsChange([])
      return
    }
    onPointsChange(routeGeoJson.coordinates.map((coords) => ({ lng: coords[0], lat: coords[1] })))
  }, [routeGeoJson, onPointsChange])

  // A panel left open must not reappear when the map changes place.
  useEffect(() => {
    setOpenId(null)
  }, [opened, setOpenId])

  // The form's escape hatch must not fire while the dialog is up (see CreateRouteModal).
  const onFullscreenChangeRef = useRef(onFullscreenChange)
  useEffect(() => {
    onFullscreenChangeRef.current = onFullscreenChange
  })
  // Reported to the form: a dialog above it (the editor, or a route point's form) owns Escape
  useEffect(() => {
    onFullscreenChangeRef.current?.(opened || waypointFormOpen)
  }, [opened, waypointFormOpen])
  useEffect(
    () => () => {
      onFullscreenChangeRef.current?.(false)
    },
    []
  )

  // A calculation in flight (a routed leg, an imported file) is not in the snapshot yet: the form
  // must not save until it lands, or it saves the route as it was before the gesture.
  const onBusyChangeRef = useRef(onBusyChange)
  useEffect(() => {
    onBusyChangeRef.current = onBusyChange
  })
  useEffect(() => {
    onBusyChangeRef.current?.(isLoading)
  }, [isLoading])
  useEffect(
    () => () => {
      onBusyChangeRef.current?.(false)
    },
    []
  )

  // Opening on request (a gesture of the form), on a finger only.
  const handledRequest = useRef(0)
  useEffect(() => {
    if (!openRequest || openRequest <= handledRequest.current) return
    handledRequest.current = openRequest
    if (isCoarse) open()
  }, [openRequest, isCoarse, open])

  // --- The host element and the two slots it moves between ---
  const [host, setHost] = useState<HTMLDivElement | null>(null)
  const [inlineSlot, setInlineSlot] = useState<HTMLDivElement | null>(null)
  const [fullscreenSlot, setFullscreenSlot] = useState<HTMLDivElement | null>(null)
  // The host the planner may be rendered into: one that has been put in a slot at least once, so
  // the map is built in a container with its real size (the fit of the track depends on it).
  const [attachedHost, setAttachedHost] = useState<HTMLDivElement | null>(null)

  // Created on the client only: nothing browser-side at module level or while rendering.
  useEffect(() => {
    const element = document.createElement('div')
    element.style.width = '100%'
    element.style.height = '100%'
    setHost(element)
    return () => {
      element.remove()
      setHost(null)
    }
  }, [])

  useLayoutEffect(() => {
    if (!host) return
    // Open: the dialog's slot (wait for the dialog to mount it). Closed: the form's slot on a
    // mouse; on a finger nowhere, the map stays mounted off-screen and the form shows a preview.
    const target = opened ? fullscreenSlot : isCoarse ? null : inlineSlot
    if (opened && !target) return
    if (target) {
      if (host.parentElement !== target) target.appendChild(host)
      setAttachedHost(host)
    } else {
      host.remove()
    }
  }, [host, opened, fullscreenSlot, inlineSlot, isCoarse])

  // The planner answers the keyboard only while it is on screen.
  const active = opened || !isCoarse

  // --- Import of a GPX file ---
  const fileInputRef = useRef<HTMLInputElement>(null)
  // A generated route: loaded as a replacing import that keeps no file (WEB-179). Over an existing
  // route the person is asked first.
  const [pendingGenerated, setPendingGenerated] = useState<File | null>(null)
  const handledImportSeq = useRef(0)
  useEffect(() => {
    if (!importRequest || importRequest.seq <= handledImportSeq.current) return
    handledImportSeq.current = importRequest.seq
    onImportHandled?.(importRequest.seq)
    const file = new File(
      [gpxFromLine(importRequest.name, decode2(importRequest.polyline))],
      'parcours-genere.gpx',
      { type: 'application/gpx+xml' }
    )
    if (route.points.length >= 2 && !importRequest.replace) setPendingGenerated(file)
    else void runImport(file, 'replace', GENERATED_IMPORT)
  }, [importRequest, onImportHandled, route.points.length, runImport])
  const openFilePicker = useCallback(() => fileInputRef.current?.click(), [])
  const handleFileChosen = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    // Reset, so that choosing the same file again fires a change
    event.target.value = ''
    if (!file) return
    offerFile(file)
  }

  const backButton = (
    <ActionIcon variant="subtle" size="lg" onClick={close} aria-label={t('actions.back')}>
      <IconArrowLeft size={20} />
    </ActionIcon>
  )
  const dialogTitle = (
    <Modal.Title
      fz="md"
      fw={600}
      lh="inherit"
      style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
    >
      {title?.trim() || t('planner.fullscreen.title')}
    </Modal.Title>
  )

  // Non-blocking: one long straight leg is a forgotten key or a crossing to check, short ones are
  // normal (a gap in the network, a square).
  const directWarning = directStats.longest > DIRECT_WARNING_METERS && (
    <Alert
      color="yellow"
      variant="light"
      icon={<IconAlertTriangle />}
      mx={isCoarse ? 'md' : undefined}
      mt="sm"
    >
      {t('planner.directWarning', {
        total: distance(directStats.total),
        longest: distance(directStats.longest),
      })}
    </Alert>
  )

  return (
    <MapPanelContext.Provider value={panelState}>
      {isCoarse ? (
        <RoutePlannerPreview
          routeGeoJson={routeGeoJson}
          pointCount={controlPoints.length}
          distance={route.dist}
          ascend={route.ascend}
          onOpen={open}
        />
      ) : (
        <>
          <Box
            ref={setInlineSlot}
            h="70dvh"
            style={{
              borderTop: '1px solid var(--mantine-color-default-border)',
              borderBottom: opened ? '1px solid var(--mantine-color-default-border)' : undefined,
            }}
          />
          {/* Under the dialog the editor shows its own strip: one chart at a time */}
          {!opened && (
            <Box style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}>
              <PlannerElevationStrip
                mappable={mappable}
                hoveredIndex={hoveredIndex}
                colorBy={planner.colorBy}
                onColorByChange={planner.setColorBy}
                surfaceStats={planner.surfaceStats}
                onHoverIndex={handleHoverIndex}
                height={STRIP_HEIGHT}
                selectedWaypoint={selectedWaypoint}
                onSelectWaypoint={handleSelectWaypoint}
              />
            </Box>
          )}
        </>
      )}

      {directWarning}

      <input
        ref={fileInputRef}
        type="file"
        accept=".gpx"
        hidden
        aria-label={t('planner.import')}
        data-testid="planner-import-input"
        onChange={handleFileChosen}
      />
      <ConfirmDialog
        isOpen={pendingGenerated !== null}
        onClose={() => setPendingGenerated(null)}
        onConfirm={() => {
          const file = pendingGenerated
          setPendingGenerated(null)
          if (file) void runImport(file, 'replace', GENERATED_IMPORT)
        }}
        title={t('routeGenerator.replaceTrack.title')}
        message={t('routeGenerator.replaceTrack.text')}
        confirmText={t('planner.import.replace')}
      />
      <PlannerEditingDialogs planner={planner} editing={editing} />

      {host &&
        attachedHost === host &&
        createPortal(
          <RoutePlanner
            planner={planner}
            layout={opened ? 'fullscreen' : 'inline'}
            active={active}
            onExpand={!isCoarse && !opened ? open : undefined}
            onImport={openFilePicker}
            fitRequest={fitRequest}
            initialTrack={initialTrack}
            teamLocation={teamLocation}
            hoverPosition={hoverPosition}
            onHoverIndex={handleMapHoverIndex}
            onWaypointAdd={openWaypointCreate}
            onWaypointOpen={openWaypointEdit}
            onWaypointRemove={handleWaypointRemove}
          />,
          host
        )}

      {/* A calculation refused at a spent quota: why, and what is still possible (BILL-10) */}
      <PlannerQuotaModal refusal={planner.quotaRefusal} onClose={planner.dismissQuotaRefusal} />

      <Modal.Root
        opened={opened}
        onClose={close}
        fullScreen
        padding={0}
        // Escape never closes the editor (« Done », the back arrow or the browser's back do), nor,
        // through it, the form underneath. It still closes a map panel or the search results.
        closeOnEscape={false}
        // The shell already covers the screen; the scroll lock would also block the wheel on the
        // map panels, which are portalled out of the dialog.
        lockScroll={false}
        // MapLibre must not measure its container mid-animation.
        transitionProps={{ duration: 0 }}
      >
        <Modal.Content h="100dvh">
          {isCoarse ? (
            <PlannerTouchFullscreen
              planner={planner}
              editing={editing}
              leading={backButton}
              title={dialogTitle}
              onImport={openFilePicker}
              onDone={close}
            >
              <div ref={setFullscreenSlot} style={{ width: '100%', height: '100%' }} />
            </PlannerTouchFullscreen>
          ) : (
            <MapFullscreenShell
              leading={backButton}
              title={dialogTitle}
              stats={{ distance: route.dist, gain: route.ascend }}
              actions={
                <Group gap="xs" wrap="nowrap">
                  <ActionIcon
                    variant="subtle"
                    color="red"
                    size="lg"
                    onClick={handleClear}
                    disabled={controlPoints.length === 0}
                    title={t('planner.clear')}
                    aria-label={t('planner.clear')}
                  >
                    <IconTrash size={18} />
                  </ActionIcon>
                  <Button size="compact-md" onClick={close}>
                    {t('planner.done')}
                  </Button>
                </Group>
              }
              bottom={
                <PlannerElevationStrip
                  mappable={mappable}
                  hoveredIndex={hoveredIndex}
                  colorBy={planner.colorBy}
                  onColorByChange={planner.setColorBy}
                  surfaceStats={planner.surfaceStats}
                  onHoverIndex={handleHoverIndex}
                  height={STRIP_HEIGHT}
                  selectedWaypoint={selectedWaypoint}
                  onSelectWaypoint={handleSelectWaypoint}
                />
              }
            >
              <div ref={setFullscreenSlot} style={{ width: '100%', height: '100%' }} />
            </MapFullscreenShell>
          )}
        </Modal.Content>
      </Modal.Root>
    </MapPanelContext.Provider>
  )
}
