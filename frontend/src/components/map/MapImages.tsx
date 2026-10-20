import { useEffect } from 'react'
import { useMap } from 'react-map-gl/maplibre'
import { PRELOADED_IMAGE_IDS, resolveMapImage } from './mapImages'

/**
 * Registers the images the map's layers use (the direction chevron, the waypoint pictograms and
 * labels) and is the map's one missing-image resolver — MapLibre keeps a single one, so a second
 * component setting its own would silently replace this. A basemap switch replaces the style and
 * drops its images; the resolver re-adds whichever a layer asks for. The resolver alone is not
 * enough for the fixed ones: a layer that asked before this effect ran has already been told
 * « missing », and only an `addImage` makes its tiles reload with the image, so they are added
 * ahead. Labels are drawn on demand.
 * `PedalonsMap` renders it; a bare `Map` that draws a trace renders it itself.
 */
export function MapImages() {
  const { current: mapRef } = useMap()

  useEffect(() => {
    if (!mapRef) return
    const map = mapRef.getMap()
    map.setMissingStyleImageResolver((id) => resolveMapImage(map, id))
    if (map.style) {
      for (const id of PRELOADED_IMAGE_IDS) void resolveMapImage(map, id)
    }
    return () => {
      map.setMissingStyleImageResolver(null)
    }
  }, [mapRef])

  return null
}
