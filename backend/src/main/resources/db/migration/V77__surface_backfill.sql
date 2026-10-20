-- docs/LEDGER_*.md WEB-100 (C1c): the background catch-up of the tracks saved before the surface
-- existed (biketeam ones included). Purely additive for the start-first rolling deploy: the previous
-- release inserts without the column and gets the default (a normal request), and never reads it.
--
-- backfill marks a request the catch-up queued itself: the worker takes those only once every normal
-- request is served, and the catch-up spaces their due times to stay under its hourly cap. A save
-- turns it back into a normal request.
alter table surface_refresh add column backfill boolean not null default false;

-- What the catch-up looks for: the tracks without a surface. Partial, so it holds the backlog once
-- and then only the tracks saved in the last minutes, the given-up ones and those of deleted routes.
create index gpx_tracks_surface_missing on gpx_tracks (route_id) where surfaces is null;
