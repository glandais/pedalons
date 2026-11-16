# Team route generator, lot 4: the website

Lot 4 of the team route generator, ledger `WEB-179`. Parent plan:
[`2026-11-13-generateur-boucles-equipe.md`](2026-11-13-generateur-boucles-equipe.md) (§7 site, §10
decisions 3, 8, 9). Input: lot 3 ([`…-lot3.md`](2026-11-13-generateur-boucles-equipe-lot3.md)),
contract `14.14.0`: `POST /api/teams/{teamSlug}/route-generator` (`generateRoutes`, generated as
`src/api/endpoints/route-generator/route-generator.ts`), `RouteRequest.excludedFromGenerator` /
`RouteDetailDto.excludedFromGenerator`, and the seven `errors.api.*` keys that lot 3 added.

Written 14 November 2026. Status: **design, not coded**. **No contract change**: the lot uses
`14.14.0` as it is. It changes no backend code, unless the owner takes the optional reserved slug
of §2.3. Paths are relative to `frontend/src/` unless stated otherwise.

---

## 0. Decisions in one screen

| Question | Decision |
|---|---|
| Where the generator lives | A **page** `routeGenerate` (`/equipes/{slug}/parcours/generer`, `/teams/{slug}/routes/generate`) reached from the routes list and map. From the route editor it is the **same panel** in a fullscreen `Modal`, so that a ride or trip form using `CreateRouteModal` loses nothing. One component, `RouteGeneratorPanel`, has two hosts. |
| Who sees it | `team.enableRoutes && team.enableRoutePlanner && teamAccess(team, isPlatformAdmin).isOrganizer`: the same rule as `RoutesListHeader`'s « Créer un parcours » plus the planner flag. The backend check (`PlannerAccess.check`) is the same. When the team's planner quota is spent, the button stays visible but disabled, with the reason, like « Tracer sur la carte » (`BILL-10`, §1). |
| Page state | The **query string** (`useUrlFilters`, §2.2): start, end, bearing, distance, familiarity, type, seed, selected candidate, and `go`. The previous results come back from the React Query cache when the person returns from the editor. Nothing is generated until « Générer » is pressed, and any change of a parameter clears `go`. |
| Generation call | `useQuery`, not the generated mutation: key = team + request, `staleTime: Infinity`, `gcTime` 30 min, `retry: false`, `meta: { clientOnly: true }`, `skipErrorToast`. Going back and forth, or back to an earlier seed, sends no new request (the rate limit is 30 per 15 min). |
| Dominant type | Three `useCountRoutes(teamSlug, { surfaceType })` calls (ROAD, GRAVEL, MTB), already in the contract, prefetched on the server. The largest count wins, ROAD on a tie or with no routes. `MIXED` is not counted. `?t=` in the URL wins over it. |
| "Far" end | `haversine(S, E) ≥ D / 2` in the client. That is the backend rule (`QueryContext.bearingApplies = chord < D/2`, measured between the snapped nodes). When the end is far, the compass is disabled and `bearing` is **not sent**. |
| Team network in the background | **Skipped.** The generator response carries a summary of the network (`RouteGeneratorNetworkDto`), not its geometry. The routes vector tiles (`RoutesTileMap`) are not a substitute: they include excluded and still-pending routes, so the map would show roads the generator does not use. See §4.4. |
| « Ouvrir dans l'éditeur » | The candidate becomes a GPX built in the browser, sent to the existing `POST /api/router/import-gpx` (FAST elevations, no routing provider, same rights). It is loaded in the planner as a **replacing import that keeps no file** (`importGpx(file, 'replace', { keepFile: false })`). Its points are `imported`, so nothing is re-routed by Stadia. The save sends a `plannerState` whose source carries `generated: true` (contract `14.16.0`), so `PlannerState.drawn()` is true and it **counts in the planner quota** as a drawn track (decision §10.3). A state of imported pieces alone is not counted (WEB-100, C4a): `keepFile: false` was not enough, the full e2e run of 2026-11-15 caught it. Saving the file itself would bypass the quota. |
| Exclusion box | `Checkbox` « Ne pas utiliser pour générer des parcours » in `RouteEditor`, on creation and on edit, shown when `team.enableRoutePlanner`. Its initial value is `route.excludedFromGenerator ?? false`. |
| Errors | One typed table in the panel (`GENERATOR_ERROR_KEYS`, the `AUTH_ERROR_KEYS` pattern) with messages that name the distance or the remaining count. The `errors.api.*` keys of lot 3 stay as the fallback. French and English: the site is bilingual (`locales/fr`, `locales/en`). |

---

## 1. Entry points

### 1.1 Team routes page (list and map)

`components/route/RoutesListHeader.tsx` is shared by `RouteListPage` and `RoutesMapPage`, so one
change reaches both. Next to « Importer GPX » and « Créer un parcours »:

```
[Importer GPX] [Générer un parcours] [+ Créer un parcours]
```

- `Button variant="default"`, `leftSection={<IconRoute2 size={16} />}` (Tabler; any route icon not
  already used for another meaning, BRANDING §6), `component={PrefetchLink}` to
  `paths.routeGenerate(team.slug)`. `RoutesListHeader` uses `component="a"` today, so this button
  follows `frontend/CLAUDE.md`, which says never to use a bare link.
- Shown when `canCreateRoute && team.enableRoutePlanner`.
- Disabled when `isPlannerQuotaSpent(team.plannerQuota, isPlatformAdmin)`, wrapped in a `Tooltip`
  that says « Les enregistrements de tracés du mois sont épuisés. » (it opens from a disabled
  button through a `span` wrapper, the Mantine pattern). Generating draws nothing, but the only way
  to keep a result is a planner save, which the quota refuses.
- On a narrow screen the three buttons wrap (`Group wrap="wrap"`). No overflow menu.

### 1.2 Route editor opening panel

`components/route/RouteEditor.tsx`, the « Source du parcours » group (create mode only,
`plannerOpen`). It gets a third button:

```
Source du parcours *
[Importer un fichier GPX] [Tracer sur la carte] [Générer un parcours]
```

