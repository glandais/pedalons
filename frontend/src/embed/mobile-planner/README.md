# Route planner embedded in the mobile app

The site's route planner — its touch fullscreen editor — as a page the Flutter app shows in a
fullscreen WebView. Ledger `WEB-183` (this side) and `MOB-170` (the app); plan
[`docs/plans/2026-11-15-planificateur-parcours-mobile.md`](../../../../docs/plans/2026-11-15-planificateur-parcours-mobile.md).

```bash
pnpm build:mobile-planner     # → mobile/assets/planner/{index.html, planner.js, planner.css, worker-src.js}
pnpm dev:mobile-planner       # the built page in a desktop browser, with a fake bridge (see below)
```

The output is committed. **Rebuild it after any change to the planner** (`components/planner/`,
`hooks/useRoutePlanner.ts`, `lib/planner*.ts`, the map components, the catalogues).

## What is shared with the site

Everything but the host. `PlannerApp.tsx` renders the same pieces as the site's form field
(`components/planner/RoutePlannerField.tsx`):

| Piece | Role |
|---|---|
| `useRoutePlanner` | The planner's state |
| `usePlannerEditing` | What happens around the map: route point form, profile hover, clear and remove with their « undo », GPX import |
| `PlannerTouchFullscreen` | The touch fullscreen: toolbar, elevation strip, bottom bar |
| `PlannerEditingDialogs` | Replace-or-append choice of an import, route point form |
| `RoutePlanner` | The map |
| `lib/plannerSubmit.ts` | The rule of what is saved (`done.payload`) |

Three things differ, each injected rather than forked:

- **Network** — `lib/plannerTransport.ts`. The site sends the planner's three calls with the
  generated client; this page calls `setPlannerTransport(bridgeTransport)` and they become bridge
  messages. Any other call of the site's client is refused before it leaves (`main.tsx`).
- **Search and « Me localiser »** — `components/planner/plannerMapControls.ts`. The site's search
  box calls Stadia Maps from the browser and its locate button reads the browser's geolocation; a
  page loaded from a file can do neither. `BridgeMapControls.tsx` provides a search on
  `/api/geocode/*` and a locate button that asks the app.
- **Basemaps** — the site reads the list from `GET /api/config` and lets MapLibre fetch each style;
  here `load` carries the list, with the style **documents** for the ones our API serves
  (`styles.ts`).

## Constraints of the page

Loaded with `loadFlutterAsset`: `file://`, origin `null`, no cookie, no token, no base URL.

- **One classic script.** A module loaded from `file://` is refused by Android's WebView. The build
  is a single IIFE, so every lazy `import()` is inlined: one import of the router or of the route
  table would bring the whole site in. `vite.mobile-planner.config.ts` aliases the two known paths
  to stubs (`stubs/`) and **fails the build** if a page, the router or Firebase gets in.
- **MapLibre's worker is a Blob.** A worker URL cannot be loaded from `file://`: the build copies
  the worker's source into `worker-src.js`, which `main.tsx` turns into a Blob URL.
- **No request to our API.** `/api/*` sends no CORS header for origin `null`. Tiles and styles on
  third-party hosts are fetched by the page directly.
- **`localStorage` may be missing** (DOM storage off): `storageShim.ts` falls back to memory.

## Bridge protocol

JSON both ways. The page posts strings on the `PedalonsBridge` JavaScript channel
(`window.PedalonsBridge.postMessage(json)`); Flutter calls `window.pedalonsPlanner.<method>(<json>)`
with `runJavaScript`. Types: `bridge.ts`.

### Flutter → page

| Call | When |
|---|---|
| `load(input)` | After `ready`. A second call starts over on a fresh state. |
| `response({ id, status, body, retryAfter? })` | Answers a `request`. |
| `gpx({ name, base64 } \| null)` | Answers `pickGpx`; `null` when the picker was left. |
| `position({ lng, lat } \| null)` | Answers `locate`; `null` when there is no position. |

`load` input:

| Field | |
|---|---|
| `state?` | `PlannerState` of the route (`GET …/planner-state`). Wins over `track`. |
| `track?` | `[lng, lat, ele, dist][]` of the route; frames the map, and is what opens when there is no `state`. |
| `ascend?` | D+ (m) stored for `track`. |
| `waypoints?`, `waypointsTotal?` | `WaypointDto[]` of the route and the length (m) stored with them. |
| `routeName?` | Toolbar title. |
| `teamSlug` | Sent with every routing call. |
| `teamLocation?` | `[lng, lat]`: where the map opens without a track. |
| `create?` | `true`: the route does not exist yet, the whole drawing is sent. `false`: an untouched track sends nothing. Default: `true` when neither `state` nor `track` is given. **Pass it explicitly when reopening a drawing not saved yet.** |
| `styles` | The basemaps of `ConfigDto.mapStyles`. For an entry whose `url` is on our API, replace `url` by `style` (the document, object or JSON text); same for `darkVariant` → `darkStyle`. Third-party URLs stay as they are. |
| `terrain?` | `ConfigDto.terrain`; absent, the relief switches are hidden. |
| `defaultCenter?` | `ConfigDto.defaultCenter`: where the map opens with neither track nor team location. |
| `theme` | `'light'` or `'dark'`. |
| `locale` | `'fr'` or `'en'` (anything else: French). |
| `units` | `'METRIC'` or `'IMPERIAL'`. |
| `quota?` | Accepted, not read: the app disables its own entry point when the quota is spent. |

