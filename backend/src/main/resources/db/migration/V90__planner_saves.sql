-- The route planner quotas (docs/LEDGER_*.md BILL-10).
--
-- planner_saves is a journal, one row per save of a track drawn in the planner: a team's quota is
-- its rows since the first day of the month in the team's zone, a user's personal quota (the GPX
-- tools, team_id null) theirs since the first day of the month in UTC. No foreign key to the route
-- or the preview: deleting what was drawn does not give the save back, or create-delete-create
-- would go round the quota. target_id only helps a diagnosis. Rows older than 13 months are purged
-- every night (PlannerQuotaCleanupScheduler).
--
-- router_daily_calls bounds the route calculations of one user per UTC day, whatever the tier: one
-- row per user and day, incremented by an upsert, so concurrent backends share the count. Rows of
-- past days are purged with the journal.
--
-- Two new tables the previous release never reads: safe for a rolling deploy. Its saves during the
-- minute both run are not counted, which costs nothing.
create table planner_saves
(
    id        bigint      not null primary key,
    domain_id bigint      not null references domains (id),
    user_id   bigint      not null references users (id),
    team_id   bigint references teams (id),
    saved_at  timestamptz not null,
    target_id bigint
);

create index idx_planner_saves_team on planner_saves (team_id, saved_at) where team_id is not null;
create index idx_planner_saves_user on planner_saves (user_id, saved_at) where team_id is null;
create index idx_planner_saves_saved_at on planner_saves (saved_at);

create table router_daily_calls
(
    id      bigint  not null primary key,
    user_id bigint  not null references users (id),
    day     date    not null,
    calls   integer not null,
    constraint uk_router_daily_calls_user_day unique (user_id, day)
);

create index idx_router_daily_calls_day on router_daily_calls (day);