- Only when `isCreateMode`. On an existing route, the planner's own GPX import already replaces the
  track, and the generator page plus « Créer » covers a new one.
- Disabled exactly when « Tracer sur la carte » is (`quotaSpent`). The existing
  `PlannerQuotaMessage` under the group already says why.
- A click opens `RouteGeneratorModal` (§3.6). Choosing a candidate there closes it, sets
  `sourceMode = 'planner'` and loads the candidate into the planner (§5).
- Because `RouteEditor` also sits in `CreateRouteModal` (ride and trip forms), the modal reports
  itself through the existing `onPlannerFullscreenChange(true/false)`. The host dialog's Escape then
  waits, as it does for the planner's fullscreen editor.

---

## 2. Page, route and URL

### 2.1 Routes contract

`contracts/routes.yaml`, after `routesMap`:

```yaml
  - id: routeGenerate
    path:
      en: /teams/{teamSlug}/routes/generate
      fr: /equipes/{teamSlug}/parcours/generer
    params:
      - teamSlug
    web: true
```

Web only, no deeplink (the app has no generator, `MOB-154`). Then run `pnpm generate-routes` and
never hand-edit `paths.generated.ts`.

`config/routes.config.ts`, next to `route-new`:

```ts
{
  id: 'route-generate',
  paths: pathVariants.routeGenerate(':teamSlug'),
  component: pages.RouteGeneratorPage,
  auth: 'authenticated',
  noindex: true,
  parentId: 'routes',
  breadcrumb: { type: 'static', i18nKey: tRegister('routeGenerator.title') },
  prefetch: teamScopedPrefetch((qc, p) => prefetchRouteGenerator(qc, p.teamSlug!)),
  showBackLink: true,
},
```

`config/pageComponents.ts`: `RouteGeneratorPage: lazyPage('RouteGeneratorPage', () =>
import('../pages/route/RouteGeneratorPage'))`. The page imports the map, so it stays in its own lazy
chunk, like `RoutesMapPage`.

### 2.2 Query string (`hooks/filters/routeGeneratorFilters.ts`)

| Key | URL | Schema | Default |
|---|---|---|---|
| `start` | `s` | `"lat,lon"` → `GeoPoint`, 5 decimals, invalid → undefined | undefined = the team's location (not written) |
| `end` | `e` | same | undefined = « Au départ » (a loop) |
| `bearing` | `cap` | `z.enum(CompassPoint)` | undefined = « Peu importe » |
| `distanceKm` | `d` | `z.coerce.number()`, clamped to 10–300 by `.catch(50)` | 50 |
| `familiarity` | `f` | number 0–1 in steps of 0.25, `.catch(0.5)` | 0.5 |
| `type` | `t` | `z.enum(RouteGeneratorType)` | undefined = the dominant type (§3.4) |
| `seed` | `seed` | int ≥ 0 | 0 |
| `selected` | `sel` | int 0–2 | 0 |
| `go` | `go` | `z.stringbool()` | false |

The page writes every change with `setFilters({ …patch, go: undefined, seed: undefined, selected:
undefined })`. A changed parameter therefore drops the results instead of silently showing results
for other parameters, the same way a list page resets `page` when a filter changes. « Générer »
writes `go: true`. « Autres propositions » writes `seed: seed + 1, selected: undefined` and keeps
`go`. A card click writes `selected`.

`routeGeneratorRequest(filters, type)` sits next to the schema (the `routeApiParams` rule): it builds
the `RouteGeneratorRequest`. It leaves out `start` and `end` when they are absent, and leaves out
`bearing` when `isEndFar` (§3.3).

**Privacy.** A start the person clicked is often a home. In the URL it reaches the browser history
and the server access logs. The analytics never read the query string (`lib/analytics/countHit.ts`).
The team's location, the common case, is never written. The owner should confirm this choice
(§9, D4). The alternative is `sessionStorage`, which would no longer survive a shared link.

### 2.3 Slug shadowing

`/equipes/{slug}/parcours/generer` wins over `/parcours/{routeSlug}` in React Router (a static
segment ranks first). A route named « Générer » would get the slug `generer` and its sheet would no
longer open by URL. That defect already exists for `nouveau`, `new`, `carte` and `map`, which
`SlugService.RESERVED_SLUGS` does not reserve: it only holds the API words `bulk`, `count`, `bounds`
and `tiles`. **Optional backend line** (owner's call, §9 D5): add `generate`, `generer` (and the
four existing UI words) to the ROUTE set, with a `SlugServiceTest` case. Otherwise the defect is
left as it stands for the four existing words.

### 2.4 Companion data module (`pages/route/routeGeneratorData.ts`)

Per `docs/SSR-data-loading.md`, the page's hooks and the route's prefetch share one description:

- `useRouteGeneratorData(teamSlug)`: `useGetTeam` (covered by `teamScopedPrefetch`) and the three
  counts `useCountRoutes(teamSlug, { surfaceType: ROAD | GRAVEL | MTB })`.
- `prefetchRouteGenerator(qc, teamSlug)`: `Promise.all` of the three `prefetchCountRoutesQuery`.
- The generation query (§3.5) is **client-only**: a POST under a rate limit, never run on the
  server. Its `meta: { [CLIENT_ONLY_QUERY]: true }` keeps `e2e/routes-render.e2e.ts` from counting
  it as a prefetch gap.

### 2.5 Page guards (`pages/route/RouteGeneratorPage.tsx`)

The same order as `CreateRoutePage`: loading → `LoadingPage`; no team → `Navigate` to
`paths.teams()`; `!team.enableRoutes` → the team; `!team.enableRoutePlanner || !isOrganizer` →
`Navigate` to `paths.routes(slug)`. The page renders inside `TeamLayout currentTab="routes"` with
the title « Générer un parcours » and the subtitle « Des propositions faites uniquement de routes
que l'équipe a déjà dans ses parcours. »

---

## 3. The panel

### 3.1 Components (`components/routeGenerator/`)

