-- docs/LEDGER_*.md WEB-100 (C4a): editing state of the route planner, read only by the edit page.
-- A replaced track takes its state with it (D3); a preview has its own column, which every
-- replacement of the track empties or rewrites. Purely additive: optional columns without a
-- default, ignored by the previous release (start-first rolling deploy).
alter table gpx_tracks add column planner_state jsonb;
alter table gpx_previews add column planner_state jsonb;
