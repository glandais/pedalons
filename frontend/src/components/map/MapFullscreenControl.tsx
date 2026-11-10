import { FullscreenControl } from 'react-map-gl/maplibre'
import { useMapZones } from './mapZones'

/**
 * MapLibre's fullscreen button, in the camera column after « Me localiser » (`mapZones.ts`). A
 * child of the map: the zone is read when the control mounts, in the browser.
 */
export function MapFullscreenControl() {
  const { camera } = useMapZones()
  return <FullscreenControl position={camera} />
}
