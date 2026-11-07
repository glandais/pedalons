-- The start a notification gives its recipient, when it is not the event's (docs/LEDGER_*.md
-- NOTIF-13): a registered rider whose group leaves at its own time is reminded of, told of the
-- cancellation or of the change of, that group's start — not the ride's.
--
-- Nullable, no default, no backfill: the previous release, still running for the minute of a
-- start-first deploy, does not map the column and leaves it null on what it fans out, as on every
-- row before it. Readers then fall back on the event's subject_date_time, the ride's date.
ALTER TABLE notifications ADD COLUMN subject_date_time timestamp(6) with time zone;