| File | Role |
|---|---|
| `RouteGeneratorPanel.tsx` | Controls, result cards and map. Props: `team`, `params`, `onParamsChange(patch)`, `onGenerate()`, `onMoreProposals()`, `onSelect(i)`, `onOpen(candidate)`, `layout: 'page' \| 'modal'`. No state of its own besides the transient click mode. |
| `RouteGeneratorMap.tsx` | `PedalonsMap`, start and end markers, click to place, candidate lines (§4). |
| `CompassPicker.tsx` | 3 × 3 grid: eight bearings around « Peu importe ». |
| `GeneratedRouteCard.tsx` | One card per candidate (§4.2). |
| `RouteGeneratorModal.tsx` | Fullscreen `Modal` (`MapFullscreenShell`, like the planner) that holds the panel with **local** state (`useRouteGeneratorState`, the same reducer as the URL version) for the editor (§1.2). |
| `useRouteGenerator.ts` | The query (§3.5) and the derived state: dominant type, `isEndFar`, `canGenerate`, the reason it cannot. |

`lib/routeGenerator.ts` (pure, unit-tested): `isEndFar`, `routeGeneratorRequest`,
`dominantGeneratorType`, `familiarityBand`, `generatorErrorMessage`, `gpxFromLine`,
`generatedRouteName`.

### 3.2 Layout

On a mouse (≥ `md`), the panel is a 360 px column to the left of the map and the map takes the rest
(`70dvh` on the page, the full height in the modal). On a finger the controls come first, then the
map (`50dvh`), then the cards. Mantine only: `Stack`, `Group`, `SegmentedControl`, `Slider`,
`Button`, `Card`, `Alert`, `Skeleton`, `Tooltip`.

Controls, in this order:

1. **Départ.** A `Text` line « Lieu de l'équipe » (or « Point choisi sur la carte » once `s` is
   set). Then `Button variant="subtle"` « Choisir sur la carte », which enters click mode `start`;
   the hint on the map reads « Cliquez sur la carte pour placer le départ ». When `s` is set, a
   second button « Revenir au lieu de l'équipe » appears, but only if the team has a location.
   When the team has no location and `s` is unset: `Alert color="blue"` « L'équipe n'a pas de lieu
   enregistré : choisissez un départ sur la carte. » and « Générer » is disabled.
2. **Arrivée.** `SegmentedControl` « Au départ » | « Ailleurs ». « Ailleurs » enters click mode
   `end` and writes nothing until the click. « Au départ » removes `e`. Once placed, the line reads
   « Point choisi sur la carte » with « Déplacer ». While « Ailleurs » has no point yet, « Générer »
   is disabled and the reason reads « Choisissez l'arrivée sur la carte. »
3. **Direction.** `CompassPicker` (§3.3).
4. **Distance.** `Slider` in the user's unit (`useUnits`: km, or mi converted to km). Range 10–300
   km, step 5 (in mi: 5–185, step 5, then converted and clamped). The value is shown next to the
   label (« 50 km »). The local value follows the drag, and the URL is written on `onChangeEnd`
   only (one history entry, not one per pixel).
5. **Fréquentation.** `Slider` 0–1, step 0.25, marks without labels, the two end labels under it:
   « Routes prises rarement » … « souvent par l'équipe ». The field label is « Routes de l'équipe »,
   `aria-valuetext` is the band of §4.2.
6. **Type.** `SegmentedControl` Route / Gravel / VTT, reusing `routes.surfaceType.*`. The value is
   `params.type ?? dominant`. While the counts load, the control is a `Skeleton`; on a count error
   the default is ROAD.
7. **« Générer ».** A full-width `Button`, `loading` while fetching. Under it in `dimmed` text, when
   disabled: the reason (team without location, end not placed).

### 3.3 Compass and the "far" rule

`isEndFar(start, end, distanceKm)`: `end` absent → false; otherwise `haversine(start, end) ≥
distanceKm × 1000 / 2`. Here `start` is the resolved start (the URL point or `team.geometry`). The
backend applies the bearing when `chord < D/2`, measured between the snapped nodes
(`QueryContext.bearingApplies`). The client compares the clicked points, so close to the threshold
(a snap moves a point by at most 2 km) the two may disagree. The consequence is harmless: either
the client sent a bearing the engine ignores, or it sent none. The response's
`bearingDeviationDeg` (null when the bearing did not apply) is not displayed.

`CompassPicker`: a `SimpleGrid cols={3}` of nine `Button size="compact-sm"` with `aria-pressed`.
Corners and edges are `NW N NE / W · E / SW S SE`, labelled with the existing abbreviations
`rides.weather.compass.*` (N, NE, E, SE, S, SO, O, NO), `aria-label` the full name
(`routeGenerator.bearing.<CP>`, « Nord-est »…). The centre is « Peu importe ». When `isEndFar`,
the grid is disabled, shows « Peu importe » as selected, and has the hint « L'arrivée est loin du
départ : le parcours part dans sa direction. » The URL's `cap` is **kept** (it applies again if the
end comes closer) but not sent.

### 3.4 Dominant type

`dominantGeneratorType({ ROAD, GRAVEL, MTB })`: the largest `total`. On a tie the order ROAD >
GRAVEL > MTB decides, and all zero gives ROAD. The counts are the routes the caller sees, and an
organizer sees all of the team's routes. Choosing a type writes `t`. Choosing the dominant one
writes nothing (it is the default), as `useUrlFilters` does for any default.

### 3.5 Query

```ts
useQuery({
  queryKey: ['routeGenerator', teamSlug, request],
  queryFn: ({ signal }) => generateRoutes(teamSlug, request, { skipErrorToast: true }, signal),
  enabled: go && canGenerate,
  staleTime: Infinity,
  gcTime: 30 * 60_000,
  retry: false,
  placeholderData: keepPreviousData,
  meta: { [CLIENT_ONLY_QUERY]: true },
})
```

`keepPreviousData`: during « Autres propositions » the previous candidates stay on screen, at 50 %
opacity, until the new ones arrive. A changed parameter clears `go`, which disables the query, so
the area then shows the empty state. The `skipErrorToast` option keeps the mutator's generic toast
quiet: the panel says what is wrong itself (§6). A `useQuery` over a POST is deliberate: the answer
is a pure function of the request for a given network (lot 3: same seed, same routes), and caching
it is what makes back-navigation free.

