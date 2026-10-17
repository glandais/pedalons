# Pédalons Roadmap

This is the **product** roadmap. The engineering follow-ups from the July 2026 v2 — API gaps that
each remove a named degradation, the three uncommitted infrastructure workstreams (push has shipped), and the live-app
test checklist — are in [LEDGER_NEXT.md](LEDGER_NEXT.md). Two entries below overlap with it and are
noted where they appear.

## P0 — Launch Blockers
Must-have for public launch. Focus on first impressions and core UX.

### UX Polish
- [X] Responsive website — Mobile-first is non-negotiable for cyclists
  - [ ] Still issues
- [X] Dark mode — Expected by modern users
- [X] Appealing cards (icons, route previews)
  - [ ] Still some polish to do ...
- [X] Pagination — Performance at scale
  - Offset pagination everywhere; infinite scroll on mobile only, deliberately not on the web, and
    cursor pagination still to do — see ledger `API-21` and `WEB-8`

### Discoverability
- [x] SEO/robots.txt — Phase 1 complete (static meta); `robots.txt` realigned on
      `contracts/routes.yaml` on 2026-09-29 (both locales, no route that no longer exists)
  - [x] llms.txt — `/llms.txt` per host, public teams and a pointer to the sitemap (ledger `WEB-34`)
- [X] SSR/Dynamic meta — shipped without Next.js: Express server-side rendering of the React app
      (`frontend/docs/SSR.md`) and per-page Open Graph/Twitter tags (`frontend/docs/LINK_PREVIEW.md`)
- [x] Dynamic sitemap.xml — `/sitemap.xml` per host, public content of public teams, no ads,
      no routes, no map pages (ledger `WEB-31`)
- [x] Share URL (Social) — Viral loop — share button on the web detail pages and team header
      (ledger `WEB-30`); the mobile app already shared links

### Core Features (In Progress)
- [X] Slug changes with redirects

---

## P1 — Post-Launch (Month 1-2)
Drive engagement and reduce friction for organizers.

