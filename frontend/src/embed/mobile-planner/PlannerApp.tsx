import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { IconArrowLeft } from '@tabler/icons-react'
import { ActionIcon, Text } from '@mantine/core'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { PlannerEditingDialogs } from '@/components/planner/PlannerEditingDialogs'
import {
  PlannerMapControlsContext,
  type PlannerMapControls,
} from '@/components/planner/plannerMapControls'
import { PlannerTouchFullscreen } from '@/components/planner/PlannerTouchFullscreen'
import { RoutePlanner } from '@/components/planner/RoutePlanner'
import { usePlannerEditing } from '@/components/planner/usePlannerEditing'
import { useRoutePlanner, type ImportGpxOptions } from '@/hooks/useRoutePlanner'
import { decode2 } from '@/lib/polyline'
import { gpxFromLine } from '@/lib/routeGenerator'
import { BridgeLocateControl, BridgeSearchControl } from './BridgeMapControls'
import { onGpx, onTest, post, type PlannerLoad } from './bridge'
import { doneMessage } from './done'

/** A generated route: a replacing import that keeps no file, as the site's `RoutePlannerField`. */
const GENERATED_IMPORT: ImportGpxOptions = { keepFile: false, generated: true }

/** The planner's two outward-reaching controls, over the bridge. */
const BRIDGE_MAP_CONTROLS: PlannerMapControls = {
  Search: BridgeSearchControl,
  Locate: BridgeLocateControl,
}

/** The same without « Me localiser », for an app that does not offer the position (`load.locate`). */
const BRIDGE_MAP_CONTROLS_NO_LOCATE: PlannerMapControls = {
  Search: BridgeSearchControl,
  Locate: () => null,
}

const pickGpx = () => post({ type: 'pickGpx' })

/**
 * The planner as the mobile app shows it: the site's touch fullscreen editor
 * (`PlannerTouchFullscreen`, shared with `RoutePlannerField`), always open, filling the WebView.
 * What the site's form does around its field is the app's here, told over the bridge: the way
 * back, the file picker, the quota dialog, the save.
 */
