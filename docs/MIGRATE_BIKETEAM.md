# Biketeam → Pédalons migration

> A biketeam team admin moves *their* team from biketeam's admin, server to server over HTTPS,
> without people: the [live migration](#live-migration), then the [mapping rules](#mapping-rules) it
> applies. Design and contract with biketeam:
> [plans/2026-09-22-biketeam-live-migration.md](plans/2026-09-22-biketeam-live-migration.md).

# Live migration

A biketeam team admin opens *Migrer vers Pédalons* in their team's biketeam admin, chooses a **trial**
(`dryRun`, ticked by default) or the real thing, and optionally a **reset**. Biketeam sends the browser
to `/migration-biketeam?request=<signed token>` here; the admin signs in (or signs up) on Pédalons,
reads what will be imported and confirms. Pédalons mints a single-use grant and sends the browser
back to biketeam, which redeems it over HTTPS (`POST /api/internal/biketeam-migration/jobs`) and
polls the job. The worker fetches the team's snapshot and files from biketeam's export API
(`/internal/pedalons/…`), maps them with the rules below, and hands biketeam a URL table. A
successful non-trial run, once the admin clicks *Basculer vers Pédalons*, makes biketeam redirect
every URL of the team here — with a 302 by default, a 301 once `PEDALONS_REDIRECT_STATUS=301` is set
on biketeam after the switches have settled (ledger `MIG-2`) — and turn the team read-only; nothing is deleted on
either side.

What comes over: the team (name, visibility, `joinable`), its about page (presentation + contact
details), its FAQ page, its logo (not the placeholder), places, routes with their GPX and
their tags, ride templates (with their numbering: biketeam's `increment` becomes `nextNumber`), publications (as posts), rides with their groups, trips with their stages, and their
images. What does **not**: users, memberships, participations, comments, registrations, route
ratings and favourites. The Pédalons account that confirmed becomes the team's **ADMIN** and the
author (`createdBy`) of everything; members join afterwards through the usual invitation link or,
for a `joinable` team, on their own. Ride groups have no leader (`RideGroupDto.leader` is null).
A new team also starts with the route planner on, admins allowed to add members, and its
visibility editable (`enableRoutePlanner`, `addMemberAllowed`, `visibilityEditable`); a replay
leaves these settings alone.

The team lands in the domain the admin confirmed on (its parent domain, if they came through an
alias), at the slug derived from the biketeam team id (`BiketeamTargetResolver.targetSlug`: every
run of `_`, `.`, `-` becomes one `-`, so `mollet_qui_pique` lands at `mollet-qui-pique`; two ids
that collapse to the same slug meet a `BIKETEAM_SLUG_CONFLICT`). The biketeam id stays the mapping
key.

| Situation at the slug | Trial / real run | With `reset` |
|---|---|---|
| free | team created | same |
| a team migrated earlier from this biketeam team | updated in place (replay) — only by its Pédalons ADMIN or a PLATFORM_ADMIN | trashed (`deleted`, slug renamed `<slug>-reset-<jobId>`) then created anew — refused while a domain alias is pinned on it |
| that team, already in the trash | trashed team set aside, created anew | same |
| any other team (a native Pédalons team) | **refused** (`BIKETEAM_SLUG_CONFLICT`), never touched | same |
| this biketeam team was migrated into another domain of this database | **refused** (`BIKETEAM_MIGRATED_IN_OTHER_DOMAIN`) | same |

A **trial** is a real migration — the team really exists afterwards, visible according to its
biketeam visibility — that biketeam simply does not switch over to. Replays are idempotent (see
[Replaying](#replaying)), so the real run after a trial re-creates nothing: it resynchronises what
changed on biketeam meanwhile, and skips the whole GPX pipeline — without even downloading — for
every route whose file has the same `size:md5` fingerprint.

## Turning it on

Off until **all five** variables are set in the backend's `.env` (documented, empty, in
`.env.example`); only some of them stops the backend at startup, naming the missing ones.

| Variable | Value |
|---|---|
| `PEDALONS_BIKETEAM_REQUEST_KEY` | `openssl rand -base64 32` — same value as biketeam's `PEDALONS_REQUEST_KEY` |
| `PEDALONS_BIKETEAM_TRIGGER_SECRET` | `openssl rand -base64 32` — same as biketeam's `PEDALONS_TRIGGER_SECRET` |
| `PEDALONS_BIKETEAM_EXPORT_URL` | biketeam's public URL, **HTTPS mandatory**, e.g. `https://www.prendslaroue.fr` |
| `PEDALONS_BIKETEAM_EXPORT_SECRET` | `openssl rand -base64 32` — same as biketeam's `PEDALONS_EXPORT_SECRET` |
| `PEDALONS_BIKETEAM_PUBLIC_URL` | biketeam's public `site.url`, e.g. `https://www.prendslaroue.fr` |

Order, on a new deployment:

1. Deploy Pédalons, then biketeam, both without any of these variables: nothing changes.
2. Secrets on both sides, restart both. There is no VPN: each side calls the other through its
   normal public HTTPS entry point — Pédalons' `/api/internal/` and biketeam's `/internal/pedalons/`
   are reachable from the Internet, guarded by the shared secrets, the single-use grant, and (for the
   export) a migration in flight for that team. Both URLs must be `https://`.
3. The backend log says
   `Biketeam live migration enabled (export …, public site …)`.
4. A trial of a small team (`gaby`) against **staging**, then against production, then the real run
   (production rollout tracked as ledger `MIG-1`).

`pedalons.biketeam.grant-ttl` (10 min), `.max-attempts` (3), `.stuck-after` (20 min),
`.export-snapshot-timeout` (5 min for the snapshot's headers — biketeam may hash a big team's files
first), `.export-idle-timeout` (60 s without a byte of a snapshot or file) and
`.export-transfer-timeout` (10 min for one snapshot or file) have defaults in
`application.properties`; startup fails if `stuck-after` does not exceed the longest silence they
allow.

## Following a job

Everything is in `biketeam_migrations` — one row per confirmed request, first a grant (`GRANTED`,
`EXPIRED`), then a job (`QUEUED`, `RUNNING`, `SUCCEEDED`, `FAILED`). Biketeam shows the same
status on its admin page; the backend logs one line per transition.

```sql
select id, biketeam_team_id, dry_run, reset, status, attempts, progress, error_code, error_message,
       queued_at, started_at, finished_at
from biketeam_migrations order by created_at desc limit 20;

-- counts and warnings of the latest job of a team
select result -> 'counts', result -> 'warnings'
from biketeam_migrations where biketeam_team_id = 'n-peloton' order by created_at desc limit 1;
```

One job at a time per instance (the worker ticks every 10 s), one active job per biketeam team. A
network or 5xx failure of the export is retried after 2, then 4 minutes; a job silent for
`stuck-after` (a killed backend) is started over — the replay is cheap. Grants never redeemed become
`EXPIRED` within the hour. No row is ever deleted.

| `error_code` | Meaning |
|---|---|
| `BIKETEAM_SLUG_CONFLICT` | A native Pédalons team holds the slug: rename it on Pédalons, then retry from biketeam. |
| `BIKETEAM_MIGRATED_IN_OTHER_DOMAIN` | This biketeam team already lives in another domain of this database. |
| `BIKETEAM_NOT_TEAM_ADMIN` | The confirming account does not administer the existing team (any more). |
| `BIKETEAM_RESET_BLOCKED` | A domain alias is pinned on the team a reset would trash. |
| `EXPORT_REFUSED` | Biketeam answered 4xx — wrong `PEDALONS_BIKETEAM_EXPORT_SECRET`, or no migration in flight on its side. |
| `EXPORT_UNAVAILABLE` | Biketeam unreachable or 5xx after every attempt — check `PEDALONS_BIKETEAM_EXPORT_URL` and that biketeam answers on it. |
| `EXPORT_INVALID` | Unreadable snapshot, unexpected `schemaVersion`, or the snapshot of another team. |
| `WORKER_LOST` | No heartbeat, and no attempt left. |
| `INTERNAL_ERROR` | Anything else — the backend log has the stack trace. |

A job that `SUCCEEDED` may still count per-element failures (`counts.*.failed`, with a warning each:
`GPX_MISSING`, `GPX_EMPTY`, `GPX_FAILURE`, `FILE_DOWNLOAD_FAILED`, `IMAGE_FAILED`, `ITEM_FAILED`;
see [Known failures](#known-failures)). Read them after the trial; whether to go on is a human call.
One warning is not a failure: `TRIP_STAGES_OUTSIDE_DATES` flags a trip whose stages fall outside its
biketeam start/end dates — migrated as is, but Pédalons ends a trip with its last stage, so its
biketeam end date is lost. Fix the dates on either side.
Neither is `TAGS_TRUNCATED`: a route's free-form biketeam tags become `ROUTE` tags of the team
(found by label case-insensitively, else created gray with the first spelling met; ledger `MIG-14`),
and the warning names a label cut to 32 characters or tags dropped beyond 10 on the route or 100 in
the team — the route keeps the first ones. `defaultSearchTags` is not migrated.

## Both applications on a workstation

Pédalons as usual (`mvn quarkus:dev` on 8080, `pnpm dev` on 5173), biketeam on **8081**
(`SERVER_PORT=8081`). In dev, plain `http://localhost` URLs are fine.

```bash
# Pédalons backend, on top of `source scripts/dev-env.sh`
export PEDALONS_BIKETEAM_REQUEST_KEY=…   PEDALONS_BIKETEAM_TRIGGER_SECRET=…   PEDALONS_BIKETEAM_EXPORT_SECRET=…
export PEDALONS_BIKETEAM_EXPORT_URL=http://localhost:8081
export PEDALONS_BIKETEAM_PUBLIC_URL=http://localhost:8081   # = biketeam's SITE_URL
# biketeam: PEDALONS_URL=http://localhost:5173, PEDALONS_INTERNAL_URL=http://localhost:8080, same three secrets
```

## Tests

Not run by the assistant (see CLAUDE.md): run them yourself.

```bash
cd backend
mvn test -Dtest='Biketeam*Test'
```

# Mapping rules

## Replaying

Re-running is safe and cheap. Already-migrated rows are matched through the biketeam→tribly id
mapping table (`biketeam_migration_map`, tagged with `biketeam_team_id`), so a replay repairs what a
previous run left missing rather than duplicating it.

Most of a run is the GPX pipeline: parse, SRTM elevation, Douglas-Peucker, FIT, two thumbnails, five
S3 uploads. `biketeam_migration_map` therefore records the size and MD5 of the `.gpx` each route was
built from — the snapshot announces both, and a downloaded file that does not match is rejected — and
a replay whose file carries the same fingerprint skips the pipeline entirely, refreshing only the
name, surface and visibility. The fingerprint is written *after* the pipeline succeeds, so a run
killed mid-upload leaves none and the next one redoes the work.

What remains is the ride and trip thumbnails, which `updateRide`/`updateTrip` regenerate
unconditionally (ledger `MIG-4`). A route whose `.gpx` changed between two runs is reprocessed, as it should be.

## Known failures

Two defects of biketeam's own data lose routes, and cannot be fixed on this side:

| Warning | Cause |
|---|---|
| `GPX_MISSING` / `GPX_EMPTY` | The `map` row points at a `.gpx` file biketeam no longer has, or at one without a track. |
| `GPX_FAILURE` | Emoji in the track/waypoint name, written by biketeam as two separate UTF-16 surrogate character references (`&#55357;&#56629;`), which is not valid XML. |

The route is skipped and the rest of the team goes on; a ride or trip stage that referenced it loses
its route.

## Ordering of groups and stages

Biketeam stores no order: it sorts in Java, at render time. The export hands the lists over already
sorted by those comparators, so tribly's `sortOrder` — the index in the request list — matches what
biketeam displayed.

| Read by the migration | Biketeam's comparator | Shown by |
|---|---|---|
| `ride_group` | `Ride.getSortedGroups()` — meeting time, then name | `ride.ftlh` |
| `trip_stage` | `Trip.getSortedStages()` — date, then name | `trip.ftlh` |
| `ride_group_template` | `RideTemplate.getSortedGroups()` — **name alone**, no time | admin form |

Nothing sorts in `RideService`/`TripService`: there, `sortOrder` is the order a human dragged them
into.

## Visibility

Tribly gates content on two fields at once (`TeamEntityRepository.getPublicEntity`): a cross-team
listing needs `team.visibility = 'PUBLIC'` **and** `te.visibility = 'PUBLIC'`; the team's own pages
list it as soon as the team is not `TEAM` (so a `PUBLIC_UNLISTED` team shows its `PUBLIC` items
there); a direct link needs both to be
anything other than `TEAM`.

Biketeam's only per-item flag is `ride.listed_in_feed` / `trip.listed_in_feed`, which hides an item
from the team feed while a direct link still opens it — exactly `PUBLIC_UNLISTED`. Routes, posts
and ride templates have no such flag and are always listed, so they map to `PUBLIC`.

Item visibility comes from the item's own flag, never from the team's unlisted-ness. Pushing the
team's `PUBLIC_UNLISTED` down onto its content would empty the team's own feed today (team-scoped listings still require
`te.visibility = 'PUBLIC'`), and would stick:
promoting that team to `PUBLIC` later would leave its whole feed hidden. A `TEAM` team clamps
everything under it to `TEAM`, which `validateVisibility` requires anyway.

| biketeam `team.visibility` | tribly |
|---|---|
| `PUBLIC` | `PUBLIC` |
| `PUBLIC_UNLISTED` | `PUBLIC_UNLISTED` |
| `USER` (personal space) | `PUBLIC_UNLISTED` |
| `PRIVATE` | `TEAM` |
| `PRIVATE_UNLISTED` | `TEAM` |

Both PRIVATE flavours mean "members only", which is `TEAM`; tribly has no unlisted-and-private,
so that distinction is dropped. `USER` marks a personal training space that biketeam never lists,
yet `Team.isPublic()` returns true for it, so anyone with the link can read it — `PUBLIC_UNLISTED`
is the faithful translation. An unknown value maps to `TEAM`, the most restrictive.

`Team.joinable` follows: biketeam puts `/join` behind `authorizePublicAccess`, so a `TEAM` team
cannot be self-joined.

## Dates

`BaseEntity.createdAt` is a `@CreationTimestamp` mapped `updatable = false`: Hibernate stamps it on
insert and never writes it again, so the migration restores the biketeam date with a plain SQL
update right after each insert.

| tribly | biketeam source |
|---|---|
| `Team.createdAt` (and its about page, and its FAQ page) | `team.created_at` (a date → midnight in the team's zone) |
| `Route.createdAt` and `dateTime` | `map.posted_at` (a date; biketeam has no finer timestamp) |
| `Ride` / `Trip` / `Post` `.createdAt` | their `published_at` |
| `Ride.dateTime` | `ride.date` + earliest group meeting time |
| `Trip.dateTime` | `trip.start_date` + `meeting_time` |
| `TripStage.dateTime` | `trip_stage.date` + **an invented time** — see below |
| `Post.dateTime` | `publication.published_at` |

Places carry no date in biketeam, so theirs is the migration time.

### Trip stage departures

`trip_stage` holds a bare `date` and no time at all — a biketeam trip's only time is
`trip.meeting_time`, the rendezvous of the whole trip. Tribly's `TripStage.dateTime` is an `Instant`
that `TripStageCard` and `StageDetailPage` both render down to the minute, so leaving it at the
day's start would print "à 00:00" on every migrated stage.

The **first** stage therefore takes `trip.meeting_time`, which is precisely what that column meant,
and the **later** ones get **8:00** — a convention for a departure on the road, not a claim about
the source, which says nothing on the subject. Stages arrive sorted by biketeam's own comparator
(date, then name), so index 0 really is the first day.

### Timezones

Biketeam stored time-of-day as `time without time zone` (`ride_group.meeting_time`,
`trip.meeting_time`) and business dates as bare `date`, resolving both against
`team_configuration.timezone` at render time (`Team.getZoneId()`). The export carries that zone,
and every bare date and time of the team is read in it (falling back to `Europe/Paris` if it is
missing or unreadable).

Only the `published_at` columns (`ride`, `trip`, `publication`) are true instants,
stored `timestamp with time zone`; those need no zone and are copied straight across.

## Team pages

Biketeam had exactly two pieces of free-form team prose, and tribly's `TeamPage` takes both:

| biketeam | tribly |
|---|---|
| `team_description` (presentation + contact details) | the team's **about** page, rendered to markdown |
| `team_configuration.markdown_page` | an **additional** page titled *FAQ* |

`markdown_page` is what biketeam's `FAQController` served at `/{teamId}/faq`, under that fixed
title — the schema has no other page table and no per-page title, so *FAQ* is the whole of it. Few
teams have one (`n-peloton`, for instance); the others get no additional page.

The column already holds Markdown, so it is copied across as-is — only CRLF is normalised, with
none of the hard-break rewriting `team_description` needs. It lands at
`/equipes/{team}/pages/faq`, published, at the team's own visibility, dated to the team's creation
like the about page.

Written through `TeamPageRepository` rather than `TeamPageService.createPage`: that path enforces a
three-additional-pages cap. Biketeam can never supply more than one, but the cap counts pages an
earlier run already created. Replays match on the `TEAM_PAGE` mapping keyed `<teamId>:faq` — the
bare `<teamId>` is the about page — and refresh the markdown in place.

**Internal links are not rewritten.** `n-peloton`'s page links to
`https://www.prendslaroue.fr/n-peloton/faq#equipement` and to its old home page; those stay pointing
at biketeam and have to be fixed by hand, or by the team, once the old site goes away
(ledger `MIG-3`).

### Trip notes

A trip had its own free-form page too — `trip.markdown_page`, served at `/{team}/trips/{id}/notes`.
Tribly has no per-trip page, so it becomes the tail of the trip's description, under a `## Notes`
heading. Like the FAQ it is already Markdown: only CRLF is normalised. The description is rebuilt
from the source on every run, so a replay never stacks a second section.

## Team logos

Biketeam kept the team logo at `misc/<teamId>/logo.png|jpg`. Tribly has no logo column: `TeamAvatar`
reads `team.about.assets.logo`, so the file is imported as a `LOGO` asset on the team's about page.
No `::asset{}` directive is added — a logo is addressed through `assets.logo`, not from the markdown.

Biketeam handed every new team a copy of its `default-images/empty.png` placeholder, so the file
being present means nothing: **many teams never replaced it**. The snapshot's logo is skipped when
its MD5 is the placeholder's (`PLACEHOLDER_LOGO_MD5`), which leaves tribly's initials avatar in
place.