### 3.6 Modal host (from the editor)

`RouteGeneratorModal` holds the parameters in a `useReducer` with the same patch rules as §2.2 (go
and seed cleared on change). It starts from the defaults, or from the last parameters used in this
editor session. The `useQuery` call is the same, so the cache is shared with the page. Its header
is the back arrow and the title « Générer un parcours ». « Ouvrir dans l'éditeur » on a card
becomes « Utiliser ce parcours ». Escape does not close it (`closeOnEscape={false}`, as for the
planner), and the back arrow does.

---

## 4. Results

### 4.1 Map (`RouteGeneratorMap`)

- **Initial view**: the resolved start at zoom 11. On new candidates: `fitBounds` over the union of
  their `bounds`, padding 40 px.
- **Markers**: `StartMarker` (green, BRANDING §3.7) at the start, and `EndMarker` (red) at the end
  when there is one. Both are `draggable` (a drag writes `s` / `e`, like a click).
- **Click mode** (`start` | `end` | null, local state): a `MapToolbarButton`-style hint at the top
  of the map with « Annuler ». The cursor is `crosshair`. A click writes the point (5 decimals) and
  leaves the mode. With no mode, a click on a line selects that candidate.
- **Candidates**: one GeoJSON source per candidate (`decode2(polyline)` → `[lng, lat]`), colour
  `routeColor(i)` (the multi-route palette, BRANDING §3.7, in order: `#566B13`, `#1d32a8`,
  `#732C7B`). Unselected: width 3, opacity 0.75. Selected: white casing 7, line 5, drawn last, and
  direction chevrons (`routeArrowLayout`, `ROUTE_ARROW_IMAGE` registered by `MapImages`), because
  which way a loop runs matters (one-way streets, no U-turn). A hit layer 14 px wide and transparent
  makes the thin lines easy to click (the `RoutesTileMap` pattern).
- **Card hover** highlights its line (width 5) and does not change the selection.
- Map controls: the standard zones (`PedalonsMap`, BRANDING §3.8). The place search
  (`MapSearchControl`) offers « Partir d'ici » on a found place, as the planner does with « Start
  here », and that writes `s`.

### 4.2 Cards (`GeneratedRouteCard`)

One `Card withBorder` per candidate, in the order the API ranked them. On a mouse they form a
column under the controls, and on a finger a horizontal `ScrollArea` under the map. The selected
card has `borderColor` set to its line colour and `aria-current="true"`. A 4 px colour bar sits in
front of the title, as on a ride group card.

```
▌ Proposition 1                                    82 km
  Dénivelé positif 640 m
  Routes prises de temps en temps
  Tronçon commun aller-retour : 1,2 km            (only when sharedM ≥ 100)
  Non revêtu : 12 %                               (when ≥ 1 %, or always for Gravel / VTT)
                                   [Ouvrir dans l'éditeur]
```

- Distance `distance(distanceM)` and D+ `elevation(ascentM)` from `useUnits` (non-breaking space,
  thousands with U+00A0: BRANDING §8.3).
- **Fréquentation**: `familiarityBand(familiarity)`, 0–0.33 « Routes peu prises par l'équipe »,
  0.33–0.67 « Routes prises de temps en temps », 0.67–1 « Routes habituelles de l'équipe ». The mean
  z is a log-normalised count, and a percentage of it would mean nothing to the reader.
- `crossings` and `descentM` are not shown (the parent plan §7 does not list them).
- The button is `variant="light"`, « Ouvrir dans l'éditeur » (« Utiliser ce parcours » in the
  modal). It is disabled while §5 runs for that card (`loading`), and disabled when the quota is
  spent (§1.1 tooltip).

Under the cards:

- « Autres propositions » (`Button variant="default"`, `IconRefresh`): seed + 1.
- `familiarityFallback` → `Alert color="blue" variant="light"`: « L'équipe a peu de parcours de ce
  type par ici : la fréquentation tient compte de tous ses parcours. »
- `network.incomplete` → `Text size="sm" c="dimmed"`, with the plural on `count` =
  `pendingRouteCount`: « L'analyse des routes de l'équipe n'est pas terminée ({{count}} parcours en
  attente) : d'autres propositions pourront apparaître. »

### 4.3 Empty, loading

- Before the first generation: `EmptyState`, title « Aucune proposition pour le moment », text
  « Réglez le départ, la distance et la direction, puis lancez la génération. »
- While fetching with no previous data: three `Skeleton` cards (height of a card) and a `Loader`
  centred over the map. The button reads « Génération… » (BRANDING §8.3: a noun plus an ellipsis
  for a state in progress).
- After 4 s still fetching: `Text c="dimmed"` « Préparation du réseau de l'équipe : la première
  demande peut prendre jusqu'à une demi-minute. » A cold cache waits for the graph build
  (`build-wait` 30 s, lot 3 §2.4).

### 4.4 Team network in the background: not done

The parent plan §7 wanted the team network faint behind the candidates, « pour comprendre pourquoi
le parcours passe là ». The API does not give it. `RouteGeneratorResponse.network` is a summary
(lengths and counts), and lot 3 §7 deliberately does not expose which routes an edge comes from.
The only geometry the site could draw is the team's route tiles (`routesTile`), which would show the
excluded and still-pending routes too: precisely the roads the generator does **not** use, which is
misleading. The layer is skipped. If it is wanted later, it needs an endpoint (or a tile source)
that serves the graph's edges with their familiarity: a contract change, a later lot.

---

## 5. « Ouvrir dans l'éditeur »

### 5.1 From the page

`navigate(paths.routeNew(team.slug), { state: { generated } })` with `generated = { polyline, type,
distanceM }`. A 300 km candidate is about 30,000 points, about 250 KB encoded, well within
`history.state` limits. The state survives a reload and back/forward. `CreateRoutePage` reads it
(`useLocation().state`, validated by a small zod schema, ignored if malformed) and passes it to
`RouteEditor` as `initialGenerated`.

