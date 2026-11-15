# Route planner in the mobile app

Ledger `MOB-170` (app) and `WEB-183` (the site's side: shared fullscreen component and embed
build). Written 15 November 2026. Status: **lot 2 (site) coded the same day, lot 3 (app) not coded**. **No contract change**
and no backend change: the generated Dart client already exposes everything the planner calls.

Goal: creating and editing a route in the app does what the site does — drawing on the map
included — **except route generation** (`MOB-154` stays as it is). Reference for the site's
planner: [`2026-10-17-editeur-parcours-web.md`](2026-10-17-editeur-parcours-web.md) (`WEB-100`).

This plan reopens one line of `MOB-24`, which kept the map planner out of the app (« il ne vit
qu'au site »). The reason it gave — the app has no screen, map and pointer fit for placing points —
no longer holds: lot 2 of `WEB-100` built a touch mode for the site (fullscreen, bottom bar, long
press, 44 px targets), and the spike of §2 shows that this mode runs inside the app.

---

## 0. Decisions in one screen

| Question | Decision |
|---|---|
| Native planner or the site's planner in a WebView | **The site's planner in a fullscreen WebView**, the form around it stays native. Same pattern as the rich text editor (`MOB-160`). §1. |
| What is shared with the site | The whole planner: `lib/planner*.ts`, `useRoutePlanner`, `RoutePlanner.tsx`, and the touch fullscreen extracted from `RoutePlannerField.tsx`. Nothing is ported to Dart. |
| How the page reaches the API | It does not. Every request goes through the bridge and is sent by Flutter's Dio (auth, 401 refresh, cancellation), on a closed list of paths. The page holds no token and no base URL. §4. |
| What the page returns | The request fragment computed by the site's `plannerSubmit.ts` (`plannerState`, or `points`, or "file untouched", plus `waypoints` when touched). The send rule is not rewritten in Dart. |
| MapLibre worker | Loaded from a **Blob** built from its source; a worker URL cannot be loaded from `file://`. §2. |
| Basemap styles | Flutter reads the style JSON and hands the **object** to the page: `/api/map/styles/*` sends no CORS header and the page's origin is `null`. §2. |
| Place search | Through `/api/geocode/*` over the bridge, not Stadia from the page: no key in the bundle. |
| « Me localiser » | The existing one-shot coarse position, no puck, no new permission (`MOB-131` stands). |
| Personal GPX tools | Out: the app has no GPX previews (`MOB-154`). |
| Multi-track route | GPX only, as on the site. |
| Leaving with unsaved changes | The app keeps its `PopScope` confirmation, which the site does not have. |

---

## 1. Why a WebView and not a Dart port

| | WebView | Dart port |
|---|---|---|
| Parity with the site | By construction: same code | Kept by hand at every change of the site |
| `PlannerState` format | One implementation | Two serialisers to keep compatible, in both directions |
| Logic to write | An entry point and a bridge | About 2 300 lines of logic, 900 of controller, and their tests |
| Map gestures | Built and tested for touch at 360 px | To build: `maplibre 0.3.7` has no draggable marker, and long press is not wired in `PdlMap` |
| Tests | The site's Vitest and Playwright suites cover the logic | Everything to rewrite |
| Look | The site's map and panels, themed by CSS variables | Native (`PdlMap`) |
| Risk | WebGL in a WebView on a modest Android phone; a committed bundle that can go stale | Silent divergence |

What decided it: the state format is still moving (`PlannerSource.generated`, contract `14.16.0`,
landed the day this plan was written), and a second implementation would have to follow each such
change with nothing failing when it does not.

What it costs: the planner's look is the site's, not the app's; the bundle is committed and must be
rebuilt after a change to the planner (§6 adds the check that `MOB-160` lacks); map gestures get no
automatic test on a device.

---

## 2. Spike (15 November 2026)

MapLibre GL JS 6.18 alone (no React, no planner), built as one IIFE, loaded with
`loadFlutterAsset` in a debug page of the app. Gestures were injected with `adb` on the Pixel and
`axe` on the simulator; on the iPhone they were made by hand.

| Question | Pixel 6a, Android 17, WebView Chrome 156 (debug) | iOS simulator, iPhone 17 Pro Max, 26.5 (debug) | iPhone, iOS 27.2 (release) |
|---|---|---|---|
| Worker starts (Blob) | Yes | Yes | Checked by hand: everything worked, no figures recorded |
| Tiles from origin `null` | « Route » style 1.9 s, IGN vector 2.0 s | 4.4 s first load, 2.8 s after; IGN 3.2 s | |
| Styles from `/api/map/styles/*` | **Blocked by CORS** | **Blocked by CORS** | |
| Rendering | WebGL 2 | WebGL 2 | |
| Tap adds a point, long press (500 ms) | Yes | Yes | |
| Dragging a marker, line redrawn live | 60 fps, worst frame 17 ms | Not measured (the injected swipe was not taken as a drag) | |
| 100 000-point line | Drawn in 0.36 s | 2.7 s | |
| Pan and zoom with that line | 57 fps, worst frame 34 ms | Not representative (no device GPU) | |

Not tested: two-finger pinch by injection, a low-end Android phone, the bundle with React, Mantine
and the planner on top (the spike weighs 1.07 MB of script, 0.52 MB of worker, 71 KB of CSS).

Two constraints came out of it:

- **Worker.** `?worker&url` emits the worker as a separate file whose URL (`/assets/…`) means
  nothing under `file://`. The build copies its source into a script the page turns into a Blob
  URL for `setWorkerUrl`.
- **CORS.** A style served by our API is refused; the styles on jsDelivr and the IGN's are not.
  Flutter fetches the style and passes it as an object. The tiles of the raster styles come from
  their providers directly (`tile.openstreetmap.org` for OSM); the satellite ones were not checked
  and are the first thing to verify in lot 2.

The spike's code is not kept: `frontend/src/embed/mobile-planner-spike/`,
`frontend/vite.mobile-planner-spike.config.ts`, `mobile/assets/planner-spike/`,
`mobile/lib/dev/planner_spike_page.dart` and the `PLANNER_SPIKE` flag. Its Vite plugin that inlines
the worker is the one thing to carry over.

---

## 3. What the app has and what it lacks

Already at parity since `MOB-79`: name, slug, surface, visibility, tags, description, media, GPX
upload and replacement, permissions from the backend.

Missing, and delivered by this plan:

- drawing and editing the track on the map, with everything the site's touch mode has: add, insert,
  move and delete points, anchors, routing profiles and their tuning, straight-line mode, undo and
  redo, clear, GPX import into the planner (replace or append), elevation strip, surface colouring,
  distance and climb, place search, basemaps, help panel;
- editing route waypoints (the twelve types, name, description, drag along the line);
- the `excludedFromGenerator` checkbox (never sent today, so the server keeps its value);
- the planner quota (`BILL-10`): button disabled with its reason when spent, dialog on
  `PLANNER_QUOTA_REACHED`, team refetched after every save.

Not on the site either, so not here: reverse, out-and-back, return to start, route drafts.

---

## 4. Architecture

### 4.1 Site (`WEB-183`)

- Extract the touch fullscreen from `components/planner/RoutePlannerField.tsx` into a component
  with two hosts: the site's fullscreen dialog and the embed. The site's behaviour does not change;
  `RoutePlannerField.test.tsx` and the planner e2e specs guard the move.
- Make the transport injectable: the planner's three router calls (`/api/router`, `/elevation`,
  `/import-gpx`) and the place search go through an interface, the Orval client on the site and the
  bridge in the embed.
