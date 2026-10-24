# Data-loading companion modules

How a screen's data gets declared **once** and read twice: by the page as hooks, by
`routes.config.ts` as a prefetch. Read this before adding or editing a route's `prefetch`.

## The problem this solves

A server-rendered page needs its data described in two places that must agree byte-for-byte:

- the page's own hooks (`useGetRide`, `useListRoutes`, …), which build the query key at render
  time from the router's params and the URL's filters;
- the route's `prefetch` in `routes.config.ts`, which must land the *same* keys in the
  per-request `QueryClient` before the render.

Nothing in the type system enforces the agreement, and a divergence is **silent** to the eye: the
page still works, the data still arrives — only after hydration instead of before it. No error. It
shows up as a `[prefetch-audit]` console warning, which `e2e/routes-render.e2e.ts` turns into a
failing test for every screen and role (the e2e image is built with `FRONTEND_PREFETCH_AUDIT=true`,
ledger `WEB-52`).

The failure modes are all "looks fine, reads different":

| Divergence | Symptom |
|---|---|
| A param spelled out by hand (`{ page: 0, size: 12 }`) that the page later changed | key mismatch, full refetch |
| A slug array built in a different **order** (query keys are structural — `['a','b'] ≠ ['b','a']`) | key mismatch, duplicate request |
| The URL's filters read through a different schema/alias than the page uses | server renders one list, client refetches another |
| A derivation copied and then edited on one side only | one of the two is dead weight in the cache |

## The pattern

One module per screen, named after it, sitting next to the page: `pages/<domain>/<screen>Data.ts`.
It exports up to three things:

1. **The shared derivation(s)** — whatever turns route params or the URL into query params:
   a slug set, a filter schema/alias pair, a params builder.
2. **`use<Screen>Data(...)`** — every query the page itself owns, returned as the **raw query
   results** (`{ data, isLoading, error, refetch, … }`) so the page keeps reading them directly.
3. **`prefetch<Screen>(queryClient, …)`** — the same data server-side, as one `Promise.all`
   (or two, when a second wave depends on the first), reusing the exact same derivations.

The route entry then reduces to a single call:

```ts
prefetch: (queryClient, params, url) => prefetchRouteList(queryClient, params.teamSlug!, url),
```

### Rules

- **Its own module, never an export of the page.** `routes.config.ts` is imported eagerly by both
  entries; importing the page would drag its lazy chunk into the main bundle. (Same reason
  `pages/home/nextRideParams.ts` and `components/common/placeAutocompleteParams.ts` exist.)
  Check after a build: the page must still have its own chunk.
- **Derive, never copy.** If both sides call the same function, they cannot drift. That is the
  whole point — a comment saying "keep in sync with…" is the thing being replaced.
- **Canonical order for anything array-shaped in a key** — dedupe *and* sort, in the shared
  function, once.
