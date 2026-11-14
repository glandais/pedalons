-- docs/LEDGER_*.md API-198 (lot 1, plan docs/plans/2026-11-13-generateur-boucles-equipe-lot1.md):
-- the street edges osm-route-details matched for a team route's track. Purely additive for the
-- start-first rolling deploy: the previous release neither reads nor writes the column, and the
-- track rows it inserts start with null, which the HD catch-up of their save fills.
alter table gpx_tracks add column network_edges jsonb;

-- What the backfill looks for: tracks without a document, or with one older than
-- NetworkEdgesDocument.VERSION. The 1 is that version, inlined (a partial index predicate cannot
-- take a parameter): a bump of it recreates this index in its migration.
create index gpx_tracks_network_edges_behind on gpx_tracks (route_id)
  where network_edges is null or (network_edges->>'v')::int < 1;
