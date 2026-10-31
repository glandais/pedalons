-- docs/LEDGER_*.md API-147 (phase D): the background catch-up of the raw line of the tracks saved
-- before V81 (biketeam ones included), read again from each route's original.gpx. Purely additive
-- for the start-first rolling deploy: a new table and an index, both ignored by the previous
-- release.
--
-- The routes the catch-up gave up on (original missing or unreadable, a number of tracks that does
-- not match the stored ones): one row each, so a pass never picks them again. Removed with the
-- route by the cascade. Deleting a row makes the route a candidate again.
create table raw_track_backfill_skip (
  route_id   bigint primary key references team_entities(id) on delete cascade,
  reason     text        not null,
  skipped_at timestamptz not null
);

-- What the catch-up looks for: the tracks without a raw line. Partial, so it holds the backlog once
-- and then only the given-up routes (every save writes the line), like gpx_tracks_surface_missing.
create index gpx_tracks_raw_missing on gpx_tracks (route_id) where raw_geometry is null;

-- The routes the catch-up gave a raw line denser than their stored points (at least 1.5 times as
-- many points), so whose surface, computed on those points, is worth asking again. Written whatever
-- pedalons.raw-backfill.resurface says, so that switching it on later still finds them: the surface
-- catch-up (SurfaceBackfill) queues them under its cap and window while it is on, and deletes the
-- row once it has. source_revision is the original's file_id the line was read from: a row whose
-- route has another original since (a save, which writes the line and asks the surface itself) is
-- obsolete.
create table raw_track_resurface (
  route_id        bigint primary key references team_entities(id) on delete cascade,
  source_revision bigint      not null,
  wanted_at       timestamptz not null
);
