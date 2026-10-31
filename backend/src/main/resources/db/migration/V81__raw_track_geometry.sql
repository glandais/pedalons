-- docs/LEDGER_*.md API-147 (phase A): every track keeps its geometry as its source produced it —
-- 2D, never resampled nor simplified — beside the processed one, for the surfaces to snap to OSM on
-- it rather than on a vertex every 90 m. Purely additive: nullable columns without a default, so
-- no table rewrite, ignored by the previous release (start-first rolling deploy).
--
-- Null means "not known" (a row written before this release, or by the previous one during the
-- deploy): readers fall back on track_points. No spatial index: no spatial query reads it.
alter table gpx_tracks add column raw_geometry geometry(LineString, 4326);

-- A preview's raw lines (polyline6, one per track) live in a document of their own carrying the
-- files_revision they describe, not in the tracks column: the previous release reads tracks with a
-- JSON reader that fails on unknown properties, and rewrites a preview's track without clearing
-- this column.
alter table gpx_previews add column raw_lines jsonb;