### 5.2 In the editor

`RouteEditor`:

- `initialGenerated` (or a candidate chosen in `RouteGeneratorModal`) sets `sourceMode = 'planner'`
  when `canUsePlanner`. If the quota is spent, it is ignored with the existing quota message: the
  entry points are disabled anyway, so this only happens through a stale history entry.
- Initial values on creation: `surfaceType = generated.type` (ROAD, GRAVEL or MTB are all
  `SurfaceType` values). The name is filled by the import (below) when the field is empty.
- It passes `importRequest = { seq, polyline, name }` to `RoutePlannerField`, where `seq` is bumped
  for each new candidate.

`RoutePlannerField` (new prop `importRequest`), in an effect keyed on `seq`:

1. `coords = decode2(polyline)`.
2. `file = new File([gpxFromLine(name, coords)], 'parcours-genere.gpx', { type:
   'application/gpx+xml' })`. `gpxFromLine` writes one `<trk><name>` and one `<trkseg>` of
   `<trkpt lat lon>`, coordinates escaped, no elevation.
3. If the route already has ≥ 2 points: `ConfirmDialog` « Voulez-vous vraiment remplacer le tracé
   actuel par ce parcours ? ». « Ajouter à la suite » is not offered: it would route a join leg
   through the provider, and the result would leave the team's roads.
4. `runImport(file, 'replace', { keepFile: false })`. That is the existing path: `POST
   /api/router/import-gpx` with `teamSlug` (FAST elevations, the climb per point, the raw `shape`,
   **no routing provider**, the same rights as the generator), then `routeFromSources`. Every point
   is `imported` with its provenance (`sourceId`, `sourceIdx`), the ends are control points, nothing
   is re-routed (B12 / C4a). `onImportName` fills the empty name field with `name` =
   `generatedRouteName(distanceM, unit)`: « Parcours généré de 82 km ».

`hooks/useRoutePlanner.ts`, the one change to the planner: `importGpx(file, mode, options?: {
keepFile?: boolean })`. With `keepFile: false`, `outcome.produced` stays null, so
`snapshot().file` is absent and the save sends the `plannerState` (one source, one imported piece),
not the file. That is the point:

- an untouched file is uploaded as a file, and a file upload does **not** draw the planner quota
  (`RouteService.createRoute`: `counted` only for a state or points). Decision §10.3 says a
  generated route counts as a drawn track;
- the server derives the track from the state. Its geometry is the candidate's, densified by the
  import, on the same line.

### 5.3 What the person sees, and one known difference

The planner shows the line, the profile (FAST elevations from the import) and the D+ of those
elevations. That D+ can differ by a few percent from the card's `ascentM`, which sums the network
edges' gain from osm-route-details' documents. The saved route gets the usual pipeline (FAST, then
HD). Neither figure is "wrong", and the card's figure is the only one available before the import.
This is not hidden and not corrected.

A failed import (network, `ROUTE_PLANNER_DISABLED`, quota) goes through the existing
`IMPORT_FAILED_KEY` / quota modal of the planner. The candidate stays in the URL of the page and can
be retried.

---

## 6. Error messages

`lib/routeGenerator.ts`, `generatorErrorMessage(error, t, { distance, units })`: a typed table
`GENERATOR_ERROR_KEYS: Partial<Record<ErrorCode, TranslationKey>>`, never a key built from the enum
(the `AUTH_ERROR_KEYS` rule, ledger `WEB-84`). It falls back on `errors.api.<code>`, then on the
generic error. It is rendered as `Alert color="red" variant="light"` above the cards, with
« Réessayer » where retrying can help (BUSY, network, unknown). `{{distance}}` is the requested
distance formatted in the user's unit.

| Code | Français | English |
|---|---|---|
| `GENERATOR_START_TOO_FAR` | Aucune route de l'équipe à moins de 2 km du départ. Choisissez un départ plus proche de ses parcours. | No team road within 2 km of the start. Pick a start closer to the team's routes. |
| `GENERATOR_END_TOO_FAR` | Aucune route de l'équipe à moins de 2 km de l'arrivée. Choisissez une autre arrivée. | No team road within 2 km of the end. Pick another end. |
| `GENERATOR_DISTANCE_TOO_SHORT` | {{distance}}, c'est trop court pour aller du départ à l'arrivée par les routes de l'équipe. Essayez une distance plus longue. | {{distance}} is too short to get from the start to the end on the team's roads. Try a longer distance. |
| `GENERATOR_NETWORK_TOO_SMALL`, details `incomplete` | (plural on `count` = `pendingRouteCount`) L'analyse des routes de l'équipe est en cours : encore {{count}} parcours à traiter. Réessayez plus tard. | The team's roads are still being analysed: {{count}} route(s) left. Try again later. |
| `GENERATOR_NETWORK_TOO_SMALL`, `routeCount = 0`, complete | L'équipe n'a pas encore de parcours sur lesquels générer des propositions. | The team has no routes to generate proposals from yet. |
| `GENERATOR_NETWORK_TOO_SMALL`, otherwise | Les routes de l'équipe autour du départ ne suffisent pas pour {{distance}}. Essayez une distance plus courte ou un autre départ. | The team's roads around the start are not enough for {{distance}}. Try a shorter distance or another start. |
| `GENERATOR_NO_ROUTE` | Aucun parcours trouvé sur les routes de l'équipe pour {{distance}}. Essayez une autre distance ou un autre départ. | No route found on the team's roads for {{distance}}. Try another distance or another start. |
| `ROUTE_GENERATOR_RATE_LIMITED` with `retryAfterSeconds` | (plural on `count` = minutes, rounded up) Trop de demandes en peu de temps. Réessayez dans {{count}} minute(s). | Too many requests in a short time. Try again in {{count}} minute(s). |
| `ROUTE_GENERATOR_RATE_LIMITED` without it | `errors.api.ROUTE_GENERATOR_RATE_LIMITED` (lot 3) | idem |
| `ROUTE_GENERATOR_BUSY` | Le générateur de parcours est très demandé. Réessayez dans un instant. | The route generator is busy. Try again in a moment. |
| `ROUTE_PLANNER_DISABLED` | La génération de parcours n'est pas activée pour cette équipe. | Route generation is not enabled for this team. |
| network error (`isNetworkError`) | Pas de connexion | No connection |
| anything else | Génération impossible | Generation failed |

