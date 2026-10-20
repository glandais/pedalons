-- docs/LEDGER_*.md WEB-100 (C3c): author waypoints. Purely additive for the start-first rolling
-- deploy: the previous release inserts imported waypoints without these columns (origin defaults to
-- IMPORTED, type stays null) and never reads them. A null type marks a row written before C3c or by
-- the previous release: WaypointBackfill types it INFO and places it on the track.
alter table gpx_waypoints add column type        varchar(16);
alter table gpx_waypoints add column description varchar(500);
alter table gpx_waypoints add column distance_m  double precision;
alter table gpx_waypoints add column origin      varchar(16) not null default 'IMPORTED';
create index gpx_waypoints_untyped on gpx_waypoints (route_id) where type is null;

-- A preview's typed waypoints, with the files_revision they describe: the `waypoints` column keeps
-- its (name, lat, lng) shape for the previous release, whose JSON reader fails on unknown fields.
alter table gpx_previews add column waypoint_details jsonb;