export function PlannerApp({ load }: { load: PlannerLoad }) {
  const { t } = useTranslation()
  const planner = useRoutePlanner({
    initialState: load.state,
    initialTrack: load.track,
    initialAscend: load.ascend,
    teamSlug: load.teamSlug,
    initialWaypoints: load.waypoints,
    initialWaypointsTotal: load.waypointsTotal,
  })
  // The name of the last file imported: the app fills its name field with it when still empty
  const nameSuggestion = useRef<string | undefined>(undefined)
  const editing = usePlannerEditing(planner, {
    onImportName: (name) => {
      nameSuggestion.current = name
    },
  })
  const panelState = useMapPanelState()
  const { isLoading, isDirty, editMark, quotaRefusal, dismissQuotaRefusal } = planner
  // The edit « Terminer » last handed over: what the map shows past it is what the form would not
  // send. Before any « Terminer », everything since `load` is.
  const [doneMark, setDoneMark] = useState<object | null | undefined>(undefined)
  const pending = doneMark === undefined ? isDirty : editMark !== doneMark

  // A calculation in flight is not in the snapshot yet: the app's save waits for it.
  useEffect(() => {
    post({ type: 'busy', busy: isLoading })
  }, [isLoading])

  // What the app's « leave without saving? » asks about, and whether the form has it all.
  useEffect(() => {
    post({ type: 'dirty', dirty: isDirty, pending })
  }, [isDirty, pending])

  // A calculation refused at a spent quota: the dialog is the app's, which also reads the team
  // again (docs/LEDGER_*.md BILL-10).
  useEffect(() => {
    if (!quotaRefusal) return
    post({
      type: 'quotaRefused',
      scope: quotaRefusal.scope,
      limit: quotaRefusal.limit,
      current: quotaRefusal.current,
      resetsOn: quotaRefusal.resetsOn,
      ...(quotaRefusal.teamName && { teamName: quotaRefusal.teamName }),
    })
    dismissQuotaRefusal()
  }, [quotaRefusal, dismissQuotaRefusal])

  // The file picked in the app, answering `pickGpx`.
  const offerFileRef = useRef(editing.offerFile)
  useEffect(() => {
    offerFileRef.current = editing.offerFile
  })
  useEffect(
    () =>
      onGpx((file) => {
        if (file) offerFileRef.current(file)
      }),
    []
  )

  // A proposal of the route generator (MOB-154): imported once, on the empty route of a creation.
  const { runImport } = editing
  const generatedDone = useRef(false)
  useEffect(() => {
    const generated = load.generated
    if (!generated || generatedDone.current) return
    generatedDone.current = true
    const file = new File(
      [gpxFromLine(generated.name, decode2(generated.polyline))],
      'parcours-genere.gpx',
      { type: 'application/gpx+xml' }
    )
    void runImport(file, 'replace', GENERATED_IMPORT)
  }, [load.generated, runImport])

  const create = load.create ?? (!load.state && !load.track)
  const done = () => {
    // The leg being computed would be missing from the snapshot
    if (isLoading) return
    setDoneMark(editMark)
    post(
      doneMessage({
        snapshot: planner.snapshot(),
        create,
        distance: planner.route.dist,
        ascend: planner.route.ascend,
        pointCount: planner.controlPoints.length,
        dirty: isDirty,
        nameSuggestion: nameSuggestion.current,
      })
    )
  }

  // Test only (`load.testCommands`, the app's Patrol suite): points placed one after the other as
  // straight lines (no routing request), each once the previous one is in the route, then
  // « Terminer ». Without the flag nothing is subscribed and the queue stays empty.
  const { addControlPoint } = planner
  const doneRef = useRef(done)
  useEffect(() => {
    doneRef.current = done
  })
  const [testSteps, setTestSteps] = useState<({ lng: number; lat: number } | 'done')[]>([])
  useEffect(() => {
    if (!load.testCommands) return
    return onTest((command) =>
      setTestSteps((steps) => [
        ...steps,
        ...(command.place ?? []),
        ...(command.done ? (['done'] as const) : []),
      ])
    )
  }, [load.testCommands])
  useEffect(() => {
    if (isLoading || testSteps.length === 0) return
    const [step, ...rest] = testSteps
    setTestSteps(rest)
    if (step === 'done') doneRef.current()
    else if (step) addControlPoint(step, true)
  }, [testSteps, isLoading, addControlPoint])

  return (
    <MapPanelContext.Provider value={panelState}>
      <PlannerMapControlsContext.Provider
        value={load.locate ? BRIDGE_MAP_CONTROLS : BRIDGE_MAP_CONTROLS_NO_LOCATE}
      >
        <PlannerTouchFullscreen
          planner={planner}
          editing={editing}
          leading={
            <ActionIcon
              variant="subtle"
              size="lg"
              onClick={() => post({ type: 'close', dirty: isDirty, pending })}
              aria-label={t('actions.back')}
            >
              <IconArrowLeft size={20} />
            </ActionIcon>
          }
          title={
            <Text component="h1" fz="md" fw={600} lh="inherit" m={0} truncate>
              {load.routeName?.trim() || t('planner.fullscreen.title')}
            </Text>
          }
          onImport={pickGpx}
          onDone={done}
        >
          <RoutePlanner
            planner={planner}
            layout="fullscreen"
            active
            onImport={pickGpx}
            fitRequest={editing.fitRequest}
            initialTrack={load.track}
            teamLocation={load.teamLocation}
            hoverPosition={editing.hoverPosition}
            onHoverIndex={editing.handleMapHoverIndex}
            onWaypointAdd={editing.openWaypointCreate}
            onWaypointOpen={editing.openWaypointEdit}
            onWaypointRemove={editing.handleWaypointRemove}
          />
        </PlannerTouchFullscreen>
        <PlannerEditingDialogs planner={planner} editing={editing} />
      </PlannerMapControlsContext.Provider>
    </MapPanelContext.Provider>
  )
}
