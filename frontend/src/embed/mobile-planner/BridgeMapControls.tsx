import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { useTranslation } from 'react-i18next'
import { useControl, useMap } from 'react-map-gl/maplibre'
import { Marker, type IControl } from 'maplibre-gl'
import type { GeocodeResultDto } from '@/api/dto'
import type { SearchedPlace } from '@/components/map/MapSearchControl'
import { useMapZones } from '@/components/map/mapZones'
import { onPosition, post, resolvePlace, searchPlaces } from './bridge'
// The site's search box styles, which this one wears (the package's script stays out: stubs/)
import '@stadiamaps/maplibre-search-box/dist/maplibre-search-box.css'

const MIN_QUERY_LENGTH = 3
const SEARCH_DEBOUNCE_MS = 300
/** Close enough to read the streets around the place picked. */
const PLACE_ZOOM = 14

/** A control box React renders into, with the classes the site's CSS already styles. */
class BoxControl implements IControl {
  readonly container = document.createElement('div')

  constructor(private readonly className: string) {}

  onAdd() {
    this.container.className = `maplibregl-ctrl ${this.className}`
    return this.container
  }

  onRemove() {
    this.container.remove()
  }
}

/**
 * The place search of the embedded planner: `GET /api/geocode/search` then, for the suggestion
 * picked only, `GET /api/geocode/place`, both through the app. The site's own search box talks to
 * Stadia Maps from the browser, authenticated by the page's origin, which a page loaded from a
 * file does not have. It wears that box's classes, so index.css styles it the same.
 */
export function BridgeSearchControl({
  onResultSelected,
}: {
  onResultSelected?: (place: SearchedPlace) => void
}) {
  const { t } = useTranslation()
  const { current: map } = useMap()
  const control = useControl(() => new BoxControl('maplibre-search-box'), { position: 'top-left' })
  const [query, setQuery] = useState('')
  // Null: no list on screen. An empty list says « no result ».
  const [results, setResults] = useState<GeocodeResultDto[] | null>(null)
  const [failed, setFailed] = useState(false)
  const resolving = useRef<AbortController | null>(null)
  useEffect(() => () => resolving.current?.abort(), [])

  useEffect(() => {
    const term = query.trim()
    if (term.length < MIN_QUERY_LENGTH) return
    const controller = new AbortController()
    const timer = window.setTimeout(() => {
      searchPlaces(term, controller.signal).then(
        (found) => setResults(found),
        () => {
          if (!controller.signal.aborted) setResults([])
        }
      )
    }, SEARCH_DEBOUNCE_MS)
    return () => {
      window.clearTimeout(timer)
      controller.abort()
    }
  }, [query])

  const handleChange = (value: string) => {
    setQuery(value)
    setFailed(false)
    if (value.trim().length < MIN_QUERY_LENGTH) setResults(null)
  }

  const pick = async (result: GeocodeResultDto) => {
    setQuery('')
    setResults(null)
    resolving.current?.abort()
    const controller = new AbortController()
    resolving.current = controller
    try {
      // A suggestion usually has no position: one billed lookup, for the one picked
      const place =
        result.lat != null && result.lon != null
          ? result
          : await resolvePlace(result.id, controller.signal)
      if (controller.signal.aborted) return
      if (place.lat == null || place.lon == null) {
        setFailed(true)
        return
      }
      map?.flyTo({ center: [place.lon, place.lat], zoom: PLACE_ZOOM })
      onResultSelected?.({ lng: place.lon, lat: place.lat, label: result.displayName })
    } catch {
      if (!controller.signal.aborted) setFailed(true)
    }
  }

  return createPortal(
    <>
      <div className="input-container">
        <input
          type="search"
          enterKeyHint="search"
          autoComplete="off"
          value={query}
          placeholder={t('map.search.placeholder')}
          aria-label={t('map.search.placeholder')}
          onChange={(event) => handleChange(event.currentTarget.value)}
        />
      </div>
      {(results || failed) && (
        <div className="results">
          <div className="results-list" role="listbox">
            {failed && <div className="result no-result">{t('geocoder.resolveFailed')}</div>}
            {results?.length === 0 && (
              <div className="result no-result">{t('map.search.noResults')}</div>
            )}
            {results?.map((result) => (
              <div
                key={result.id}
                className="result"
                role="option"
                aria-selected={false}
                tabIndex={0}
                onClick={() => void pick(result)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') void pick(result)
                }}
              >
                <div className="result-label">{result.displayName}</div>
              </div>
            ))}
          </div>
          {/* The credit Stadia Maps' terms want next to its results. */}
          {results && results.length > 0 && (
            <div className="search-attribution">{t('geocoder.attribution')}</div>
          )}
        </div>
      )}
    </>,
    control.container
  )
}

/** MapLibre's geolocate button, as its own control builds it: the theme draws the icon. */
class LocateButtonControl extends BoxControl {
  readonly button = document.createElement('button')

  constructor() {
    super('maplibregl-ctrl-group')
    this.button.type = 'button'
    this.button.className = 'maplibregl-ctrl-geolocate'
    const icon = document.createElement('span')
    icon.className = 'maplibregl-ctrl-icon'
    icon.setAttribute('aria-hidden', 'true')
    this.button.appendChild(icon)
    this.container.appendChild(this.button)
  }
}

const WAITING_CLASS = 'maplibregl-ctrl-geolocate-waiting'
const ACTIVE_CLASS = 'maplibregl-ctrl-geolocate-active'

/**
 * « Me localiser » of the embedded planner: the app's one-shot coarse position, asked over the
 * bridge. A page loaded from a file has no geolocation permission of its own, and the app
 * deliberately asks for no finer one (docs/LEDGER_*.md MOB-131). One shot, as on the site: the
 * position is only there to find where to start.
 */
export function BridgeLocateControl({
  onLocated,
}: {
  onLocated: (place: { lng: number; lat: number }) => void
}) {
  const { t } = useTranslation()
  const { current: map } = useMap()
  const zones = useMapZones()
  const control = useControl(() => new LocateButtonControl(), { position: zones.camera })
  const onLocatedRef = useRef(onLocated)
  useEffect(() => {
    onLocatedRef.current = onLocated
  })

  useEffect(() => {
    const { button } = control
    button.setAttribute('aria-label', t('map.locate.find'))
    let dot: Marker | null = null
    const ask = () => {
      button.classList.add(WAITING_CLASS)
      post({ type: 'locate' })
    }
    button.addEventListener('click', ask)
    const unsubscribe = onPosition((position) => {
      button.classList.remove(WAITING_CLASS)
      if (!position || !map) {
        button.setAttribute('aria-label', t('map.locate.unavailable'))
        return
      }
      button.classList.add(ACTIVE_CLASS)
      const element = document.createElement('div')
      element.className = 'maplibregl-user-location-dot'
      dot?.remove()
      dot = new Marker({ element }).setLngLat([position.lng, position.lat]).addTo(map.getMap())
      map.flyTo({ center: [position.lng, position.lat], zoom: Math.max(map.getZoom(), PLACE_ZOOM) })
      onLocatedRef.current(position)
    })
    return () => {
      button.removeEventListener('click', ask)
      unsubscribe()
      dot?.remove()
    }
  }, [control, map, t])

  return null
}
