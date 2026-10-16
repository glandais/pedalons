package fr.pedalons.repository.gps;

import fr.pedalons.domain.gps.GpsRouteSync;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.GpsSyncError;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.LockModeType;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

/**
 * The tracking rows of the routes sent to GPS services (docs/LEDGER_*.md API-120). Every write is
 * a native upsert or a conditional bulk update: the planner writes only the desired columns, the
 * worker only the synchronised ones and only under its lease, so neither ever overwrites the other.
 */
@ApplicationScoped
public class GpsRouteSyncRepository implements PanacheRepository<GpsRouteSync> {

  // ------------------------------------------------------------------ planner

  /** An automatic row as the planner compares it with the desired state. */
  public record AutoRow(
      Long id,
      Long connectionId,
      Long rideId,
      @Nullable Long rideGroupId,
      @Nullable Long desiredRouteId,
      @Nullable String desiredHash,
      @Nullable String desiredName,
      @Nullable Instant groupStartAt,
      boolean reconnectRequired) {}

  /**
   * The domains the planner has something to do on: those with a connection that asked for the
   * sync, and those with automatic rows left (a sync turned off still has routes to remove). Across
   * domains by nature — it is what decides which domain to look at.
   */
  public List<Long> findDomainsToPlan() {
    @SuppressWarnings("unchecked")
    List<Number> ids =
        getEntityManager()
            .createNativeQuery(
                """
                select u.domain_id from gps_service_connections c
                  join users u on u.id = c.user_id
                  where c.auto_sync = true
                union
                select s.domain_id from gps_route_syncs s where s.ride_id is not null
                """)
            .getResultList();
    return ids.stream().map(Number::longValue).toList();
  }

