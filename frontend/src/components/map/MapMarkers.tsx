import { useEffect, useState, type CSSProperties } from 'react'
import { Marker, useMap } from 'react-map-gl/maplibre'
import { Box, Text } from '@mantine/core'
import { getOverlayBg } from '@/lib/colors'
import { computeKmMarkers } from './mapUtils'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'

interface MarkerProps {
  longitude: number
  latitude: number
}

export function StartMarker({ longitude, latitude }: MarkerProps) {
  return (
    <Marker longitude={longitude} latitude={latitude} anchor="center">
      <Box
        w={16}
        h={16}
        bg="var(--mantine-color-green-filled)"
        style={{
          borderRadius: '50%',
          border: '2px solid white',
          boxShadow: 'var(--mantine-shadow-lg)',
        }}
      />
    </Marker>
  )
}

export function EndMarker({ longitude, latitude }: MarkerProps) {
  return (
    <Marker longitude={longitude} latitude={latitude} anchor="center">
      <Box
        w={16}
        h={16}
        bg="var(--mantine-color-red-filled)"
        style={{
          borderRadius: '50%',
          border: '2px solid white',
          boxShadow: 'var(--mantine-shadow-lg)',
        }}
      />
    </Marker>
  )
}

export function HoverMarker({
  longitude,
  latitude,
  style,
  testId,
}: MarkerProps & { style?: CSSProperties; testId?: string }) {
  return (
    <Marker longitude={longitude} latitude={latitude} anchor="center" style={style}>
      <Box
        w={24}
        h={24}
        bg="var(--mantine-color-blue-filled)"
        data-testid={testId}
        style={{
          borderRadius: '50%',
          border: '2px solid white',
          boxShadow: 'var(--mantine-shadow-lg)',
        }}
      />
    </Marker>
  )
}

interface KmMarkerProps extends MarkerProps {
  label: string
}

export function KmMarker({ longitude, latitude, label }: KmMarkerProps) {
  const colorScheme = useResolvedColorScheme()
  const labelColor = colorScheme === 'dark' ? 'var(--mantine-color-gray-0)' : '#000000'

  return (
    // A mere label: a press on it is the map's (touch-action auto on the marker would let the
    // browser take the touch for a page scroll, and keep its moves from the planner's anchor drag)
    <Marker
      longitude={longitude}
      latitude={latitude}
      anchor="center"
      style={{ pointerEvents: 'none' }}
    >
      <Box
        w={22}
        h={22}
        style={{
          borderRadius: '50%',
          border: '1.5px solid #AAAAAA',
          backgroundColor: getOverlayBg(colorScheme, true),
          boxShadow: 'var(--mantine-shadow-sm)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Text size="xs" fw={700} style={{ color: labelColor, lineHeight: 1 }}>
          {label}
        </Text>
      </Box>
    </Marker>
  )
}

interface KmMarkersLayerProps {
  coords: number[][]
  totalDistanceM: number
}

export function KmMarkersLayer({ coords, totalDistanceM }: KmMarkersLayerProps) {
  const markers = computeKmMarkers(coords, totalDistanceM)
  return (
    <>
      {markers.map((m) => (
        <KmMarker key={m.label} longitude={m.lng} latitude={m.lat} label={m.label} />
      ))}
    </>
  )
}

interface WaypointMarkerProps extends MarkerProps {
  name?: string
}

/**
 * From this zoom on, a waypoint shows its name; below, only its dot, the name on hover or tap. A
 * route can carry dozens of waypoints (the cobbled sectors of a classic, start and end of each),
 * whose names overlap into an unreadable mass once zoomed out.
 */
export const WAYPOINT_LABEL_MIN_ZOOM = 12

/** Whether the map is zoomed in to at least `minZoom`; re-renders only when that flips. */
function useZoomAtLeast(minZoom: number): boolean {
  const { current: mapRef } = useMap()
  const [above, setAbove] = useState(() => (mapRef ? mapRef.getZoom() >= minZoom : false))

  useEffect(() => {
    if (!mapRef) return
    const map = mapRef.getMap()
    const update = () => setAbove(map.getZoom() >= minZoom)
    update()
    map.on('zoom', update)
    return () => {
      map.off('zoom', update)
    }
  }, [mapRef, minZoom])

  return above
}

export function WaypointMarker({ longitude, latitude, name }: WaypointMarkerProps) {
  const colorScheme = useResolvedColorScheme()
  const labelBg = getOverlayBg(colorScheme)
  const zoomedIn = useZoomAtLeast(WAYPOINT_LABEL_MIN_ZOOM)
  const [revealed, setRevealed] = useState(false)
  const showLabel = !!name && (zoomedIn || revealed)

  // Only the dot is the marker's box, so `center` puts the dot itself on the point; the label is
  // positioned out of the flow and never shifts it (a label inside the box moved the dot left by
  // half its width).
  return (
    <Marker
      longitude={longitude}
      latitude={latitude}
      anchor="center"
      style={{ zIndex: revealed ? 1 : undefined }}
    >
      <Box
        pos="relative"
        w={14}
        h={14}
        bg="var(--mantine-color-yellow-filled)"
        data-testid="waypoint-dot"
        aria-label={name}
        onMouseEnter={() => setRevealed(true)}
        onMouseLeave={() => setRevealed(false)}
        onClick={() => setRevealed(true)}
        style={{
          borderRadius: '50%',
          border: '2px solid white',
          boxShadow: 'var(--mantine-shadow-lg)',
          cursor: name ? 'pointer' : undefined,
        }}
      >
        {showLabel && (
          <Text
            size="xs"
            fw={500}
            px={4}
            pos="absolute"
            left={16}
            top="50%"
            style={{
              transform: 'translateY(-50%)',
              backgroundColor: labelBg,
              borderRadius: 'var(--mantine-radius-sm)',
              boxShadow: 'var(--mantine-shadow-sm)',
              whiteSpace: 'nowrap',
              pointerEvents: 'none',
            }}
          >
            {name}
          </Text>
        )}
      </Box>
    </Marker>
  )
}