`response`: `status` is the HTTP status, `0` when no answer came (network down, path refused by
the app). `body` is the decoded JSON or its text. `retryAfter` is the `Retry-After` header in
seconds, when present. An error status is turned into the errors the site's client throws
(`ApiClientError` with the API's `code`, else an axios error with the status), so the planner's
messages by code (`lib/plannerErrors.ts`, `lib/plannerQuota.ts`) are the site's.

### Page → Flutter

| Message | Flutter does |
|---|---|
| `{ type: 'ready' }` | Calls `load`. |
| `{ type: 'request', id, method, path, body? }` | Sends it with its own HTTP client and answers with `response`. |
| `{ type: 'cancel', id }` | Cancels that request; no `response` is expected (a late one is dropped). |
| `{ type: 'pickGpx' }` | Opens the file picker, keeps the file, answers with `gpx`. |
| `{ type: 'locate' }` | Answers with `position`. |
| `{ type: 'busy', busy }` | A calculation is in flight: nothing to save yet. |
| `{ type: 'dirty', dirty }` | Whether anything changed since `load` — what a « leave without saving? » asks about. |
| `{ type: 'quotaRefused', scope, limit, current, resetsOn, teamName? }` | A calculation was refused with `PLANNER_QUOTA_REACHED`: open the quota dialog, read the team again. The page shows the refusal in its status line too. |
| `{ type: 'done', payload, stats, dirty, nameSuggestion?, notice? }` | « Terminer »: close the screen, hand the result to the form. Not sent while `busy`. |
| `{ type: 'close', dirty }` | The back arrow: leave without a result. The page asks nothing; confirming is the app's. |
| `{ type: 'error', message }` | An uncaught failure of the page, for the app's log. |

`request` is only ever one of:

| `method` `path` | `body` |
|---|---|
| `POST /api/router` | `RouterRequest` |
| `POST /api/router/elevation` | `LineElevationRequest` |
| `POST /api/router/import-gpx` | `{ multipart: { fields: { teamSlug? }, file: { name, base64, contentType } } }` — the file part is named `gpxFile` |
| `GET /api/geocode/search?q=…` | — |
| `GET /api/geocode/place?id=…` | — |

The query string is part of `path`, already encoded. The app should refuse anything else.

`done`:

- `payload` — the fragment to merge into the route request, computed by `plannerPayload`
  (`lib/plannerSubmit.ts`): `plannerState`, **or** `points`, **or** `file: true`, **or** none of
  them, plus `waypoints` when the route points were touched. `file: true` means the route is,
  untouched, the file the app picked last: upload that file, as the site does. An empty payload on
  an existing route means « send no track ».
- `stats` — `{ distance, ascend, pointCount, line }`: metres, metres of climb, control points, and
  the drawn line as a polyline of precision 6 (latitude then longitude) for the preview card.
- `nameSuggestion` — the name of the last file imported, for a name field still empty.
- `notice: 'tooLarge'` — the state was past its bounds, `points` are sent and the saved track
  loses its control points: show the site's warning (`planner.state.tooLarge`) once saved.

## Trying it without the app

```bash
pnpm build:mobile-planner
pnpm dev:mobile-planner
# or against a backend, as a signed-in member of a team:
API=http://localhost:8080 TOKEN=<access token> TEAM=<team slug> pnpm dev:mobile-planner
```

Then `http://localhost:5199/` (`?theme=dark&locale=en&units=IMPERIAL&routeName=…` are optional),
**with the devtools' device toolbar on**: the page is the touch editor and reads
`(pointer: coarse)`; with a mouse it also draws the site's desktop toolbar over the map.

`dev/mobile-planner/serve.mjs` serves the built files and plays the app: `fake-bridge.js` logs
every message in the console, answers `request` through the server (the API given, or canned
answers: a straight line for a leg, two places for a search, a refusal for an import), opens a
file input for `pickGpx`, reads the browser's position for `locate`, and shows `done`, `close`,
`quotaRefused` and `error` on the page. Nothing of it is in the bundle.

## Tests

`bridge.test.ts` (requests, cancellation, error mapping, multipart) and `done.test.ts` (the
payload) run with the site's Vitest suite. The planner itself is covered by the site's own suites.
