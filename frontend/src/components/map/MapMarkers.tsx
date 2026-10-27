import { memo, useMemo, type CSSProperties } from 'react'
import { Marker } from 'react-map-gl/maplibre'
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

// Memoized: its map re-renders on every hover move, and a long route carries some 200 markers.
export const KmMarkersLayer = memo(function KmMarkersLayer({
  coords,
  totalDistanceM,
}: KmMarkersLayerProps) {
  const markers = useMemo(() => computeKmMarkers(coords, totalDistanceM), [coords, totalDistanceM])
  return (
    <>
      {markers.map((m) => (
        <KmMarker key={m.label} longitude={m.lng} latitude={m.lat} label={m.label} />
      ))}
    </>
  )
})