The details are read as `RouteGeneratorNetworkDetails` when
`error.error.details?.type === 'GENERATOR_NETWORK_TOO_SMALL'`. Every sentence is épicène with no
point médian: it addresses the action, never the person's gender. The French plurals have `_one`,
`_many` and `_other`. `count` is used only for plurals, so the distance is `{{distance}}`.

Optional, same lot: the existing `errors.api.ROUTE_PLANNER_DISABLED` reads « Le tracé
d'itinéraire… ». « itinéraire » is on BRANDING §8.2's forbidden list. The proposed wording is
« Le tracé de parcours n'est pas activé sur ce site. » (§9 D7).

---

## 7. Exclusion box in the route form

`RouteEditor`, right after the surface type `Stack` (both say how the route is used), when
`team.enableRoutePlanner`:

```tsx
<Checkbox
  label={t('routes.create.form.excludedFromGenerator')}
  description={t('routes.create.form.excludedFromGeneratorHint')}
  {...form.getInputProps('excludedFromGenerator', { type: 'checkbox' })}
  disabled={isPending}
/>
```

- Label « Ne pas utiliser pour générer des parcours » / "Don't use to generate routes".
- Hint « Pour un parcours d'événement ou une route ouverte exceptionnellement : ses routes ne
  seront proposées que si un autre parcours de l'équipe les emprunte. » / "For an event route or a
  road open only exceptionally: its roads are only proposed if another route of the team rides
  them."
- `EditRoutePage` `initialValues.excludedFromGenerator = route.excludedFromGenerator ?? false`.
  `CreateRoutePage` and `CreateRouteModal` set `false`.
- The value is always sent with the form. On a team without the planner, the box is hidden and the
  value sent is the route's own, so nothing changes. The mobile form omits the field (null means
  unchanged, lot 3 §4).
- No badge on the route sheet or in the list: the box is a setting of the route, read only in its
  form (`RouteDto` does not carry it, lot 3 §4).

---

## 8. Tests

### 8.1 Vitest

- `lib/routeGenerator.test.ts`:
  - `isEndFar`: no end; just under and just over D/2 (two points 24.9 and 25.1 km apart at 50 km).
  - `routeGeneratorRequest`: start and end left out by default; `bearing` dropped when far, kept
    when near; `type` from the URL wins over the dominant one; the seed passes through.
  - `dominantGeneratorType`: largest count wins, tie ROAD > GRAVEL > MTB, all zero → ROAD.
  - `familiarityBand` boundaries.
  - `gpxFromLine`: parse it back (`DOMParser`), same points, name escaped (`<`, `&`).
  - `generatorErrorMessage`, on a real i18n instance (`await createServerI18n('fr')`, then `'en'`,
    per the frontend rules): every row of §6, the incomplete plural, rate limit with and without
    `Retry-After`, network error.
- `hooks/filters/routeGeneratorFilters.test.ts`: garbage URL (`?d=abc&cap=XX&s=foo`) → defaults;
  `d=500` → 50 (the catch); round trip of `s` with 5 decimals; defaults not written.
- `components/routeGenerator/CompassPicker.test.tsx`: nine buttons with accessible names,
  `aria-pressed`, all disabled with the hint when `far`.
- `components/routeGenerator/RouteGeneratorPanel.test.tsx` (`generateRoutes` mocked with `vi.mock`,
  map mocked like `RoutePlannerField.test.tsx` mocks `RoutePlanner`):
  - « Générer » is disabled while the team has no location and no start, and while the end is
    « Ailleurs » without a point;
  - the request sent: no `bearing` with a far end; `type` = dominant;
  - three cards in the API order, with distance, D+, band, the shared length only ≥ 100 m, unpaved
    only when relevant;
  - « Autres propositions » sends `seed: 1`, and the previous cards stay, dimmed, until the answer;
  - the error rows render in French; « Réessayer » refetches;
  - `familiarityFallback` and `incomplete` notices.
- `components/route/RoutesListHeader.test.tsx` (new): the button is hidden for a member, hidden when
  the planner is off, disabled with its tooltip when the quota is spent, and its link is
  `paths.routeGenerate`.
- `components/route/RouteEditor.test.tsx`, added cases: the box is shown only with the planner;
  edit initialises it from the route; the submitted payload carries it; « Générer un parcours » only
  in create mode, disabled with the quota spent; `initialGenerated` opens in planner mode with
  `surfaceType` preset.
- `components/planner/RoutePlannerField.test.tsx`: `importRequest` triggers `importGpx(file,
  'replace', { keepFile: false })` once per `seq`, and asks for confirmation over an existing route.
- `hooks/useRoutePlanner.test.tsx`: `keepFile: false` → `snapshot().file` undefined and
  `plannerState` present, the points `imported`; the default still keeps the file (existing tests
  unchanged).

### 8.2 End-to-end (`frontend/e2e/route-generator.e2e.ts`, written, not run)

**Constraint.** The e2e stack holds the HD catch-up for 24 h (`.env.e2e`), and `network_edges` are
written by that catch-up, so a seeded team **never has a network** during a run. The real endpoint
therefore always answers `GENERATOR_NETWORK_TOO_SMALL` with `incomplete = true`. The spec uses that
for one real call and stubs the generator for the rest, as `gpx-planner.e2e.ts` stubs the router.

Setup (`beforeAll`): an organizer, a team (`newTeam`, then `setTeamAttributes(team, {
enableRoutePlanner: true })`), two ROAD routes and one GRAVEL route (`newRoute` with `windingTrack`),
and a member account. `stubBasemap(page)` in `beforeEach`.

1. **Real call, pending network.** As the organizer: routes list → « Générer un parcours » → the
   page at `/equipes/{slug}/parcours/generer`. Type preselected « Route » (2 against 1). « Générer »
   → the real POST → the alert « L'analyse des routes de l'équipe est en cours : encore 3 parcours
   à traiter… ». No toast.
