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
 * Position: top-right, the one exception to `PedalonsMap`'s "everything top-left, one column"
 * rule. The control is a 280px text field with a results list dropping from it; in the left
 * column it would sit under the basemap switcher and its results would cover the page's own
 * buttons (undo/redo, routing profile…). A search field is not a button: visitors look for it
 * where every map application puts it, in a corner of its own.
 */
export function MapSearchControl() {
  const { i18n } = useTranslation()
  // The control reads its options once, when constructed: a language change rebuilds it.
  return <SearchControl key={i18n.resolvedLanguage ?? i18n.language} />
}

function SearchControl() {
  const { t, i18n } = useTranslation()
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
      }),
    { position: 'top-right' }
  )
  return null
}
