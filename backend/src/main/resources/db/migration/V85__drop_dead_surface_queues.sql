-- docs/LEDGER_*.md API-151 (phase F, step 2, plan docs/plans/2026-11-05-osm-route-details.md): the
-- two queues no release reads any more. surface_refresh fed osm-surface until phase E;
-- raw_track_resurface marked the routes the raw line catch-up gave a denser line, read by nothing
-- since API-150 phase D. Their entities left in API-155, one release before this one, so the
-- previous release of the start-first rolling deploy does not see them go. A release up to phase E
-- (a8eda50d) maps surface_refresh and would no longer start: no rollback below API-155.
drop table surface_refresh;
drop table raw_track_resurface;
