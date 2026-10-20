import { useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { Marker, type MarkerDragEvent } from 'react-map-gl/maplibre'
import { Box, ThemeIcon } from '@mantine/core'
import { useUnits } from '@/hooks/useUnits'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import type { PlacedWaypoint } from '@/lib/plannerWaypoints'
import { waypointTypeOf } from '@/lib/waypoints'
import { WAYPOINT_ICONS } from '../map/waypointIcons'

/** A click this soon after a drag ended is the end of the drag, not a request to open the form. */
const DRAG_CLICK_GRACE_MS = 300
const PIN_SIZE = 26
const TIP_SIZE = 6

interface PlannerWaypointMarkerProps {
  waypoint: PlacedWaypoint
  /** Where the pin is drawn: the point's own position, or the dragged one. */
  lng: number
  lat: number
  /** Off the track, as the point is now or as the drag is shown (free placement). */
  offTrack: boolean
  dragging: boolean
  /** The map is busy (a calculation in flight): the point can be neither moved nor removed. */
  locked: boolean
  onOpen: (key: string) => void
  onRemove: (key: string) => void
  onDragStart: (key: string, event: MarkerDragEvent) => void
  onDrag: (key: string, event: MarkerDragEvent) => void
  onDragEnd: (key: string, event: MarkerDragEvent) => void
}

/**
 * One route point of the planner, as a DOM marker (focusable, draggable, with its own click) rather
 * than a symbol of the map's layer: the consultation views draw the layer, the editor needs a
 * target. Enter or Space opens the form, Delete removes the point.
 */
export function PlannerWaypointMarker({
  waypoint,
  lng,
  lat,
  offTrack,
  dragging,
  locked,
  onOpen,
  onRemove,
  onDragStart,
  onDrag,
  onDragEnd,
}: PlannerWaypointMarkerProps) {
  const { t } = useTranslation()
  const { distance } = useUnits()
  const type = waypointTypeOf(waypoint.type)
  const { Icon } = WAYPOINT_ICONS[type]
  const dragEndedAt = useRef(0)
  const typeLabel = t(`routes.waypoints.type.${type}`)
  const where =
    offTrack || waypoint.distance === null
      ? t('routes.waypoints.offTrack')
      : t('routes.waypoints.fromStart', { distance: distance(waypoint.distance) })

  return (
    <Marker
      longitude={lng}
      latitude={lat}
      anchor="bottom"
      draggable={!locked}
      // Under the control points (2), over the line; the pin being dragged over everything
      style={{ zIndex: dragging ? 3 : 1 }}
      onDragStart={(event) => onDragStart(waypoint.key, event)}
      onDrag={(event) => onDrag(waypoint.key, event)}
      onDragEnd={(event) => {
        dragEndedAt.current = Date.now()
        onDragEnd(waypoint.key, event)
      }}
    >
      <Box
        role="button"
        tabIndex={0}
        className="planner-waypoint mantine-focus-auto"
        aria-label={t('planner.waypoint.marker.label', {
          label: waypoint.name || typeLabel,
          where,
        })}
        aria-keyshortcuts="Enter Delete"
        data-waypoint-key={waypoint.key}
        onClick={(event: React.MouseEvent) => {
          // React listens on the marker's element, below MapLibre's listener on the canvas
          // container: stop the click here, or the map would add a control point under the pin
          event.stopPropagation()
          if (Date.now() - dragEndedAt.current < DRAG_CLICK_GRACE_MS) return
          onOpen(waypoint.key)
        }}
        onContextMenu={(event: React.MouseEvent) => {
          event.preventDefault()
          event.stopPropagation()
          onOpen(waypoint.key)
        }}
        onKeyDown={(event: React.KeyboardEvent) => {
          if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault()
            event.stopPropagation()
            onOpen(waypoint.key)
          } else if (event.key === 'Delete' || event.key === 'Backspace') {
            event.preventDefault()
            event.stopPropagation()
            if (!locked) onRemove(waypoint.key)
          }
        }}
        style={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          cursor: locked ? 'progress' : dragging ? 'grabbing' : 'grab',
          pointerEvents: 'auto',
          opacity: offTrack ? 0.6 : 1,
        }}
      >
        <ThemeIcon
          variant="filled"
          color={WAYPOINT_TYPE_COLORS[type]}
          radius="xl"
          size={PIN_SIZE}
          aria-hidden
          style={{
            border: offTrack ? '2px dashed white' : '2px solid white',
            boxShadow: 'var(--mantine-shadow-md)',
          }}
        >
          <Icon size={15} />
        </ThemeIcon>
        <Box
          aria-hidden
          style={{
            width: 0,
            height: 0,
            borderLeft: `${TIP_SIZE}px solid transparent`,
            borderRight: `${TIP_SIZE}px solid transparent`,
            borderTop: `${TIP_SIZE}px solid white`,
            marginTop: -1,
          }}
        />
      </Box>
    </Marker>
  )
}