- **Auth stays out of the shared hook.** The page reads it via `useAuth()`, the prefetch via
  `useAuthStore.getState()` (the server has no hook, and the store is a per-request-forbidden
  singleton — see [SSR.md](SSR.md#session-aware-ssr)). Keep auth-conditional branches inside
  `prefetch<Screen>`.
- **The prefetch may legitimately cover more than the hook** — data fetched by children the page
  mounts (comments, GPS export options). Say so in the docblock, so the asymmetry reads as
  deliberate rather than as an oversight.
- **Shared prefetch primitives live in `config/prefetchHelpers.ts`** (`prefetchPageWindow`,
  `prefetchMemberComments`, `prefetchRoutesBulkChunked`, `resolveMembershipDefault`), not in
  `routes.config.ts` — a companion importing them back from `routes.config.ts` would be a cycle.

Two shapes fall out of the rules rather than being exceptions to them:

- **One module, two routes** when a screen has a sibling view over the same data — a list and its
  map (`allRouteListData.ts` serves `all-routes` and `all-routes-map`), a detail page and its
  fullscreen map (`routeDetailData.ts` serves `route-detail` and `route-map`). One filter/params
  derivation, one hook per view, one prefetch per route.
- **Prefetch-only**, when the page itself owns no query and only mounts children that do
  (`pages/profile/profileData.ts`: each profile page mounts the section components that query —
  `PasskeyManager`, `NotificationPreferences`…). Export the prefetch; adding a hook nobody calls
  would be noise.

## The two shapes, worked

### A detail page — `pages/ride/rideDetailData.ts`

Dependent data: the routes bulk needs the ride's groups, so the prefetch runs in two phases.
The derivation is the interesting part — it is what had already drifted:

```ts
/** The ride's own route plus every group's, deduped and sorted (the array goes into the key). */
export function rideRouteSlugs(ride: RideDto | undefined): string[]
```

The page, `RoutesMapView` and the prefetch now share that one set, so all three hit a single
`/routes/bulk` cache entry. Before, the page derived `group.routeSlug || ride.routeSlug` while the
map derived the ride's route *plus* the groups' — two keys, two requests, a prefetch covering one.

### A list page — `pages/route/routeListData.ts`

The key is derived from the **query string**, so the page (via `useRouteFilters`) and the prefetch
(via `readUrlFilters(url.searchParams, …)`) must read it through the same schema *and* the same
alias, then project it the same way:

```ts
export const routeListFilterOptions = { schema: routeFiltersSchema, alias: routeFiltersAlias } as const
```

The hook returns the filter state as `useRouteFilters` gives it (the panel needs the setters) plus
the query results; `prefetchRouteList` prefetches `prefetchPageWindow(routeApiParams(filters), …)`
— the page the URL asks for **plus the neighbours** `usePaginatedQuery` fetches ahead on the
client. A filtered link (`?q=gravel&p=2&sort=DISTANCE`) must server-render *that* list.

## Where they are

**Every route with a `prefetch` has a companion** — including the ones whose prefetch is a single
generated call. That is a deliberate call for homogeneity over economy: what a screen loads is worth
one predictable place to look, and a one-line module today is what stops the next query from being
added to the page and forgotten in the prefetch. Don't reintroduce the exception.

| Companion | Route id(s) | What it shares |
|---|---|---|
| `pages/home/homeFeedData.ts` | `home` | membership-defaulted filter schema, `publicationApiParams`, the `hourAlignedNowIso()` boundary |
| `pages/team/teamListData.ts` | `teams` | membership-defaulted filter schema, `teamApiParams`, page window |
| `pages/team/teamHomeData.ts` | `team-detail` | the team and its dashboard, side by side (the dashboard answers everyone, API-86) |
| `pages/team/teamAgendaData.ts` | `team-agenda` | agenda filters (`when`, no clock in the key), `agendaApiParams`, page window, the tags of the chosen kind |
| `pages/team/teamPostsData.ts` | `team-posts` | post filters, `teamPostApiParams`, page window, the post tags |
| `pages/route/routeListData.ts` | `routes` | route filters schema/alias, page window |
| `pages/route/allRouteListData.ts` | `all-routes`, `all-routes-map` | cross-team filters + `minRole` projection |
| `pages/ad/adListData.ts` | `ads` | ad filters schema/alias, page window |
| `pages/ride/rideDetailData.ts` | `ride-detail` | `rideRouteSlugs`, two-phase prefetch |
| `pages/ride/rideGroupData.ts` | `ride-group`, `ride-group-map` | the ride page's own reads (shared keys), the group's participants from the URL (`groupParticipantsParams`, the page only) |
| `pages/trip/tripDetailData.ts` | `trip-detail` | `tripRouteSlugs`, two-phase prefetch |
| `pages/trip/stageDetailData.ts` | `stage-detail` | `stageRouteSlug` (the stage's route, looked up inside the trip) |
| `pages/post/postDetailData.ts` | `post-detail` | two-phase prefetch (comments for the child) |
| `pages/route/routeDetailData.ts` | `route-detail`, `route-map` | team+route pair, usages, comments, GPS services |
| `pages/profile/profileData.ts` | `profile` and its sub-pages | prefetch-only: the summary, and each section's parameterless query |
| `pages/profile/myRidesData.ts` | `my-participations` | the tab/page filters, the two totals and their shared hour boundary |
| `pages/calendar/calendarData.ts` | `calendar` | `getInitialCalendarRange()`, the range the hook seeds itself with |
| `pages/team/teamMembersData.ts` | `team-members`, `team-directory` | member filters, the pending-invitations params (admin screen only) |
| `pages/team/teamPlacesData.ts` | `team-admin-places` | the place filters `PlaceList` reads |
| `pages/ridetemplate/rideTemplateListData.ts` | `ride-templates` | ride-template filters |
| `pages/ride/rideFormData.ts` | `ride-new`, `ride-edit` | the two `PlaceAutocomplete` param sets the form mounts |
| `pages/gpxtool/gpxPreviewData.ts` | `gpx-tools-view`, `gpx-tools-map` | the preview query (public: the unguessable id *is* the credential) |
| `pages/team/teamAboutData.ts` | `team-about` | the team query |
| `pages/team/teamPageData.ts` | `team-page` | team + page pair |
| `pages/team/teamAdminData.ts` | `team-admin` | the team query (no prefetch — see below) |
| `pages/team/teamSettingsData.ts` | `team-settings` | idem |
| `pages/team/teamPagesAdminData.ts` | `team-admin-pages` | the pages list |
| `pages/team/teamPageFormData.ts` | `team-admin-page-new`, `team-admin-page-edit` | the page being edited |
| `pages/trip/tripFormData.ts` | `trip-new`, `trip-edit` | the trip being edited |
| `pages/post/postFormData.ts` | `post-new`, `post-edit` | the post being edited |
| `pages/route/routeFormData.ts` | `route-new`, `route-edit` | the route being edited |
| `pages/ad/adFormData.ts` | `ad-new`, `ad-edit` | the ad being edited |
| `pages/ad/adDetailData.ts` | `ad-detail` | team + ad pair |
| `pages/ridetemplate/rideTemplateFormData.ts` | `ride-template-new`, `ride-template-edit` | team, and the template being edited |
| `pages/calendar/teamCalendarData.ts` | `team-calendar` | the team, then its events over `getInitialCalendarRange()` for members, and the calendar token |
| `pages/route/routesMapData.ts` | `routes-map` | route filters from the URL, team + routes bounds |
| `pages/trip/stageMapData.ts` | `stage-map` | team + trip, then the stage's route |
| `pages/team/teamFormData.ts` | `teams-new` | the existence probe (`TEAM_EXISTENCE_PROBE_PARAMS`) |
| `pages/team/teamReportsData.ts` | `team-admin-reports` | report filters from the URL |
| `pages/device/deviceVerifyData.ts` | `device-verify-karoo`, `device-verify-garmin` | the available GPS services |
| `pages/gpxtool/gpxPreviewListData.ts` | `gpx-tools-list` | preview-list filters from the URL, page window |
| `pages/gpxtool/gpxPreviewFormData.ts` | `gpx-tools-edit` | the preview being edited |
| `pages/notification/notificationListData.ts` | `notifications` | the filtered inbox page — hook only, **no prefetch** (per-user inbox, see its docblock) |
| `pages/admin/adminDashboardData.ts` | `admin` | the platform stats |
| `pages/admin/adminDomainsData.ts` | `admin-domains` | the default domain list |
| `pages/admin/adminTeamsData.ts` | `admin-teams` | the domain filter options + the default team list |
| `pages/admin/adminUsersData.ts` | `admin-users` | the domain filter options + the default user list |
| `pages/admin/adminBetaSignupsData.ts` | `admin-beta-signups` | the default beta-signup list |
| `pages/admin/adminReportsData.ts` | `admin-reports` | report filters from the URL |

`routes.config.ts` imports exactly one generated function now — `prefetchGetTeamQuery`, for
`teamScopedPrefetch`. Anything else it needs comes from a companion.

The admin screens keep the `teamScopedPrefetch(...)` wrapper in `routes.config.ts` — the auth gate and the
team query are shared by ~15 routes, so the companion exports only the screen-specific part.

**The team-only screen** (`team-admin`, `team-settings`, and every `…-new` form) reads nothing but the team,
and its route is a bare `teamScopedPrefetch()`. Its companion exports the **hook only, no `prefetch`
function**: the wrapper already primes that exact key, and a companion prefetching it again would write the
same key twice. The docblock says where the prefetch side lives, so the module is still the one place to
look. See `teamAdminData.ts`.

**Known limitation, deliberately preserved**: those admin lists prefetch `someFiltersSchema.parse({})` — the
*default* list, ignoring the URL's filters, unlike the public lists which go through `readUrlFilters`. Each
companion says so in its docblock. It is a prefetch gap, not a divergence: page and prefetch still agree on
the default list, and a filtered URL simply refetches after hydration.

## Adding a route

Write the companion first, then the route entry. Even if the screen reads one thing:
`use<Screen>Data` next to `prefetch<Screen>`, and `prefetch: (qc, params) => prefetch<Screen>(…)` (or
`teamScopedPrefetch((qc, p) => prefetch<Screen>(qc, p.teamSlug!))` under `/teams/{slug}/…`). A route entry
that calls a generated `prefetchXxxQuery` directly is the shape this file exists to prevent — the exception
that used to be documented here was removed on purpose.

## One known gap, deliberately left

Not a page/prefetch divergence — both sides agree; it is simply something the prefetch does not
cover. Left alone so a refactor stays a refactor; the SSR audit is what should rule on it.

- The admin lists prime `someFiltersSchema.parse({})`, the **default** list, ignoring the URL's filters
  (unlike the public lists, which go through `readUrlFilters`). `admin-reports` and
  `team-admin-reports` are the exception: they read the URL.

The two other gaps once listed here are closed: `ride-template-edit` now prefetches the template
(`prefetchGetTemplateQuery`), and `ad-edit` primes both `getAdEdit` and `getAd`.

## Verifying

The audit is the check, not the network tab — it names the exact keys that were fetched late:

```bash
API_BASE_URL=https://staging.pedalons.fr PORT=3111 pnpm dev:ssr

# 1. the right keys are in the dehydrated state (filters included)
curl -s 'http://localhost:3111/equipes/<team>/parcours?q=gravel&p=2' \
  | grep -o 'id="ssr-query-state".*' | head -c 2000

# 2. nothing is fetched after hydration
pnpm e2e routes-render -g '<routeId> /'    # on the e2e stack, every role — or one page in a browser:
# console → [prefetch-audit] route "…": all queries were covered by route prefetch
```

`[prefetch-audit]` only flushes after 5 s with no fetch activity (`SETTLE_DEBOUNCE_MS` in
`lib/prefetchAudit.ts`) — a scripted check must wait that long before concluding anything, and the
build/server must have `FRONTEND_PREFETCH_AUDIT=true`.

## Reading a prefetch gap

- **"Depends on the viewport" is a claim to verify against the component, not a category to file
  a gap under.** The calendars' late `calendar/events` window was once dismissed that way; the
  range actually came from `CalendarView`'s mount effect, `getVisibleRange(date, view)`, a pure
  function of two pieces of state that replaced the prefetched window one render after hydration.
  `useCalendarDateRange` now bails out when the visible range is already inside the loaded one,
  which required snapping that window to month boundaries (`useCalendarDateRange.test.ts` guards
  the end-of-month days a rolling window missed). A range a mount effect computes from state is
  always reproducible server-side.
- **A query fired only on interaction is not a gap.** The deletion impact of « Mon compte » is
  read when its confirmation opens; it cannot and need not be prefetched. The audit settles
  5 s after load, before any click, so it does not see them.
- **A production build tells you *that*, not *where*.** It minifies hydration errors (`#418` =
  mismatch, with `args[]` naming what mismatched; `#185` = update loop) and carries no component
  diff, and minified class names are chunk-local (two vendor chunks can each define their own
  `Tn`), so a name from the bundle identifies nothing. Re-run the failing route against
  `pnpm dev:ssr` to get the component tree.
