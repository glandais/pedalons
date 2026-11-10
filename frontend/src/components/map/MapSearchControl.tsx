import { useEffect, useRef } from 'react'
import { useTranslation } from 'react-i18next'
import { useControl } from 'react-map-gl/maplibre'
import { MapLibreSearchControl } from '@stadiamaps/maplibre-search-box'
import '@stadiamaps/maplibre-search-box/dist/maplibre-search-box.css'

/**
 * Stadia Maps' European host. The control talks to it straight from the browser, authenticated by
 * the page's origin (pedalons.fr and its subdomains are registered on the Stadia side; localhost
 * passes on a strict quota) — there is deliberately no API key anywhere in the client bundle.
 * `frontend/server/csp.js` lists this same origin in `connect-src`. docs/LEDGER_*.md WEB-99.
 */
export const STADIA_MAPS_ORIGIN = 'https://api-eu.stadiamaps.com'

/**
 * "Fly me somewhere": a place search on the maps the visitor navigates freely — the ones that
 * open on `useDefaultMapView()` (route planner, the routes tile map, the blank GPX map). A map
 * framed on a trace or an ad does not get one: it already shows what the page is about.
 *
 * Wraps `@stadiamaps/maplibre-search-box`, which does the whole job itself: debounced
 * autocomplete, keyboard navigation, `flyTo`/`fitBounds` on selection, and the
 * « Powered by Stadia Maps, © OpenStreetMap contributors & others » credit under the results.
 * The focus point is the map's own centre (above zoom 5), so a search from a Savoy team's map
 * ranks Savoy first — no deployment-specific configuration is needed.
 *
 * Address lookups in *forms* (`GeocoderAutocomplete`) are a different thing: they go through our
 * backend proxy so the visitor's IP never reaches the provider. The privacy policy describes both.
 *
 * Position: top-left, at the head of the camera family (it moves the view). On a fine pointer it
 * tops the camera column, its results list floating over the buttons under it (index.css); on a
 * finger it spans the top of the map while the buttons gather bottom-right (`mapZones.ts`).
 * docs/LEDGER_*.md WEB-157.
 */
export function MapSearchControl({ onResultSelected }: MapSearchControlProps) {
  const { i18n } = useTranslation()
  // The control reads its options once, when constructed: a language change rebuilds it.
  return (
    <SearchControl
      key={i18n.resolvedLanguage ?? i18n.language}
      onResultSelected={onResultSelected}
    />
  )
}

/** A place the visitor picked in the results. */
export interface SearchedPlace {
  lng: number
  lat: number
  label: string
}

interface MapSearchControlProps {
  /** Called once a result is chosen (after the map has flown there). */
  onResultSelected?: (place: SearchedPlace) => void
}

function SearchControl({ onResultSelected }: MapSearchControlProps) {
  const { t, i18n } = useTranslation()
  // The control reads its options once, when constructed: the callback goes through a ref.
  const callback = useRef(onResultSelected)
  useEffect(() => {
    callback.current = onResultSelected
  })
  useControl(
    () =>
      new MapLibreSearchControl({
        baseUrl: STADIA_MAPS_ORIGIN,
        // Localises the result labels only; the query itself is language-agnostic.
        lang: i18n.resolvedLanguage ?? i18n.language,
        placeholder: t('map.search.placeholder'),
        noResults: t('map.search.noResults'),
        maxResults: 5,
        minInputLength: 3,
        hideResultsOnBlur: true,
        onResultSelected: (feature) => {
          const coordinates = feature.geometry?.coordinates
          if (!callback.current || !coordinates || coordinates.length < 2) return
          callback.current({
            lng: coordinates[0],
            lat: coordinates[1],
            label: feature.properties.name,
          })
        },
      }),
    // Whatever the pointer: on a finger the top-left corner is the search's alone.
    { position: 'top-left' }
  )
  return null
}
