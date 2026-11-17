package fr.pedalons.repository.weather;

import fr.pedalons.domain.weather.WeatherCell;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.hibernate.query.TypedParameterValue;
import org.hibernate.type.StandardBasicTypes;
import org.jspecify.annotations.Nullable;

/**
 * The weather cells: planned by {@code WeatherPlanner}, claimed and refreshed by {@code
 * WeatherFetchWorker}, dropped by {@code WeatherHousekeeping}.
 *
 * <p>No {@code domainId} anywhere: the cache is global (see {@code fr.pedalons.domain.weather}).
 */
@ApplicationScoped
public class WeatherCellRepository implements PanacheRepository<WeatherCell> {

  /**
   * Records that the planner needs this cell, creating it due at once if it is new.
   *
   * <p>Native, as {@code NotificationEventRepository#insertIfAbsent}: two planners of a rolling
   * deploy may want the same new cell in the same second, and {@code ON CONFLICT} settles it without
   * a constraint violation in either transaction. Deterministic in its inputs, so a replayed tick
   * writes the same thing again.
   *
   * <p>{@code next_refresh_at} on an existing cell:
   *
   * <ul>
   *   <li>left alone while a failure's backoff runs ({@code attempts > 0}): planning must not undo
   *       it, or a provider in trouble would be asked again every five minutes;
   *   <li>now, for a cell never fetched;
   *   <li>else {@code fetched_at + ttl}, the interval that suits the closest passage — so a ride
   *       moving closer shortens the wait of a cell fetched under a longer one.
   * </ul>
   *
   * @param ttl the refresh interval for {@code nearestNeedAt} ({@code WeatherRefreshPolicy})
   */
  public void upsertDemand(
      int latIdx,
      int lonIdx,
      @Nullable Integer eleBand,
      double latitude,
      double longitude,
      Instant nearestNeedAt,
      Duration ttl,
      Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into weather_cells
              (id, lat_idx, lon_idx, ele_band, latitude, longitude, next_refresh_at,
               nearest_need_at, last_demand_at, attempts, created_at, updated_at)
            values
              (:id, :latIdx, :lonIdx, :eleBand, :latitude, :longitude, :now, :need, :now, 0, :now,
               :now)
            on conflict (lat_idx, lon_idx, ele_band) do update set
              last_demand_at = excluded.last_demand_at,
              nearest_need_at = excluded.nearest_need_at,
              next_refresh_at = case
                when weather_cells.attempts > 0 then weather_cells.next_refresh_at
                when weather_cells.fetched_at is null then excluded.next_refresh_at
                else weather_cells.fetched_at + make_interval(secs => :ttlSeconds)
              end,
              updated_at = excluded.updated_at
            """)
        .setParameter("id", TSID.Factory.getTsid().toLong())
        .setParameter("latIdx", latIdx)
        .setParameter("lonIdx", lonIdx)
        .setParameter("eleBand", new TypedParameterValue<>(StandardBasicTypes.INTEGER, eleBand))
        .setParameter("latitude", latitude)
        .setParameter("longitude", longitude)
        .setParameter("need", Timestamp.from(nearestNeedAt))
        .setParameter("ttlSeconds", (double) ttl.toSeconds())
        .setParameter("now", Timestamp.from(now))
        .executeUpdate();
  }

  /** The cell of these indexes, or null. A null band is a cell of its own, not a wildcard. */
  public @Nullable WeatherCell findByKey(int latIdx, int lonIdx, @Nullable Integer eleBand) {
    return eleBand == null
        ? find("latIdx = ?1 and lonIdx = ?2 and eleBand is null", latIdx, lonIdx).firstResult()
        : find("latIdx = ?1 and lonIdx = ?2 and eleBand = ?3", latIdx, lonIdx, eleBand)
            .firstResult();
  }

  /**
   * Due cells still wanted, nearest passage first, locked for this transaction and skipping those
   * another worker holds. Same two-part claim as {@code NotificationEventRepository}: {@code skip
   * locked} for throughput, then the lease of {@link #lease} for correctness once this transaction
   * commits and the provider call runs outside of it.
   *
   * <p>Only the cells a recent planning pass asked for ({@code last_demand_at >= demandedSince})
   * and whose nearest passage is still ahead: a cell whose ride left the planner's window — gone
   * by, deleted, cancelled, moved — is never fetched again, only left for the nightly purge.
   * Without this, such a cell would come back every hour (the interval of a passage in the past)
   * until that purge, and at the head of the queue, its passage being the nearest of all.
   */
  public List<Long> findDueIdsSkipLocked(Instant now, Instant demandedSince, int limit) {
    @SuppressWarnings("unchecked")
    List<Number> ids =
        getEntityManager()
            .createNativeQuery(
                """
                select id from weather_cells
                where next_refresh_at <= :now
                  and (claimed_until is null or claimed_until < :now)
                  and last_demand_at >= :demandedSince
                  and nearest_need_at >= :now
                order by nearest_need_at, next_refresh_at
                limit :limit
                for update skip locked
                """)
            .setParameter("now", Timestamp.from(now))
            .setParameter("demandedSince", Timestamp.from(demandedSince))
            .setParameter("limit", limit)
            .getResultList();
    return ids.stream().map(Number::longValue).toList();
  }

  /**
   * Leases the cells until {@code until}. In the claiming transaction, after {@link
   * #findDueIdsSkipLocked}: once it commits, the row locks are gone and the lease is what keeps a
   * second worker off these cells while the provider answers. A worker that dies leaves the lease
   * to expire.
   */
  public int lease(Collection<Long> ids, Instant until) {
    if (ids.isEmpty()) {
      return 0;
    }
    return update("claimedUntil = ?1 where id in ?2", until, ids);
  }

  /** Gives cells back without counting a failure: the breaker opened, or the budget ran out. */
  public int release(Collection<Long> ids) {
    if (ids.isEmpty()) {
      return 0;
    }
    return update("claimedUntil = null where id in ?1", ids);
  }

  /** A successful refresh: forecast stored, backoff forgotten, lease released. */
  public int markFetched(
      Long id,
      @Nullable Double gridElevation,
      @Nullable String timezone,
      Instant fetchedAt,
      Instant nextRefreshAt) {
    return update(
        "gridElevation = ?1, timezone = ?2, fetchedAt = ?3, nextRefreshAt = ?4, attempts = 0,"
            + " lastError = null, claimedUntil = null, updatedAt = ?3 where id = ?5",
        gridElevation,
        timezone,
        fetchedAt,
        nextRefreshAt,
        id);
  }

  /**
   * A failed refresh: retried after {@code min(base · 2^attempts, max)}, the stored forecast left as
   * it is — a failure never deletes anything, the cache is served stale meanwhile.
   */
  public int markFailed(
      Collection<Long> ids, String error, Duration base, Duration max, Instant now) {
    if (ids.isEmpty()) {
      return 0;
    }
    return getEntityManager()
        .createNativeQuery(
            """
            update weather_cells set
              attempts = attempts + 1,
              last_error = :error,
              claimed_until = null,
              next_refresh_at = cast(:now as timestamptz) + least(
                make_interval(secs => :baseSeconds * power(2, least(attempts, 20))),
                make_interval(secs => :maxSeconds)),
              updated_at = :now
            where id in (:ids)
            """)
        .setParameter("error", error)
        .setParameter("baseSeconds", (double) base.toSeconds())
        .setParameter("maxSeconds", (double) max.toSeconds())
        .setParameter("now", Timestamp.from(now))
        .setParameter("ids", ids)
        .executeUpdate();
  }

  /** Rate-limited: not before {@code retryAt} (the next full hour), whatever the attempt count. */
  public int markRateLimited(Collection<Long> ids, String error, Instant retryAt, Instant now) {
    if (ids.isEmpty()) {
      return 0;
    }
    return update(
        "attempts = attempts + 1, lastError = ?1, claimedUntil = null, nextRefreshAt = ?2,"
            + " updatedAt = ?3 where id in ?4",
        error,
        retryAt,
        now,
        ids);
  }

  /**
   * The cells whose indexes fall in both sets, for the read side to filter down to its exact keys.
   * One query whatever the number of keys; the cross product of the two sets only ever matches cells
   * someone planned, which near a ride are that ride's.
   */
  public List<WeatherCell> findByIndexes(Collection<Integer> latIdxs, Collection<Integer> lonIdxs) {
    if (latIdxs.isEmpty() || lonIdxs.isEmpty()) {
      return List.of();
    }
    return list("latIdx in ?1 and lonIdx in ?2", latIdxs, lonIdxs);
  }

  /**
   * Drops the cells nobody planned since {@code cutoff}, with their forecast rows (the foreign keys
   * cascade; deleted here too so the purge does not depend on them). A cell a worker holds under
   * lease is left for the next run: deleting it would make that worker's upsert of the forecast
   * rows violate the foreign key and fail its whole batch, although the provider answered.
   */
  public int deleteUndemandedBefore(Instant cutoff, Instant now) {
    Timestamp at = Timestamp.from(cutoff);
    Timestamp current = Timestamp.from(now);
    String purgeable =
        "last_demand_at < :cutoff and (claimed_until is null or claimed_until < :now)";
    getEntityManager()
        .createNativeQuery(
            "delete from weather_hourly where cell_id in"
                + " (select id from weather_cells where "
                + purgeable
                + ")")
        .setParameter("cutoff", at)
        .setParameter("now", current)
        .executeUpdate();
    getEntityManager()
        .createNativeQuery(
            "delete from weather_daily where cell_id in"
                + " (select id from weather_cells where "
                + purgeable
                + ")")
        .setParameter("cutoff", at)
        .setParameter("now", current)
        .executeUpdate();
    return getEntityManager()
        .createNativeQuery("delete from weather_cells where " + purgeable)
        .setParameter("cutoff", at)
        .setParameter("now", current)
        .executeUpdate();
  }
}
