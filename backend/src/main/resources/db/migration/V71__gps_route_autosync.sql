-- docs/LEDGER_*.md API-120 : envoi automatique des parcours de mes sorties vers mes services GPS,
-- plan docs/plans/2026-10-16-gps-route-autosync.md. Purement additive : colonnes avec défaut ou
-- nullables et une table nouvelle, que la release précédente ignore (déploiement start-first).

alter table gps_service_connections
    -- l'opt-in, par connexion (D1) : faux par défaut, remis à faux par une connexion depuis zéro
    add column auto_sync boolean not null default false,
    -- posé sur un 401 persistant ou un 412 Garmin ; remis à null par la reconnexion
    add column sync_reconnect_required_at timestamp(6) with time zone,
    -- 429 : plus aucun appel de synchronisation pour cette connexion avant cet instant
    add column sync_paused_until timestamp(6) with time zone;

-- Une ligne par parcours que Pédalons a envoyé ou doit envoyer à un service, pour un utilisateur :
-- - ride_id non nul : gérée par l'envoi automatique, une ligne par (connexion, sortie) (D3) ;
-- - ride_id nul : un envoi manuel, enregistré pour être réutilisé, jamais mis à jour ni supprimé
--   d'office, une ligne par (connexion, route).
-- Elle porte l'état voulu (desired_*, écrit par le planificateur) et l'état synchronisé
-- (external_route_id, synced_*, écrit par le worker) ; le travail à faire est leur différence.
create table gps_route_syncs (
    id                 bigint                      not null primary key,
    domain_id          bigint                      not null references domains,
    user_id            bigint                      not null references users,
    -- la release précédente supprime la connexion sans connaître cette table : la cascade absorbe
    connection_id      bigint                      not null references gps_service_connections on delete cascade,
    -- sans FK : un groupe retiré d'une sortie est supprimé physiquement (orphanRemoval), une
    -- cascade effacerait l'identifiant externe et le parcours resterait pour toujours chez le service
    ride_id            bigint,
    ride_group_id      bigint,
    desired_route_id   bigint,
    desired_hash       varchar(64),
    desired_name       varchar(120),
    group_start_at     timestamp(6) with time zone,
    external_route_id  varchar(100),
    synced_hash        varchar(64),
    synced_at          timestamp(6) with time zone,
    attempts           integer                     not null default 0,
    next_attempt_at    timestamp(6) with time zone,
    -- le bail du worker (modèle V69__feedback_github_lease.sql)
    claimed_until      timestamp(6) with time zone,
    last_error         varchar(40),
    last_error_at      timestamp(6) with time zone,
    created_at         timestamp(6) with time zone not null,
    updated_at         timestamp(6) with time zone not null,
    constraint uk_gps_route_syncs_connection_ride unique (connection_id, ride_id),
    constraint ck_gps_route_syncs_last_error check (last_error in
        ('SERVICE_ERROR', 'UNAUTHORIZED', 'PERMISSION_REVOKED', 'RATE_LIMITED', 'NOT_CONFIGURED',
         'ROUTE_UNAVAILABLE'))
);

-- Un seul envoi manuel suivi par (connexion, route) : deux clics simultanés retombent sur la même
-- ligne (upsert on conflict). Miroir dans import-test.sql : Hibernate ne sait pas l'exprimer.
create unique index uk_gps_route_syncs_manual
    on gps_route_syncs (connection_id, desired_route_id) where ride_id is null;

-- Le travail en attente du worker.
create index idx_gps_route_syncs_pending
    on gps_route_syncs (domain_id, group_start_at)
    where ride_id is not null and desired_hash is distinct from synced_hash;

create index idx_gps_route_syncs_user on gps_route_syncs (user_id);
create index idx_gps_route_syncs_route on gps_route_syncs (desired_route_id);