- New entry `src/embed/mobile-planner/`, built by `vite.mobile-planner.config.ts` into
  `mobile/assets/planner/` as a classic IIFE with no hash (`pnpm build:mobile-planner`), the worker
  inlined as in §2. Mantine provider, French and English catalogues, theme through CSS variables
  pushed by Flutter.

### 4.2 Bridge (`PedalonsBridge`, JSON messages)

Flutter to page: `load({state | track, waypoints, routeName, team, quota, style, theme, locale})`,
`response{id, status, body}`, `gpx{name, bytes}`, `position{lng, lat}`.

Page to Flutter:

| Message | Flutter does |
|---|---|
| `ready` | Sends `load` |
| `request{id, method, path, body}` / `cancel{id}` | Sends it with Dio, on the closed list `/api/router`, `/api/router/elevation`, `/api/router/import-gpx`, `/api/geocode/*`; anything else is refused |
| `pickGpx` | Opens the existing picker (`gpxFilePickerProvider`), keeps the file, returns its bytes |
| `locate` | Returns the coarse one-shot position |
| `busy{bool}` | Blocks the form's save while a leg or an import is in flight |
| `quotaRefused{scope}` | Opens the quota dialog, refetches the team |
| `done{payload, stats, nameSuggestion, notice}` | Closes the screen, hands the result to the form |

