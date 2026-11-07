-- docs/LEDGER_*.md API-150 (phase C, plan docs/plans/2026-11-05-osm-route-details.md §7). Purely
-- additive for the start-first rolling deploy: nullable columns and a defaulted one, ignored by the
-- previous release, which inserts into elevation_refresh without the column and gets a normal
-- request. surface_refresh is kept: the previous release still drains it.
--
-- The version of GpxPipeline that computed the stored HD profile. Null = before this column,
-- written by the previous release, or a FAST save the catch-up has not replaced: to recompute.
alter table team_entities add column elevation_pipeline smallint;
alter table gpx_previews add column elevation_pipeline smallint;

-- A request queued by the catch-up of the whole fleet (phase D), not by a save.
alter table elevation_refresh add column backfill boolean not null default false;

-- What that catch-up looks for: routes behind the current pipeline, most recent first. The 3 is
-- GpxPipeline.VERSION: a bump of it recreates this index in its migration.
create index team_entities_pipeline_behind on team_entities (created_at desc, id desc)
  where entity_type = 2 and deleted = false and (elevation_pipeline is null or elevation_pipeline < 3);
create index elevation_refresh_backfill on elevation_refresh (due_at) where backfill;