2. **Stubbed candidates.** `page.route('**/api/teams/*/route-generator', …)` answers three
   candidates built from `windingTrack` (encoded with `encode2`), `familiarityFallback: false`, and
   records the bodies. The test asserts three cards and three lines (`traceMapPixels` on the
   canvas), then « Autres propositions » → second body `seed: 1`. URL `?e=` far from the start →
   the compass is disabled, and the next body has no `bearing`.
3. **Open in the editor, no provider, quota drawn.** `watchRouter(page)` records the router
   requests. Card 1 → « Ouvrir dans l'éditeur » → `/parcours/nouveau`, planner mode, the name
   « Parcours généré de … », the profile drawn. Save → the route sheet. Assert: **zero**
   `POST /api/router` requests; the saved route's `surfaceType` is the generated type; its first
   and last coordinates equal the candidate's (`coordinatesOf`, within 15 m); `getTeam(...).plannerQuota.used`
   went up by one. Back from the editor: the page shows the same cards without a new POST (request
   count unchanged).
4. **From the editor's opening panel.** `/parcours/nouveau` → « Générer un parcours » → modal →
   stubbed candidates → « Utiliser ce parcours » → the modal closes, the planner holds the line.
5. **Exclusion box.** Edit route 1 → tick the box → save → `GET` the route shows
   `excludedFromGenerator: true` → the edit form opens ticked. Untick → false.
6. **Gating.** As the member: no button on the routes list, and the generator URL redirects to the
   list. With `enableRoutePlanner: false`: no button, and the box is absent from the form.

`e2e/routes-render.e2e.ts` picks up the new route by itself (six roles). Anonymous → login,
member → redirect, organizer → render, with the counts prefetched and the generation query
client-only.

---

## 9. Owner decisions

| # | Question | Proposal |
|---|---|---|
| D1 | Page plus editor modal, rather than a modal only or a page only | Page plus modal, one panel component (§0) |
| D2 | A generated route counts in the planner quota through `keepFile: false` and a source marked `generated` | Yes, decision §10.3. Without `keepFile: false` the editor would save the synthetic GPX as an upload; without the mark the state is imported pieces only, which the backend does not count. A flag on the source rather than a new piece mode: an unknown enum value would break the published mobile apps reading the state |
| D3 | No team network layer in lot 4 | Skip (§4.4); a later lot with an endpoint if wanted |
| D4 | Start and end coordinates in the URL (5 decimals) | Yes, for back-navigation and sharing; the team location is never written |
| D5 | Reserve `generate`/`generer` (and `new`/`nouveau`/`map`/`carte`) as ROUTE slugs | Owner's call; one backend line plus a test, no contract change |
| D6 | Entry disabled when the planner quota is spent | Yes, the « Tracer sur la carte » rule (`BILL-10`) |
| D7 | Fix « Le tracé d'itinéraire » in `errors.api.ROUTE_PLANNER_DISABLED` | Yes, in this lot (lexicon §8.2) |
| D8 | The editor's D+ (FAST) may differ from the card's (edge sums) | Accept and leave as is (§5.3) |
| D9 | The e2e cannot produce a real network on the e2e stack | One real call (pending), the rest stubbed; a real generation e2e would need `network_edges` seeded or the HD catch-up enabled for the run |

---

## 10. Files and order

### 10.1 Files

| File | Change |
|---|---|
| `contracts/routes.yaml` | `routeGenerate` |
| `frontend/src/config/paths.generated.ts`, `mobile/lib/config/paths.generated.dart` | regenerated (`pnpm generate-routes`); web only, so the Dart file gains nothing if the generator skips `mobile: false` routes |
| `config/routes.config.ts`, `config/pageComponents.ts` | `route-generate` entry, lazy page |
| `hooks/filters/routeGeneratorFilters.ts` (+ test) | new |
| `lib/routeGenerator.ts` (+ test) | new |
| `components/routeGenerator/*` (+ tests) | new (§3.1) |
| `pages/route/RouteGeneratorPage.tsx`, `pages/route/routeGeneratorData.ts` | new |
| `components/route/RoutesListHeader.tsx` (+ new test) | button |
| `components/route/RouteEditor.tsx` (+ tests) | third source button, modal, `initialGenerated`, exclusion box |
| `pages/route/CreateRoutePage.tsx`, `pages/route/EditRoutePage.tsx`, `components/route/CreateRouteModal.tsx` | `location.state.generated`; initial `excludedFromGenerator` |
| `components/planner/RoutePlannerField.tsx` (+ test) | `importRequest` prop |
| `hooks/useRoutePlanner.ts` (+ test) | `importGpx(…, { keepFile })` |
| `locales/fr/common.json`, `locales/en/common.json` | `routeGenerator.*` keys, form box keys, optional fix of `errors.api.ROUTE_PLANNER_DISABLED` |
| `frontend/e2e/route-generator.e2e.ts` | new, not run |
| optional `backend/.../service/common/SlugService.java` + `SlugServiceTest` | D5 |

### 10.2 Order

1. `useRoutePlanner` `keepFile` and its test. This is the only change to existing behaviour: run
   `pnpm test` on the planner suites.
2. Exclusion box in `RouteEditor` plus `EditRoutePage`. It stands alone and can ship first.
3. `lib/routeGenerator.ts` and the filters schema, with their tests.
4. `routes.yaml` → `pnpm generate-routes`; route entry and data module; the empty page with its
   guards.
5. `CompassPicker`, `GeneratedRouteCard`, `RouteGeneratorMap`, `RouteGeneratorPanel`, the page;
   Vitest.
6. `RoutesListHeader` button.
7. « Ouvrir dans l'éditeur »: `CreateRoutePage` state, `RouteEditor.initialGenerated`,
   `RoutePlannerField.importRequest`; then `RouteGeneratorModal` and the third source button.
8. i18n keys in both files, `pnpm format` (sorts the catalogues; the owner runs it before
   committing), `pnpm typecheck && pnpm lint && pnpm test`, `pnpm i18n:check`.
