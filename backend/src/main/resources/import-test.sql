-- Test profile runs with schema-management.strategy=drop-and-create and no Flyway, so database
-- objects Hibernate does not create must be declared here too. Mirrors V23__route_mvt_row_type.sql.
-- Hibernate splits this file on semicolons, so each statement must be a single semicolon-free
-- statement: no DO blocks, no dollar quoting. DROP first, since the type outlives drop-and-create.
DROP TYPE IF EXISTS route_mvt_row CASCADE;
CREATE TYPE route_mvt_row AS (geom geometry, slug text, name text, team_slug text, distance real, elevation_gain real);
-- Mirrors the partial unique index of V43__biketeam_live_migration.sql: one active job per biketeam
-- team. Hibernate cannot express a partial index, and the trigger's 409 relies on it.
CREATE UNIQUE INDEX uk_biketeam_migrations_active ON biketeam_migrations (biketeam_team_id) WHERE status IN ('QUEUED', 'RUNNING');
-- Mirrors V61__weather_cache.sql: the cell key is NULLS NOT DISTINCT (the departure cell has no
-- elevation band) and the forecast rows go with their cell. Hibernate can express neither.
CREATE UNIQUE INDEX uk_weather_cells_key ON weather_cells (lat_idx, lon_idx, ele_band) NULLS NOT DISTINCT;
ALTER TABLE weather_hourly ADD CONSTRAINT fk_weather_hourly_cell FOREIGN KEY (cell_id) REFERENCES weather_cells ON DELETE CASCADE;
ALTER TABLE weather_daily ADD CONSTRAINT fk_weather_daily_cell FOREIGN KEY (cell_id) REFERENCES weather_cells ON DELETE CASCADE;
-- Mirrors V71__gps_route_autosync.sql: one tracked manual upload per (connection, route), which the
-- manual upload's upsert relies on. Hibernate cannot express a partial index.
CREATE UNIQUE INDEX uk_gps_route_syncs_manual ON gps_route_syncs (connection_id, desired_route_id) WHERE ride_id IS NULL;