### Organizer Productivity
- [X] Multi-GPX upload (one route per file) — Huge time saver
- [X] Team location (init route planner) — Better defaults
- [X] Card CTAs (modify, publish, delete, add to calendar) — ledger `WEB-33`
- [x] Team dashboard (drafts count, what's next, activity feed) — ledger `API-79`, `WEB-63`,
      `MOB-53`; the "latest content" blocks stand in for an activity feed

### Member Engagement
- [X] Calendar view (rides, trips) + sync URL export
- [X] User unit system toggle (metric/imperial) — Respect preferences
- [X] Ride/trip "Terminated" status — Clarity on past events
  - The server says it: a computed `finished` boolean on rides, trips and calendar events, next to
    `Status` rather than in it (a past cancelled ride is both). See ledger `API-16`

### Content System
- [x] Markdown image improvements:
  - [X] Use image asset endpoint in display
  - [X] Allow any image format (heic, ...)
  - [x] Drag/drop image support — drop or paste into the editor (ledger `WEB-32`)
- [x] Tags on Ride, Post, Trip, Route, Ad — Filtering/discovery (one tag set per type) — delivered
  2026-10-01, API 10.1.0: team vocabulary per type, `?tags=` filter on team lists, web tagging and
  admin, mobile display and filter (ledger `API-59`, `WEB-40`, `MOB-39`)

---

## P2 — Growth Phase (Month 3+)
Features that differentiate and deepen engagement.

### Discovery & Search
- [ ] Global full-text search (priority: my teams → public) — ledger `API-19`
- [ ] All trips view with search filters
- [ ] User favorite routes + dedicated tab

### Route Features
- [ ] Route basket (collect routes, display on single map)
- [ ] Team/global route heatmap
- [x] Router profile selection — six routing profiles in the web planner (`RouterProfileSelector`;
      Valhalla costings, computed by Stadia Maps since October 2026, `OPS-48`)
- [ ] Custom cycling map style (Maplibre) — CyclOSM (third-party raster) is among the base maps
      in the meantime

### Visibility Controls
- [x] PUBLIC_UNLISTED visibility — Shareable but not indexed
  - The enum value exists, both editors offer it, and both clients badge it orange. The "not
    indexed" half shipped with ledger `WEB-4`: the SSR head carries a per-page
    `<meta name="robots" content="noindex">` for unlisted content and for every page of an
    unlisted team, and `frontend/index.html` no longer ships a static robots tag.

### Trip Enhancements
Stored trip stats were ruled out: the totals are computed on read (ledger `API-93`).
- [ ] Trip stage alternative routes
- [x] Trip view redesign — mobile v2 (screen 24) and the web port
- [ ] Trip progress indicator inside the trip view (current stage, "stage 3/7") — today only the
      agenda and card badges say a trip is under way

---

## P3 — Platform Scale
Requires significant architecture work. Spike before committing.

### Notifications
- [x] Versatile notification system
  - **Phases 1 to 5 in production since 2026-09-21** — design in
    docs/plans/archive/2026-09-18-notifications.md, what shipped in ledger `NOTIF-9`
  - Event types, team/user preferences, in-app inbox, team webhook, daily digest
  - Mobile push: **live in production since 2026-09-21** (FCM, Android + iOS)
  - Web push: **live in production since 2026-09-29** (installable site, same FCM, platform `WEB`)
  - E-mail channel: built, **off in production** by product decision (2026-09-21)
  - What's left is ledger `NOTIF-1` to `NOTIF-4`

### Administration
- [X] System admin panel
  - Manage all users/teams
  - Promote/demote admins
  - Recover deleted items
  - [ ] Configure legal pages
  - [ ] Manage system images

### Multi-Tenancy
- [X] Team custom domains
  - [X] User linked to a domain
  - [X] SQL-level domain filtering
  - [X] Domain alias pinned to a team (V20, `AdminDomainAliasService`): a platform admin serves one
        team on its own hostname

---

## Icebox — Needs Discovery
Validated interest required before prioritization.

### Device Integrations
- [X] Garmin Connect upload (one-click route sync)
- [X] Hammerhead Karoo upload
- [X] Wahoo Cloud upload (cloud-only — no companion app, the ELEMNT syncs from the account)
- [X] Garmin GPS (iq store) app (route download for current ride)
- [X] Karoo app (route download)
- [X] Weather for rides (October 2026, API 10.9.0) — Open-Meteo forecast on the ride page, the
      cards and the mobile "route weather" screen: departure, checkpoints, wind along the route,
      rain alert. Ledger `API-74`, `WEB-60`, `MOB-51`
- [X] Weather for trips (October 2026, API 10.11.0) — one forecast per stage, on the stage page and
      the stage cards. Ledger `API-76`, `WEB-67`, `MOB-57`
- [X] Weather for trips on list cards (October 2026, API 10.13.0) — the next stage's forecast on
      the trip cards. Ledger `API-82`
- [ ] Weather on Karoo/Garmin — ledger `API-77`

### Mobile
- [X] Mobile application (iOS/Android) — Flutter app with auth, teams, rides, routes, calendar
- [X] Mobile v2 (July 2026) — `core/pdl` design system, five-tab shell, light/dark, metric/imperial,
      twelve reworked screens. Consultation and participation only: creating and editing content
      stays out of scope

### Other
- [ ] Dedicated mobile/Garmin/Karoo app for a team with its own domain (one store listing per
      customer — the web side is covered by domain aliases)
- [ ] User dedicated team (personal workspace)
- [x] Places improvements — server-side search and pagination (picker and admin list); no more
      50-item cap

---

## Tech Debt / Hygiene
Run alongside feature work.

- [X] Schedule orphan asset deletion (>24h without entity) — `AssetCleanupScheduler`, daily
- [x] Markdown asset reference cleanup — `AssetService.updateAssets` keeps only the images a
      `::asset{…}` directive still references; orphan removal deletes the rest with their S3 files
