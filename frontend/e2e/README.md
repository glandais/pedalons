# End-to-end tests

Playwright, against the **real application**: the SSR frontend and the backend images behind
traefik, with postgres, MinIO, imgproxy and mailpit — the deployment's `docker-compose.yml` plus the
`docker-compose.e2e.yml` overlay. Nothing is mocked: logins read their OTP and verification links
from mailpit, data is seeded through the REST API.

## Running

From the repository root:

```bash
scripts/e2e.sh up          # build the tribly-e2e images if missing, start, wait until it answers
scripts/e2e.sh test        # run the suite (any Playwright argument passes through)
scripts/e2e.sh reset       # empty database, files and saved sessions, then up
scripts/e2e.sh build frontend   # after a code change: rebuild an image, then `up` again
scripts/e2e.sh down
```

The app is on http://localhost:8190, mailpit on http://localhost:18025 — every port is offset from
the workstation stack (`tribly-local`), so both run side by side. `tileserver` is borrowed from
the workstation stack's network; when it is down the e2e stack still starts, but map tiles fail.
Routing (the planner, `POST /api/router`) goes to the Stadia Maps API: `scripts/e2e.sh` takes
`STADIAMAPS_API_KEY` from its environment, else from the workstation's `.env`, and hands it to the
backend through `docker-compose.e2e.yml` — never through `.env.e2e`, which is committed. Without a
key it exports `E2E_NO_ROUTING=1` and `playwright.config.ts` skips `gpx-planner.e2e.ts`.