9. The e2e spec, written; the owner runs it with `scripts/e2e.sh run route-generator`.
10. Ledger: `WEB-179` to `LEDGER_DONE.md` with the decisions of §9 once taken, in the commit of the
    work (not in this design step).

---

## 11. Deliberately out of lot 4

- **The team network layer** (§4.4): no geometry in the API.
- **A target D+**: parent plan §10.7, displayed only.
- **Excluding one stretch on the map**: parent plan §10.8, later.
- **Generator in the app** (`MOB-154`): the app has no route editor.
- **Showing `crossings` and `bearingDeviationDeg`**: in the API for the bench and for later; the
  parent plan's card does not list them.
- **A badge "exclu du générateur"** on route sheets or lists: the box is read only where it is
  edited.
- **Saving straight from the generator** without the editor: the editor is where the person names
  the route, checks it and spends the quota.

---

## 12. As implemented (14 November 2026)

Coded as designed; no contract change, no backend change. The deviations, and what was not done:

- **Points in the URL are strings.** `useUrlFilters` writes a value with `String(value)`, so `start` and
  `end` stay `"lat,lng"` strings (5 decimals) in the filters and are turned into a `GeoPoint` at the
  edge (`pointFromParam` / `pointToParam` / `normalizePointParam` in `lib/routeGenerator.ts`). The schema
  normalises a hand-written value to 5 decimals and drops garbage.
- **`errorDetails`, not `details`.** The generated `ErrorResponse` carries `errorDetails`; the network
  details are read from it (`type === 'GENERATOR_NETWORK_TOO_SMALL'`).
- **Markers are not draggable** (§4.1): `StartMarker` / `EndMarker` are the shared, static ones. A point is
  moved with « Choisir sur la carte » / « Déplacer », which is also the keyboard-reachable path.
- **« Partir d'ici »** is a small overlay offered after a place is picked in the map's search box (it
  writes `s`); the search control itself is the shared `MapSearchControl`.
- **A second press on « Générer »** while results are shown asks for other proposals (seed + 1): the same
  request would only come back from the cache. Page and modal behave alike.
- **`placeholderData`** keeps the previous cards only when the new request differs from the old one by the
  seed alone (« Autres propositions »). Any other change clears `go`, so no results are shown for other
  parameters.
- **The exclusion box** is sent with the form on every save of a team with the planner. `CreateRoutePage`
  and `CreateRouteModal` start it at `false`, `EditRoutePage` from `route.excludedFromGenerator ?? false`.
- **D7 done:** `errors.api.ROUTE_PLANNER_DISABLED` (French) now reads « Le tracé de parcours n'est pas
  activé sur ce site. ». **D5 not done** (reserved slugs): left to the owner, no backend line added.
- **`routes-render.e2e.ts`**: the dataset's team keeps its route planner off, so `routeGenerate` is declared
  there as « every signed-in role is sent back to the routes list » (the `gpxToolsNew` pattern). The page
  itself is exercised by `route-generator.e2e.ts`, on a team with the planner on.
- **Generated files**: `pnpm generate-routes` rewrote `mobile/lib/config/paths.generated.dart` without its
  `dart format` blank lines and added nothing (web-only route); that file was restored. The apple
  app-site-association file gained the two `NOT` entries of the new path, as for `routesMap`.
- **Catalogues**: keys added to both files, sorted with `i18next-cli extract` (not `pnpm format`, which the
  owner runs); the new `routeGenerator.*` keys, `routes.create.form.sourceModeGenerator`,
  `…excludedFromGenerator` and `…excludedFromGeneratorHint`.
- **Not unit-tested**: `RouteGeneratorModal` (the reducer is the page's patch rules over local state, and its
  hand-off is covered through the editor test and the e2e), `RouteGeneratorPage` guards, the map component
  (stubbed in the panel test; its drawing is in the e2e through `traceMapPixels`).
- **e2e written, not run** (`frontend/e2e/route-generator.e2e.ts`, six scenarios + the `routes-render` entry).
  The scenario 3 assertion that the saved line equals the candidate's relies on the first stubbed
  candidate being the winding track itself; scenario 1 makes the one real call and expects the
  « analyse en cours » answer, which needs the HD catch-up to stay held on the e2e stack (D9).

Checks run: `pnpm typecheck`, `pnpm lint` (one pre-existing warning), `pnpm i18n:check`, `pnpm vitest run`
(248 files, 2391 tests, all green), `prettier --check` on `src` and `e2e`.

### Review fixes (14 November 2026)

- **Layer order (major)**: the layers of every candidate now stay mounted, in a fixed order (casing and
  chevrons hidden by opacity / `visibility: none` when not selected), and an effect keyed on `selected` and
  the candidates calls `map.moveLayer` on the selected candidate's casing, line, arrows and hit layers, so
  the selected line is on top with its colour. Not unit-testable (the map is stubbed); to check in the e2e.
- **End without a mouse (major)**: `FoundPlaceOverlay` (new, extracted from `RouteGeneratorMap`) offers
  « Arriver ici » next to « Partir d'ici » when the end is « Ailleurs » (`endElsewhere` prop, key
  `routeGenerator.end.here`). Test: `FoundPlaceOverlay.test.tsx`.
- **Sliders (minor)**: `thumbLabel` / `thumbValueText` on both sliders (band in words for familiarity),
  root-level aria props removed.
- **Cards (minor)**: the card header is an `UnstyledButton` (`aria-pressed`) that selects; a spent quota
  puts the reason in a focusable `Tooltip` around a `span` instead of `title` on the disabled button.
  No dedicated test.
- **Replayed import (minor)**: `RoutePlannerField` calls `onImportHandled(seq)`; `RouteEditor` drops the
  request then and keeps a monotonic `seq` in a ref. Test: planner → GPX → planner in `RouteEditor.test.tsx`
  (the field stand-in now mimics the take-once behaviour).

Checks: `pnpm typecheck`, `pnpm lint` (the same pre-existing warning), `vitest run` on `routeGenerator`,
`route` and `planner` (33 files, 252 tests, green).
