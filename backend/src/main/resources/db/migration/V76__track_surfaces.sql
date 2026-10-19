-- docs/LEDGER_*.md WEB-100 (C1b): surface along a saved track, from Stadia Maps trace_attributes
-- (map_snap on the stored track), computed in the background after a quiet period like the HD
-- catch-up of V74. Purely additive: optional columns without a default and a new table, all
-- ignored by the previous release (start-first rolling deploy).
--
-- A route's surfaces live on its track rows: replacing the track replaces the rows and takes them
-- along. A preview's live in one document carrying the files_revision it describes, since the
-- previous release rewrites a preview's track without clearing this column.
alter table gpx_tracks add column surfaces jsonb;
alter table gpx_previews add column surfaces jsonb;

-- The queue, modelled on elevation_refresh: one row per target, removed with it by the cascade.
-- source_revision is the token of the track the request is about: the file_id of a route's
-- original GPX, files_revision of a preview.
create table surface_refresh (
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
create unique index surface_refresh_route   on surface_refresh (route_id)   where route_id is not null;
create unique index surface_refresh_preview on surface_refresh (preview_id) where preview_id is not null;
create index surface_refresh_due on surface_refresh (due_at);