From `frontend/`: `pnpm e2e` (same as `scripts/e2e.sh test`), `pnpm e2e:ui` (Playwright's UI mode),
`pnpm e2e:typecheck`. After a failure: `pnpm exec playwright show-report e2e/.report`, or
`show-trace` on the `trace.zip` the failure printed.

**Don't run the backend suite at the same time.** Its Testcontainers create and remove veth
interfaces on the host; Chromium reports `net::ERR_NETWORK_CHANGED` and fails to load chunks
(« Failed to fetch dynamically imported module »), which surfaces as random hydration timeouts.
Under load, `--workers=5` is steadier than the default.

**Parallel runs need distinct output dirs.** Playwright empties its output directory (traces,
screenshots) when a run starts, so two runs sharing one wipe each other's failure traces.
Give each its own: `E2E_OUTPUT=/tmp/e2e-mine pnpm e2e`, or `--output=/tmp/e2e-mine`.

**The tests run against images, not your working tree** — rebuild (`scripts/e2e.sh build frontend`
or `backend`, about a minute each) and `up` before testing a change. `E2E_BASE_URL` and
`E2E_MAILPIT_URL` override where the suite looks, but the stack behind them must be one whose
bootstrap admin is `admin@e2e.test` — not the workstation stack.

## The SSR check: `routes-render.e2e.ts`

It opens every web route of `contracts/routes.yaml` as six roles and fails on a hydration error, an
uncaught page error, an error screen, and — on every screen rendered on its own path — any
`[prefetch-audit]` verdict but `covered`: a query the page read after hydration that its route's
`prefetch` did not put in the server render (see [docs/SSR-data-loading.md](../docs/SSR-data-loading.md);
ledgers `WEB-52`, `WEB-53`). Its dataset (`support/routes-render.ts`) fills every entity the way a
real team would — a ride with groups, routes and places, an ad with pictures and a location… — so the
queries that only fire when the data exists are audited too: when a screen starts reading a new
field, give the dataset that field.

- **The audit is compiled in**: `.env.e2e` sets `FRONTEND_PREFETCH_AUDIT=true`, read at image build
  time. `scripts/e2e.sh up` only builds a *missing* image, so a `tribly-e2e` frontend image built
  before that line fails every rendering test with « no [prefetch-audit] verdict »: rebuild it
  (`scripts/e2e.sh build frontend`).
- **One route**: `pnpm e2e routes-render -g '<routeId> /'` (every role, both projects).
- **Not every `console.error` fails it**, deliberately (decided 2026-10-04): only `[hydration]`.
- **A green run dates from the day it ran.** A screen whose prefetch depends on the date (the
  calendars' month windows) can be covered on the 4th and have a gap on the 27th; that is a unit
  test's job (`useCalendarDateRange.test.ts`), not this one's.

## In CI

`.github/workflows/e2e.yml` runs the whole suite **every night on `develop`** and **on demand**
(Actions › E2E › Run workflow), never on pull requests. It builds both images on a GitHub-hosted
runner, starts this same stack with `scripts/e2e.sh up`, and uploads the report, the traces and the
stack's logs when something fails. The routing key comes from the repository secret
`STADIAMAPS_API_KEY`, so the planner test runs there too (without the secret, `scripts/e2e.sh`
skips it as above). The job's first step fails unless `.env.e2e` still points the mailer at mailpit.

## Why a separate stack

The workstation database is a biketeam restore holding thousands of real member addresses, and a
test run sends OTPs and invitations. The e2e stack starts on an **empty** database, its mailer only
reaches mailpit, and `.env.e2e` holds nothing but throwaway values — which is why it is committed.

## Writing tests

- Files are `*.e2e.ts` (Vitest's glob would pick up `*.spec.ts`).
- Import `test`, `expect` and `as` from `./support/fixtures`. `test.use(as('rider'))` signs a block in
  as that role; the `seed` fixture says what `global-setup.ts` created (a public team with the
  platform admin as owner and the rider as member).
- **`test.use(as(role))` also signs in the API contexts of `support/api.ts`**: they inherit the
  `refresh_token` cookie, which the backend accepts (`getUserFromRefreshTokenCookie`). A call meant
  to be anonymous then runs as that role — sign the page in with `signIn(context, roleSession(…))`
  instead when a test mixes a signed-in page and anonymous API calls.
- **Never modify the seed from a test.** Create what the test needs, with a unique name, through
  `support/api.ts` — the suite runs fully parallel, on two projects (desktop and mobile).
- Type request bodies with the generated DTOs (`import type { … } from '../src/api/dto'`): a field
  the contract made required is then a type error instead of a 400 at run time.
- The app speaks French by default (`locale: 'fr-FR'`), so navigate with the French paths
  (`/connexion`, `/equipes/…`) — or with the English ones, which the router registers too.
- Prefer roles and accessible names (`getByRole('heading', { name })`) over text: the same text
  often appears in a breadcrumb that the mobile layout hides.

## Shared helpers

Everything a journey needs lives in `support/`, one module per domain, one implementation of each
helper — reuse before writing a new one, and keep journey-only helpers in their own
`support/<journey>.ts` (`flow-account.ts`, `flow-team.ts`, `routes-render.ts`, …).

- `api.ts` — `withApi(who, run)` (a disposable request context signed in as `who`, or anonymous),
  `apiGet` / `apiPost` / `apiPut` / `apiPatch` / `apiDelete` (parsed body, or an `ApiError` with the
  backend's `code`), `apiGetOrNull` (null on a 404: a deleted or unknown entity), `expectOk`, the
  logins and `refresh`.
- `data.ts` — `roleSession(role)` (cached per worker), `signIn(context, auth)`, `newUser`,
  `freshAddress` (an address with no account), `markdownMedia`, `teamRequest`, `newTeam` (applies
  the `enable*` flags POST ignores, and a non-TEAM visibility as the platform admin;
  `{ addMemberAllowed: true }` lets the team's admins add and invite), `getTeam`,
  `setTeamAttributes`, `addMember` (as the platform admin unless the team allows it), `newTeamPage`.
- `fixtures.ts` — `test`, `expect`, `as(role)`, the `seed` fixture, `unique(label)`.
- `rides.ts` — `rideRequest`, `newRide`, `readRide` / `findRide`, `readComments`, `readTemplates`,
  `joinGroup`, `postComments`, `openRide`, `groupCard`.
- `routes.ts` — `newRoute` (GPX upload), `getRoute`, `newTrip`, `fetchTrip` (null once deleted),
  the route/trip/stage paths, `stubBasemap`, `traceMapPixels`, `watchRouteReads`.
- `posts.ts` — `newPost`, `fetchPost` / `findPost`.
- `ads.ts` — `newAd` (with pictures), `getAd`, `uploadImage`, `solidPng`.
- `editor.ts` — the rich-text editor every form shares: `richText(scope, name?)` (by its accessible
  name, « Description » unless `EDITOR_LABEL` says otherwise), `typeRichText`, `toolbarButton`,
  `addImage`, and `letEditorSettle(page)` — lets its 150 ms debounce hand the text over. Saving
  needs no pause (the editor flushes on blur); removing an editor with an update queued does
  (needs `page.clock.install()` before the first `goto`).
- `dates.ts` — Paris wall-clock dates (`WallClock`, `parisWallClock`, `parisDaysAhead`,
  `parisInstant`, `pickerText`, `frenchDateTime`) and the Mantine DateTimePicker driver
  (`pickDateTime`, `openPicker`).
- `calendar.ts` — the team calendar on both layouts: `openCalendar(page, team, day)`,
  `calendarEvent`, `teamEvents`. Its events are SSR-prefetched, so an absence check needs another
  event of the same view shown first.
- `contract.ts` — `contractWebRoutes()` (contracts/routes.yaml), `configuredAuth()`
  (routes.config.ts), `fillPath`.
- `mailpit.ts` — `mailbox` + `waitForNewMail` (text of the next mail), `mailsTo` (headers and every
  part), `otpCodeIn`, `linkTokenIn`.
- `ui.ts` — `hydrated(locator)` before clicking a server-rendered control, `pageHydrated`,
  `watchHydration` (hydration errors, uncaught page errors, discarded server markup), `toasts`,
  `watchToasts` (every toast shown, where a retrying `toHaveCount(0)` would pass vacuously),
  `pageAs(browser, auth)` (a second browser with the project's device — never a bare
  `browser.newContext()`), `entityCard`, `actionsMenu` / `openActionsMenu` (a detail page's
  « Options de gestion » chevron), `escapeRegExp`, `startsWith`.
- `stack.ts` — where the e2e stack answers (`stack`, read from `.env.e2e`; `E2E_BASE_URL` /
  `E2E_MAILPIT_URL` override it), `storageStatePath`, `seedPath`.
- `domains.ts` — multi-tenancy: `hostHeader`, `onHost` / `hostGet` / `hostPost` / `hostPut` /
  `hostStatus`, `registerOn` / `loginOn` / `signInOn`, `otherDomain`, `newTeamOn`, `pinnedTeam`,
  `pinnedAlias`, `hostDocument`, `plannerSite`.
- `ssr.ts` — the server-rendered document without a browser: `rawDocument`, `ssrOutlet`,
  `reactQueryState` / `dehydratedQuery`, `ogTags`, `authState`, `sessionCookie`.
- `list-pages.ts` — URL-driven list pages ([docs/URL_FILTERS.md](../docs/URL_FILTERS.md)): `watchListReads`,
  `openServerRendered`, `expectInMarkup`, `expectQuery`, `nextPage`, `expectCurrentPage`.
- `invitations.ts` — `inviteByApi`, `invitationTokenIn`, `previewInvitation`, `membershipsOf`.
- `member-directory.ts` — `directoryTeam` (one account per role, none a platform admin),
  `setMemberDirectory`, `listMembers`.
- `platform-admin.ts` — the admin screens and their API: team/user/domain rows, `setPlatformRole`,
  `toggleTeamArchived`, domain aliases (`aliasesOf`, `deleteAlias`), `gpsCredentialsOf`,
  `scratchDomain`, `betaSignups`.
- `moderation.ts` — `report`, `blockedBy`, `teamQueue` / `platformQueue`, `moderationWorld`,
  `queueCard`, `queueTab`, `commentRow`.
- `notifications.ts` — a user's inbox and preferences through the API: `listNotifications`,
  `unreadCount`, `waitForNotification` (the dispatcher's wait), `expectNoNotification`,
  `notificationPreferences`, `isMuted`.
- `device.ts` — the Karoo/Garmin device code flow: `startDeviceFlow`, `verifyUserCode`,
  `pollToken` / `pollError`, `refreshDeviceToken`, `deviceMe`, `jwtClaims`; Hammerhead offered on
  `localhost` (`ensureHammerheadOffered`, get-or-create) and played by `refuseAtHammerhead`, which
  intercepts the browser's trip to Hammerhead and sends it back to the callback refused (ledger
  `API-63`).
- `ad-contact.ts` — the classified-ad e-mail relay: `setContactable`, `contactAuthor`, `rawAd`.
- `scheduled-publication.ts` — scheduled posts and trips: `pickIntoEmptyPicker`, `pastPublishAt`,
  `waitForAutoPublish`.
- `slug-change.ts` — renaming a team, ride, route or ad URL with `SlugEditor` and the redirects kept
  from old slugs: `slugScene`, `renameThroughApi`, `readAt`, `slugEditor`, `freshSlug`.
- `pwa.ts` — the installable site: `waitForServiceWorker`, `cacheNames`, `manifestOf`,
  `installPromptDouble` / `fireInstallPrompt`, `watchFirebase`.

## How sessions work

**The refresh token rotates at every refresh** (ledger `SEC-27`): the refresh answers with a new
token, the one presented is honoured for another minute, and presented after that it **rotates again
from itself** (ledger `API-94`: the client lost the answer) — the token it had been replaced by
dies, and whoever holds it is refused at its next refresh. The browser refreshes on every document (the SSR server
does, and hands it the new cookie). So a session has **one owner** — the test, or one browser
context — and never a token saved and shared:

- `global-setup.ts` saves no session. It gives each role a password (the bootstrap admin, created
  without one, gets it once through the mailed reset link) and writes it to the seed; password
  logins are only rate-limited on failures.
- `as(role)` logs a fresh session in for each context; `roleSession(role)` logs one in per worker,
  at most every 10 minutes.
- `signIn(context, auth)` gives the browser **a session of its own** whenever `auth` carries its
  password (`newUser()`, `roleSession()`, `registerOn()`), the test keeping `auth`'s. Otherwise
  the browser takes `auth`'s session over, and the test must stop refreshing it.
- To read the browser's session, pass the context: `meFromSession(context)`,
  `sessionIsAlive(context)` write the rotated token back into its cookie. With an AuthResponse,
  `refreshHeld(auth)` / `meFromSession(auth)` keep it in the object; `rawDocument`/`hostDocument`
  do the same for a cookie built by `sessionCookie(auth)`. A bare token string can be refreshed
  once.
