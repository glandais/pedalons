-- docs/LEDGER_*.md API-198 (lot 3, plan docs/plans/2026-11-13-generateur-boucles-equipe-lot3.md §4):
-- "Ne pas utiliser pour générer des parcours" (plan §10.8). Routes live in the single table
-- team_entities, so every entity type gets the column, false for all but the routes that tick it.
-- Purely additive for the start-first rolling deploy: a constant default is metadata only on
-- PostgreSQL 11+, the previous release's inserts get false, and its updates do not list the column,
-- so they leave it as it is.
alter table team_entities
  add column excluded_from_generator boolean not null default false;
