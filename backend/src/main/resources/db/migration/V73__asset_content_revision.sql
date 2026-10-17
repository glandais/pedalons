-- Stable asset URLs (docs/LEDGER_*.md API-128): replacing a route's track or a thumbnail now keeps
-- the asset row and changes only its file_id (the storage key). content_revision is the GPS sync
-- signal for a replaced content: set to the new file_id when a track edit rewrites a GPX/FIT file,
-- null otherwise. Null keeps the fingerprint of existing rows (the asset id), so nothing is re-pushed.
alter table assets add column content_revision bigint;
