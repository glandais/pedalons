-- Fast elevation at save time, HD catch-up in the background (docs/LEDGER_*.md API-131, plan
-- docs/plans/archive/2026-10-17-altitude-hd-asynchrone.md).
--
-- elevation_refresh is the queue of tracks saved with the fast elevation source (Mapterhorn) that
-- ElevationRefreshWorker recomputes with IGN LiDAR HD after a quiet period. One row per target
-- (route or GPX-tool preview), removed with it by the cascade. source_revision is the token of the
-- track the request is about: the file_id of a route's original GPX, files_revision of a preview.
create table elevation_refresh (
  id                 bigint primary key,
  route_id           bigint references team_entities(id) on delete cascade,
  preview_id         bigint references gpx_previews(id)  on delete cascade,
  source_revision    bigint      not null,
  first_requested_at timestamptz not null,
  due_at             timestamptz not null,
  attempts           int         not null default 0,
  claimed_until      timestamptz,
  last_error         text,
  check ((route_id is null) <> (preview_id is null))
);
create unique index elevation_refresh_route   on elevation_refresh (route_id)   where route_id is not null;
create unique index elevation_refresh_preview on elevation_refresh (preview_id) where preview_id is not null;
create index elevation_refresh_due on elevation_refresh (due_at);

-- Where the stored profile stands: PENDING (fast profile, HD recomputation scheduled), HD, or FAST
-- (fast profile kept, the recomputation was given up). Null = computed before this column (pipeline
-- v2, IGN), i.e. HD: also what the previous release writes during a rolling deploy.
alter table team_entities add column elevation_state varchar(8);
alter table gpx_previews add column elevation_state varchar(8);
-- A preview's track files live under gpx-previews/{publicId}/{files_revision}/…; null = the flat
-- layout of existing previews (plan §4.6, lot 3).
alter table gpx_previews add column files_revision bigint;