**As built, the protocol's reference is `frontend/src/embed/mobile-planner/README.md`.** It adds
to the table above: `load.create` (to pass explicitly when reopening a drawing not saved yet),
`load.terrain` and `load.defaultCenter`, `dirty{dirty}` for the app's `PopScope`, `error{message}`,
`close{dirty}`, and `done.stats.line` (a polyline6 for the native preview). `done.payload.file` is
`true`, never the bytes. `theme` is `light` or `dark`, not CSS variables.

A multipart body crosses the bridge as base64. Flutter keeps the picked file so that an import left
untouched is uploaded as a file, as on the site.

### 4.3 App (`MOB-170`)

- Create: `GpxPickStep` offers « Importer un fichier GPX » and « Tracer sur la carte ». The second
  shows only when `team.enableRoutePlanner`, disabled with the quota message when spent.
- Edit: `route_track_section.dart` gains « Modifier le tracé » beside « Remplacer le GPX », for a
  single-track route only. `planner-state` is read before opening, uncached; if the read fails the
  track opens as an import with the site's warning.
- `RoutePlannerScreen`: a fullscreen `MaterialPageRoute`, the WebView as the whole body with
  `EagerGestureRecognizer`. Never inside the scrolling form (decision of `MOB-160`).
- Back in the form: a native preview card (thumbnail, distance, climb, point count). The name is
  filled only when empty.
- `route_form.dart` merges `payload` into the request: `points` and `plannerState` never together,
  the file only for an untouched import, nothing for an untouched track on edit. `tagIds` stays
  always sent and the multipart shape of `MOB-79` does not change.
- `pedalons_api_client.dart` exposes the router client.

---

## 5. Lots

1. **Spike** — done, §2.
2. **Site** (`WEB-183`, M): extraction, injectable transport, entry point and build. Ends with the
   real planner bundle loaded in the app's debug page: weight, satellite tiles, first paint on the
   Pixel. **Done 15 November 2026**: 2.6 MB of script (760 KB gzipped), 0.5 MB of
   worker, 0.4 MB of CSS; on the Pixel 6a the page is ready in 0.7 s and the eight basemaps
   render, the API-served ones (satellite, OSM, SCAN 25, Michelin) through style documents read
   by Flutter. The debug page `mobile/lib/dev/planner_embed_page.dart` (`/dev/planificateur`) is
   kept: it is the bridge's minimal reference until lot 3.
3. **App** (`MOB-170`, M): screen, bridge, source choice, preview, send, quota, exclusion checkbox.
   Three points lot 2 left to lot 3:
   - **Reopening.** `done` returns no state, and a payload is relative to the state the page
     opened on: destroying the WebView between two openings would let an untouched reopening wipe
     the first result. Keep the WebView alive for the life of the form.
   - **Large GPX.** A 10 MB file crosses the bridge twice as base64; untested on a device. If it
     hurts, the multipart refers to the file Flutter kept instead of carrying it.
   - **Android back** never reaches the page: Flutter decides from the last `dirty` message.
4. **Tests and device check** (§6), then `contracts/routes.yaml`'s comment on `routeNew` /
   `routeEdit` (« the route planner stays web-only ») and the `MOB-24` row are brought up to date.

---

## 6. Tests

- Site: the existing planner suites must stay green through the extraction; Vitest on the embed's
  transport and on the `done` payload.
- App: unit tests of the bridge (closed path list, cancellation, base64 multipart) and of the
  request merge; `route_repository_write_test` extended to a `plannerState` request;
  `route_editor_page_test` for the two entry points, the quota states and the checkbox.
- Patrol: a test command on the bridge places points without touching the map, then the saved
  route is checked through the API. **To settle first**: whether the e2e stack has a stub router;
  without one this test bills Stadia requests.
- `mobile/check.sh` fails when `mobile/assets/planner/` is older than the sources it is built from.
- By hand on Android and iOS: drag, insert on the line, long-press menu, pinch, edge auto-pan,
  waypoint form, keyboard in the search box.

---

## 7. Not to undo

- The page never holds a token or a URL; Flutter is the only HTTP client.
- The send rule lives in `plannerSubmit.ts` only.
- The WebView is a screen of its own, never a child of the form.
- No Dart copy of the planner's logic or of the `PlannerState` serialiser.
