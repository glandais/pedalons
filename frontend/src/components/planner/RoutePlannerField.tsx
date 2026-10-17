import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { useTranslation } from 'react-i18next'
import { IconArrowLeft, IconTrash } from '@tabler/icons-react'
import { ActionIcon, Box, Button, Group, Modal, Text } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GeoPoint } from '@/api/dto'
import { useHistoryOverlay } from '@/hooks/useHistoryOverlay'
import { useMediaMatch } from '@/hooks/useResponsive'
import { useRoutePlanner } from '@/hooks/useRoutePlanner'
import { MapFullscreenShell } from '@/components/map/MapFullscreenShell'
import { MapPanelContext, useMapPanelState } from '@/components/map/mapPanelState'
import { PlannerBottomBar } from './PlannerBottomBar'
import { PlannerStatusChip } from './PlannerStatus'
import { RoutePlanner } from './RoutePlanner'
import { RoutePlannerPreview } from './RoutePlannerPreview'

interface RoutePlannerFieldProps {
  /** Receives the computed path whenever it changes; empty below two points. */
  onPointsChange: (points: GeoPoint[]) => void
  initialTrack?: number[][] // [lng, lat, ele, dist][] from existing route
  teamLocation?: [number, number] // [lng, lat] from team geometry
  /** Team the route is drawn for (team route editor); absent from the GPX tools. Sent to the router. */
  teamSlug?: string
  /** Name of the route being edited, shown in the fullscreen toolbar. */
  title?: string
  /** Tells the form whether the fullscreen editor is open (its Escape must not close the form). */
  onFullscreenChange?: (opened: boolean) => void
  /**
   * A counter the form bumps on a deliberate gesture (the « draw on the map » button): on a finger
   * each bump opens the fullscreen editor. Never opens by itself on load.
   */
  openRequest?: number
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
  onPointsChange,
  initialTrack,
  teamLocation,
  teamSlug,
  title,
  onFullscreenChange,
  openRequest,
}: RoutePlannerFieldProps) {
  const { t } = useTranslation()
  const planner = useRoutePlanner({ initialTrack, teamSlug })
  const { routeGeoJson, controlPoints, route, isLoading, error } = planner
  const isCoarse = useMediaMatch('(pointer: coarse)')
  const { opened, open, close } = useHistoryOverlay()
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
  useEffect(() => {
    onFullscreenChangeRef.current?.(opened)
  }, [opened])
  useEffect(
    () => () => {
      onFullscreenChangeRef.current?.(false)
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

  const stats =
    route.points.length >= 2 ? { distance: route.dist, ascend: route.ascend } : undefined
  const showStatusChip = controlPoints.length > 0 || isLoading || error !== null

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
        <Box
          ref={setInlineSlot}
          h="70dvh"
          style={{
            borderTop: '1px solid var(--mantine-color-default-border)',
            borderBottom: '1px solid var(--mantine-color-default-border)',
          }}
        />
      )}

      {host &&
        attachedHost === host &&
        createPortal(
          <RoutePlanner
            planner={planner}
            layout={opened ? 'fullscreen' : 'inline'}
            active={active}
            onExpand={!isCoarse && !opened ? open : undefined}
            initialTrack={initialTrack}
            teamLocation={teamLocation}
          />,
          host
        )}

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
          <MapFullscreenShell
            leading={
              <ActionIcon variant="subtle" size="lg" onClick={close} aria-label={t('actions.back')}>
                <IconArrowLeft size={20} />
              </ActionIcon>
            }
            title={
              <Modal.Title
                fz="md"
                fw={600}
                lh="inherit"
                style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
              >
                {title?.trim() || t('planner.fullscreen.title')}
              </Modal.Title>
            }
            stats={{ distance: route.dist, gain: route.ascend }}
            actions={
              !isCoarse && (
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
              )
            }
            bottom={
              isCoarse && (
                <Box pos="relative" style={{ flexShrink: 0 }}>
                  {showStatusChip && (
                    <Box
                      pos="absolute"
                      left={8}
                      right={8}
                      pb="xs"
                      style={{
                        bottom: '100%',
                        display: 'flex',
                        justifyContent: 'center',
                        pointerEvents: 'none',
                        zIndex: 5,
                      }}
                    >
                      <PlannerStatusChip
                        pointCount={controlPoints.length}
                        isLoading={isLoading}
                        error={error}
                        stats={stats}
                      />
                    </Box>
                  )}
                  <PlannerBottomBar
                    canUndo={planner.canUndo}
                    canRedo={planner.canRedo}
                    onUndo={planner.undo}
                    onRedo={planner.redo}
                    routerProfile={planner.routerProfile}
                    onProfileChange={planner.setRouterProfile}
                    pointCount={controlPoints.length}
                    onClear={handleClear}
                    onDone={close}
                  />
                </Box>
              )
            }
          >
            <div ref={setFullscreenSlot} style={{ width: '100%', height: '100%' }} />
          </MapFullscreenShell>
        </Modal.Content>
      </Modal.Root>
    </MapPanelContext.Provider>
  )
}
