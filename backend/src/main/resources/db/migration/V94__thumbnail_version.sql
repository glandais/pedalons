-- docs/LEDGER_*.md OPS-71, API-223. Purely additive for the start-first rolling deploy: nullable
-- or defaulted columns, ignored by the previous release.
--
-- The version of MapThumbnailRenderer that drew the stored thumbnails of the entity (route, ride or
-- trip): both files, light and dark. Null = before this column, drawn by the previous release, or to
-- redraw.
alter table team_entities add column thumbnail_version smallint;
-- Failed redraws of the catch-up (ThumbnailBackfill): the tries so far, and when the next one may
-- come. After five the entity keeps its old thumbnail and leaves the catch-up.
alter table team_entities add column thumbnail_attempts smallint not null default 0;
alter table team_entities add column thumbnail_retry_at timestamptz;

-- What that catch-up looks for: entities behind the current drawing, most recent first. The 2 is
-- MapThumbnailRenderer.VERSION: a bump of it recreates this index in its migration.
create index team_entities_thumbnail_behind on team_entities (created_at desc, id desc)
  where deleted = false and (thumbnail_version is null or thumbnail_version < 2);
