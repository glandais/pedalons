import { useEffect, useRef } from 'react'
import { useControl } from 'react-map-gl/maplibre'
import type { ControlPosition } from 'react-map-gl/maplibre'
import { GeolocateControl } from 'maplibre-gl'
import type { GeolocateControlOptions, GeolocatePositionEvent } from 'maplibre-gl'

const ACTIVE_CLASS = 'maplibregl-ctrl-geolocate-active'

/**
 * MapLibre's geolocate button, made a toggle. The first click behaves as MapLibre's: locate, show
 * the dot, fly there. The next one switches the position off — dot removed, map left where it is.
 *
 * MapLibre does neither on its own: in one-shot mode every click locates and flies again, and in
 * tracking mode a click after the visitor panned away (`BACKGROUND`) re-centres on the position.
 */
class ToggleGeolocateControl extends GeolocateControl {
  /** One-shot mode only: the dot is on the map. Tracking mode keeps its own `_watchState`. */
  private located = false

  constructor(options: GeolocateControlOptions) {
    super(options)
    this.on('geolocate', () => {
      if (this.options.trackUserLocation) return
      this.located = true
      this._geolocateButton.classList.add(ACTIVE_CLASS)
      this._geolocateButton.setAttribute('aria-pressed', 'true')
    })
  }

  override trigger(): boolean {
    if (!this._setup) return super.trigger()

    if (this.options.trackUserLocation) {
      // From ACTIVE_LOCK, MapLibre turns tracking off without moving the camera: take that path.
      if (this._watchState === 'BACKGROUND') this._watchState = 'ACTIVE_LOCK'
      return super.trigger()
    }

    if (!this.located) return super.trigger()
    this.located = false
    this._updateMarker(null)
    this._geolocateButton.classList.remove(ACTIVE_CLASS)
    this._geolocateButton.setAttribute('aria-pressed', 'false')
    return true
  }
}

interface LocateControlProps {
  position?: ControlPosition
  /** Follow the visitor as they move, instead of locating them once. */
  trackUserLocation?: boolean
  /** Each position found — not called when the toggle switches the position off. */
  onGeolocate?: (event: GeolocatePositionEvent) => void
}

/** The « Me localiser » button of the maps, as a toggle — see {@link ToggleGeolocateControl}. */
export function LocateControl({
  position = 'top-left',
  trackUserLocation = false,
  onGeolocate,
}: LocateControlProps) {
  // The control reads its options once, when constructed: the callback goes through a ref.
  const onGeolocateRef = useRef(onGeolocate)
  useEffect(() => {
    onGeolocateRef.current = onGeolocate
  }, [onGeolocate])

  useControl(
    () => {
      const control = new ToggleGeolocateControl({
        trackUserLocation,
        positionOptions: { enableHighAccuracy: true },
      })
      control.on('geolocate', (e) => onGeolocateRef.current?.(e))
      return control
    },
    { position }
  )
  return null
}
