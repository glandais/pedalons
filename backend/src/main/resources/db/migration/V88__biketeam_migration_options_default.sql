-- Biketeam migration: no more trial/final distinction and no more reset — every migration is
-- incremental (docs/LEDGER_*.md MIG-16). The application no longer writes these two columns, but
-- the previous release, which shares the database during a rolling deploy (and after a rollback),
-- still does: they stay, with a default for the rows the new release inserts. Dropping them is
-- docs/LEDGER_*.md MIG-17, in a later release.
alter table biketeam_migrations alter column dry_run set default true;
alter table biketeam_migrations alter column reset set default false;