  /** Every automatic row of the domain, in one query. */
  public List<AutoRow> findAutoRows(Long domainId) {
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select s.id, c.id, s.rideId, s.rideGroupId, s.desiredRouteId, s.desiredHash,"
                    + " s.desiredName, s.groupStartAt, c.syncReconnectRequiredAt"
                    + " from GpsRouteSync s join s.connection c"
                    + " where s.domainId = :domainId and s.rideId is not null",
                Object[].class)
            .setParameter("domainId", domainId)
            .getResultList();
    List<AutoRow> result = new ArrayList<>(rows.size());
    for (Object[] r : rows) {
      result.add(
          new AutoRow(
              (Long) r[0],
              (Long) r[1],
              (Long) r[2],
              (Long) r[3],
              (Long) r[4],
              (String) r[5],
              (String) r[6],
              (Instant) r[7],
              r[8] != null));
    }
    return result;
  }

  /**
   * The GPX asset each route would be sent from — the filtered GPX, failing that the original, as
   * {@code GpsService} picks it; the newest when there are several — in one query for all routes.
   *
   * @return route id → asset id; routes without a GPX are absent
   */
  public Map<Long, Long> findGpxAssetIds(Long domainId, Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return Map.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select a.teamEntity.id, a.id, a.type from Asset a"
                    + " where a.teamEntity.id in (:routeIds) and a.type in (:types)"
                    + " and a.team.domain.id = :domainId",
                Object[].class)
            .setParameter("routeIds", routeIds)
            .setParameter(
                "types", List.of(AssetType.ROUTE_FILTERED_GPX, AssetType.ROUTE_ORIGINAL_GPX))
            .setParameter("domainId", domainId)
            .getResultList();
    Map<Long, Long> filtered = new HashMap<>();
    Map<Long, Long> original = new HashMap<>();
    for (Object[] r : rows) {
      Map<Long, Long> target = r[2] == AssetType.ROUTE_FILTERED_GPX ? filtered : original;
      target.merge((Long) r[0], (Long) r[1], Math::max);
    }
    Map<Long, Long> result = new HashMap<>(original);
    result.putAll(filtered);
    return result;
  }

  /**
   * Writes the desired state of one automatic row, creating it if needed. Only the desired columns
   * — never the synchronised ones nor the lease — and nothing at all when they are unchanged, so a
   * tick replayed, or run by both backends of a rolling deploy, writes the same thing once. A new
   * desired hash forgets the failures of the previous one.
   */
  public void upsertDesired(
      Long domainId,
      Long userId,
      Long connectionId,
      Long rideId,
      Long rideGroupId,
      Long routeId,
      String hash,
      String name,
      Instant groupStartAt,
      Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into gps_route_syncs
              (id, domain_id, user_id, connection_id, ride_id, ride_group_id, desired_route_id,
               desired_hash, desired_name, group_start_at, attempts, created_at, updated_at)
            values
              (:id, :domainId, :userId, :connectionId, :rideId, :groupId, :routeId, :hash, :name,
               :startAt, 0, :now, :now)
            on conflict (connection_id, ride_id) do update set
              attempts = case when gps_route_syncs.desired_hash is distinct from excluded.desired_hash
                then 0 else gps_route_syncs.attempts end,
              next_attempt_at = case
                when gps_route_syncs.desired_hash is distinct from excluded.desired_hash
                then null else gps_route_syncs.next_attempt_at end,
              ride_group_id = excluded.ride_group_id,
              desired_route_id = excluded.desired_route_id,
              desired_hash = excluded.desired_hash,
              desired_name = excluded.desired_name,
              group_start_at = excluded.group_start_at,
              updated_at = excluded.updated_at
            where (gps_route_syncs.ride_group_id, gps_route_syncs.desired_route_id,
                   gps_route_syncs.desired_hash, gps_route_syncs.group_start_at)
              is distinct from
                  (excluded.ride_group_id, excluded.desired_route_id, excluded.desired_hash,
                   excluded.group_start_at)
            """)
        .setParameter("id", TSID.Factory.getTsid().toLong())
        .setParameter("domainId", domainId)
        .setParameter("userId", userId)
        .setParameter("connectionId", connectionId)
        .setParameter("rideId", rideId)
        .setParameter("groupId", rideGroupId)
        .setParameter("routeId", routeId)
        .setParameter("hash", hash)
        .setParameter("name", name)
        .setParameter("startAt", Timestamp.from(groupStartAt))
        .setParameter("now", Timestamp.from(now))
        .executeUpdate();
  }

  /**
   * The automatic rows that must disappear from their service: nothing desired any more. Only rows
   * that still desire something, so that a replay writes nothing.
   */
  public int clearDesired(Long domainId, Collection<Long> ids, Instant now) {
    if (ids.isEmpty()) {
      return 0;
    }
    return update(
        "desiredRouteId = null, desiredHash = null, desiredName = null, attempts = 0, nextAttemptAt"
            + " = null, updatedAt = ?3 where domainId = ?1 and id in ?2 and rideId is not null and"
            + " desiredHash is not null",
        domainId,
        ids,
        now);
  }

  /**
   * Deletes the automatic rows with nothing at the service and nothing desired — unless a worker
   * holds them: its creation may be about to land, and its id must find the row.
   */
  public long deleteSettled(Long domainId, Instant now) {
    return delete(
        "domainId = ?1 and rideId is not null and desiredHash is null and externalRouteId is null"
            + " and (claimedUntil is null or claimedUntil < ?2)",
        domainId,
        now);
  }

  // ------------------------------------------------------------------ worker

  /** A leased row, detached from the claiming transaction. */
  public record Claim(
      Long id,
      Long domainId,
      Long userId,
      Long connectionId,
      GpsServiceType serviceType,
      @Nullable Long rideId,
      @Nullable Long desiredRouteId,
      @Nullable String desiredHash,
      @Nullable String desiredName,
      @Nullable String externalRouteId,
      int attempts,
      Instant lease) {}

  /** The domains with automatic rows due now. Across domains, like {@link #findDomainsToPlan}. */
  public List<Long> findDomainsWithDueWork(Instant now, int maxAttempts) {
    @SuppressWarnings("unchecked")
    List<Number> ids =
        getEntityManager()
            .createNativeQuery(
                """
                select distinct s.domain_id from gps_route_syncs s
                  join gps_service_connections c on c.id = s.connection_id
                  where s.ride_id is not null
                    and s.desired_hash is distinct from s.synced_hash
                    and s.attempts < :maxAttempts
                    and (s.next_attempt_at is null or s.next_attempt_at <= :now)
                    and (s.claimed_until is null or s.claimed_until < :now)
                    and c.sync_reconnect_required_at is null
                    and (c.sync_paused_until is null or c.sync_paused_until <= :now)
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .getResultList();
    return ids.stream().map(Number::longValue).toList();
  }

  /**
   * The due automatic rows of the domain, nearest departure first, row-locked for the claiming
   * transaction ({@code FOR UPDATE SKIP LOCKED}: a second worker takes others). To be leased in the
   * same transaction ({@link #lease}).
   */
  public List<Long> findDueIdsSkipLocked(Long domainId, Instant now, int maxAttempts, int limit) {
    @SuppressWarnings("unchecked")
    List<Number> ids =
        getEntityManager()
            .createNativeQuery(
                """
                select s.id from gps_route_syncs s
                  join gps_service_connections c on c.id = s.connection_id
                  where s.domain_id = :domainId
                    and s.ride_id is not null
                    and s.desired_hash is distinct from s.synced_hash
                    and s.attempts < :maxAttempts
                    and (s.next_attempt_at is null or s.next_attempt_at <= :now)
                    and (s.claimed_until is null or s.claimed_until < :now)
                    and c.sync_reconnect_required_at is null
                    and (c.sync_paused_until is null or c.sync_paused_until <= :now)
                  order by s.group_start_at, s.id
                  limit :limit
                  for update of s skip locked
                """)
            .setParameter("domainId", domainId)
            .setParameter("now", Timestamp.from(now))
            .setParameter("maxAttempts", maxAttempts)
            .setParameter("limit", limit)
            .getResultList();
    return ids.stream().map(Number::longValue).toList();
  }

  /** Leases the rows until {@code until}, in the claiming transaction. */
  public int lease(Collection<Long> ids, Instant until) {
    if (ids.isEmpty()) {
      return 0;
    }
    return update("claimedUntil = ?1 where id in ?2", until, ids);
  }

  /**
   * Leases one automatic row unless another worker holds it — for a manual upload of a route the
   * sync already tracks, which then runs the worker's own step on it.
   */
  public boolean claimOne(Long id, Instant now, Instant until) {
    return update(
            "claimedUntil = ?1 where id = ?2 and rideId is not null"
                + " and (claimedUntil is null or claimedUntil < ?3)",
            until,
            id,
            now)
        == 1;
  }

  /** The leased rows, as the worker needs them. */
  public List<Claim> findClaims(Collection<Long> ids, Instant lease) {
    if (ids.isEmpty()) {
      return List.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select s.id, s.domainId, s.user.id, c.id, c.serviceType, s.rideId,"
                    + " s.desiredRouteId, s.desiredHash, s.desiredName, s.externalRouteId,"
                    + " s.attempts"
                    + " from GpsRouteSync s join s.connection c"
                    + " where s.id in (:ids) and s.claimedUntil = :lease"
                    + " order by s.groupStartAt, s.id",
                Object[].class)
            .setParameter("ids", ids)
            .setParameter("lease", lease)
            .getResultList();
    List<Claim> claims = new ArrayList<>(rows.size());
    for (Object[] r : rows) {
      claims.add(
          new Claim(
              (Long) r[0],
              (Long) r[1],
              (Long) r[2],
              (Long) r[3],
              (GpsServiceType) r[4],
              (Long) r[5],
              (Long) r[6],
              (String) r[7],
              (String) r[8],
              (String) r[9],
              (Integer) r[10],
              lease));
    }
    return claims;
  }

  /**
   * A creation or an update went through: what is at the service now is what was sent ({@code
   * hash}, computed from what was read, not the desired hash read again — a change made meanwhile
   * leaves the row behind, for the next tick). Lease given back.
   *
   * @return 0 when the lease was lost (expired and taken, or the row deleted by a disconnection)
   */
  public int markSynced(Long id, Instant lease, String externalId, String hash, Instant now) {
    return update(
        "externalRouteId = ?3, syncedHash = ?4, syncedAt = ?5, attempts = 0, nextAttemptAt = null,"
            + " lastError = null, lastErrorAt = null, claimedUntil = null, updatedAt = ?5"
            + " where id = ?1 and claimedUntil = ?2",
        id,
        lease,
        externalId,
        hash,
        now);
  }

  /**
   * The route is gone from the service. The row goes too, unless something is desired again
   * meanwhile: it then waits, empty, to be created anew.
   */
  public int markRemoved(Long id, Instant lease, Instant now) {
    long deleted = delete("id = ?1 and claimedUntil = ?2 and desiredHash is null", id, lease);
    if (deleted > 0) {
      return (int) deleted;
    }
    return update(
        "externalRouteId = null, syncedHash = null, syncedAt = ?3, attempts = 0,"
            + " nextAttemptAt = null, lastError = null, lastErrorAt = null, claimedUntil = null,"
            + " updatedAt = ?3 where id = ?1 and claimedUntil = ?2",
        id,
        lease,
        now);
  }

  /** A failed attempt: retried at {@code nextAttemptAt}, lease given back. */
  public int markFailed(
      Long id,
      Instant lease,
      int attempts,
      @Nullable Instant nextAttemptAt,
      GpsSyncError error,
      Instant now) {
    return update(
        "attempts = ?3, nextAttemptAt = ?4, lastError = ?5, lastErrorAt = ?6, claimedUntil = null,"
            + " updatedAt = ?6 where id = ?1 and claimedUntil = ?2",
        id,
        lease,
        attempts,
        nextAttemptAt,
        error,
        now);
  }

  /** Gives the row back untouched: the tick ran out of budget before reaching it. */
  public int release(Long id, Instant lease) {
    return update("claimedUntil = null where id = ?1 and claimedUntil = ?2", id, lease);
  }

  /**
   * Gives the row back without counting an attempt — the connection is paused or needs a
   * reconnection, which the claim already filters on. {@code error} says why, for the profile.
   */
  public int release(Long id, Instant lease, GpsSyncError error, Instant now) {
    return update(
        "claimedUntil = null, lastError = ?3, lastErrorAt = ?4"
            + " where id = ?1 and claimedUntil = ?2",
        id,
        lease,
        error,
        now);
  }

  /**
   * Hands over the manual upload of {@code routeId} on this connection, if one is tracked, to the
   * leased automatic row {@code id} that now takes the route in charge — an update instead of a
   * second copy at the service (§3.6). In one transaction, and before the service is called: the
   * external id is written onto the automatic row (its synced hash left as it is, so the row stays
   * due) and the manual row deleted. Whatever the call then does — fails, is rate-limited, or never
   * returns — the id stays on the automatic row, and the next attempt updates that route rather than
   * creating a copy and leaving the user's upload untracked.
   *
   * @throws IllegalStateException when the lease was lost meanwhile: nothing is handed over
   */
  public Optional<String> takeManual(Long id, Instant lease, Long connectionId, Long routeId) {
    Optional<GpsRouteSync> manual =
        find(
                "connection.id = ?1 and desiredRouteId = ?2 and rideId is null"
                    + " and externalRouteId is not null",
                connectionId,
                routeId)
            .withLock(LockModeType.PESSIMISTIC_WRITE)
            .firstResultOptional();
    if (manual.isEmpty()) {
      return Optional.empty();
    }
    String externalId = manual.get().getExternalRouteId();
    int adopted =
        update(
            "externalRouteId = ?3, updatedAt = ?4"
                + " where id = ?1 and claimedUntil = ?2 and externalRouteId is null",
            id,
            lease,
            externalId,
            Instant.now());
    if (adopted == 0) {
      throw new IllegalStateException("Lease lost before the manual upload was taken over");
    }
    delete(manual.get());
    return Optional.ofNullable(externalId);
  }

  /**
   * Every automatic row of the connection is due again, its failures forgotten — on a reconnection,
   * or when the sync is turned back on. Rows at {@code MAX_ATTEMPTS} are otherwise never claimed
   * again until their desired state changes.
   */
  public int resetAttempts(Long connectionId, Instant now) {
    return update(
        "attempts = 0, nextAttemptAt = null, lastError = null, lastErrorAt = null, updatedAt = ?2"
            + " where connection.id = ?1 and rideId is not null"
            + " and (attempts > 0 or lastError is not null)",
        connectionId,
        now);
  }

  // ------------------------------------------------------------------ manual uploads

  /**
   * The automatic row of this connection that desires {@code routeId}, the nearest departure first,
   * if any.
   */
  public Optional<GpsRouteSync> findAutoForRoute(Long domainId, Long connectionId, Long routeId) {
    return find(
            "domainId = ?1 and connection.id = ?2 and desiredRouteId = ?3 and rideId is not null"
                + " order by groupStartAt, id",
            domainId,
            connectionId,
            routeId)
        .firstResultOptional();
  }

  /** The tracked manual upload of {@code routeId} on this connection, if any. */
  public Optional<GpsRouteSync> findManual(Long domainId, Long connectionId, Long routeId) {
    return find(
            "domainId = ?1 and connection.id = ?2 and desiredRouteId = ?3 and rideId is null",
            domainId,
            connectionId,
            routeId)
        .firstResultOptional();
  }

  /**
   * Records a manual upload: one row per connection and route, its desired and synced hashes equal
   * (never claimed by the worker). Two simultaneous uploads land on the same row ({@code
   * uk_gps_route_syncs_manual}).
   */
  public void upsertManual(
      Long domainId,
      Long userId,
      Long connectionId,
      Long routeId,
      String name,
      String hash,
      String externalId,
      Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into gps_route_syncs
              (id, domain_id, user_id, connection_id, ride_id, desired_route_id, desired_hash,
               desired_name, external_route_id, synced_hash, synced_at, attempts, created_at,
               updated_at)
            values
              (:id, :domainId, :userId, :connectionId, null, :routeId, :hash, :name, :externalId,
               :hash, :now, 0, :now, :now)
            on conflict (connection_id, desired_route_id) where ride_id is null do update set
              desired_hash = excluded.desired_hash,
              desired_name = excluded.desired_name,
              external_route_id = excluded.external_route_id,
              synced_hash = excluded.synced_hash,
              synced_at = excluded.synced_at,
              updated_at = excluded.updated_at
            """)
        .setParameter("id", TSID.Factory.getTsid().toLong())
        .setParameter("domainId", domainId)
        .setParameter("userId", userId)
        .setParameter("connectionId", connectionId)
        .setParameter("routeId", routeId)
        .setParameter("hash", hash)
        .setParameter("name", name)
        .setParameter("externalId", externalId)
        .setParameter("now", Timestamp.from(now))
        .executeUpdate();
  }

  // ------------------------------------------------------------------ reads for the clients

  /** One tracked row of a user, for the per-route state ({@code GpsRouteSyncService}). */
  public record RouteRow(
      Long routeId,
      GpsServiceType serviceType,
      boolean automatic,
      @Nullable String externalRouteId,
      @Nullable String desiredHash,
      @Nullable String desiredName,
      @Nullable String syncedHash,
      @Nullable Instant syncedAt,
      int attempts,
      boolean reconnectRequired) {}

  /**
   * The rows of a user's connections that hold one of {@code routeIds}, in one query whatever the
   * number of routes — the per-page lookup rule (CLAUDE.md).
   */
  public List<RouteRow> findByUserAndRoutes(Long domainId, Long userId, Collection<Long> routeIds) {
    if (routeIds.isEmpty()) {
      return List.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select s.desiredRouteId, c.serviceType, s.rideId, s.externalRouteId,"
                    + " s.desiredHash, s.desiredName, s.syncedHash, s.syncedAt, s.attempts,"
                    + " c.syncReconnectRequiredAt"
                    + " from GpsRouteSync s join s.connection c"
                    + " where s.domainId = :domainId and s.user.id = :userId"
                    + " and s.desiredRouteId in (:routeIds)",
                Object[].class)
            .setParameter("domainId", domainId)
            .setParameter("userId", userId)
            .setParameter("routeIds", routeIds)
            .getResultList();
    List<RouteRow> result = new ArrayList<>(rows.size());
    for (Object[] r : rows) {
      result.add(
          new RouteRow(
              (Long) r[0],
              (GpsServiceType) r[1],
              r[2] != null,
              (String) r[3],
              (String) r[4],
              (String) r[5],
              (String) r[6],
              (Instant) r[7],
              (Integer) r[8],
              r[9] != null));
    }
    return result;
  }

  /** The automatic rows of one connection, aggregated for the profile. */
  public record ConnectionSummary(
      long routeCount, boolean pending, boolean failing, @Nullable Instant lastSyncedAt) {

    public static final ConnectionSummary EMPTY = new ConnectionSummary(0, false, false, null);
  }

  /**
   * The summary of each connection's automatic rows, in one grouped query for all of them.
   * Connections without a row are absent.
   */
  public Map<Long, ConnectionSummary> summarize(Long domainId, Collection<Long> connectionIds) {
    if (connectionIds.isEmpty()) {
      return Map.of();
    }
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select s.connection.id,"
                    + " sum(case when s.externalRouteId is not null then 1 else 0 end),"
                    + " sum(case when (s.desiredHash is null and s.externalRouteId is not null)"
                    + "   or (s.desiredHash is not null and (s.syncedHash is null"
                    + "   or s.syncedHash <> s.desiredHash)) then 1 else 0 end),"
                    + " sum(case when s.attempts > 0 then 1 else 0 end),"
                    + " max(s.syncedAt)"
                    + " from GpsRouteSync s"
                    + " where s.domainId = :domainId and s.connection.id in (:ids)"
                    + " and s.rideId is not null"
                    + " group by s.connection.id",
                Object[].class)
            .setParameter("domainId", domainId)
            .setParameter("ids", connectionIds)
            .getResultList();
    Map<Long, ConnectionSummary> result = new HashMap<>();
    for (Object[] r : rows) {
      result.put(
          (Long) r[0],
          new ConnectionSummary(
              ((Number) r[1]).longValue(),
              ((Number) r[2]).longValue() > 0,
              ((Number) r[3]).longValue() > 0,
              (Instant) r[4]));
    }
    return result;
  }

  /** Every row of a user, its connection fetched: the GDPR export. */
  public List<GpsRouteSync> findByUser(Long domainId, Long userId) {
    return find(
            "from GpsRouteSync s join fetch s.connection"
                + " where s.domainId = ?1 and s.user.id = ?2 order by s.createdAt",
            domainId,
            userId)
        .list();
  }

  // ------------------------------------------------------------------ disconnection

  /** A route the sync placed at a service, to remove before the connection goes. */
  public record Placed(Long id, String externalRouteId) {}

  /**
   * The automatic rows of the connection that have a route at the service and that no worker holds
   * (a held one is the accepted race of the plan, §4.6).
   */
  public List<Placed> findPlacedByConnection(Long domainId, Long connectionId, Instant now) {
    List<Object[]> rows =
        getEntityManager()
            .createQuery(
                "select s.id, s.externalRouteId from GpsRouteSync s"
                    + " where s.domainId = :domainId and s.connection.id = :connectionId"
                    + " and s.rideId is not null and s.externalRouteId is not null"
                    + " and (s.claimedUntil is null or s.claimedUntil < :now)",
                Object[].class)
            .setParameter("domainId", domainId)
            .setParameter("connectionId", connectionId)
            .setParameter("now", now)
            .getResultList();
    List<Placed> result = new ArrayList<>(rows.size());
    for (Object[] r : rows) {
      result.add(new Placed((Long) r[0], (String) r[1]));
    }
    return result;
  }

  public long deleteByConnection(Long connectionId) {
    return delete("connection.id = ?1", connectionId);
  }
}
