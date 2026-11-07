-- Departure date, its zone and average speed of a GPX preview (docs/LEDGER_*.md API-149).
-- Purely additive and nullable: the previous release neither maps nor writes these columns.
alter table gpx_previews add column departure_at   timestamp(6) with time zone;
alter table gpx_previews add column departure_zone varchar(64);
alter table gpx_previews add column average_speed  float4;

-- Partial: almost no row has a date, and the weather planner reads them every 5 minutes.
create index idx_gpx_previews_departure_at on gpx_previews (departure_at)
  where departure_at is not null;
