package fr.pedalons.domain.weather;

import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

/**
 * One forecast location of the weather cache: a 0.05° cell (~5 km), plus a 100 m elevation band when
 * the point it stands for has a known altitude.
 *
 * <p><b>Global, with no {@code domainId}</b> — the explicit exception to the rule that every query
 * filters by domain (see the package documentation): a forecast depends on a place and an hour only,
 * and a cell is only ever read starting from a ride the caller may already read. The coordinates
 * stored are the centre of the cell, which is also what the provider is asked about: a meeting
 * point never leaves the server more precisely than the cell.
 *
 * <p>Standalone (no {@code BaseEntity}): nobody creates a cell, the planner does. Never persisted
 * through JPA either: {@code WeatherCellRepository} upserts it natively, because two planners of a
 * rolling deploy may want the same cell at the same moment. The unique key {@code (lat_idx,
 * lon_idx, ele_band) NULLS NOT DISTINCT} lives in {@code V61__weather_cache.sql} and, for the tests
 * (built from the entities), in {@code import-test.sql}: an annotation cannot say {@code NULLS NOT
 * DISTINCT}.
 */
@Setter
@Getter
@Entity
@Table(
    name = "weather_cells",
    indexes = {
      @Index(name = "idx_weather_cells_next_refresh", columnList = "next_refresh_at"),
      @Index(name = "idx_weather_cells_last_demand", columnList = "last_demand_at")
    })
@NoArgsConstructor
public class WeatherCell {

  @Id @Tsid private Long id;

  /** {@code round(lat / 0.05)}. See {@code CellKey}. */
  @Column(name = "lat_idx", nullable = false)
  private int latIdx;

  /** {@code round(lon / 0.05)}. */
  @Column(name = "lon_idx", nullable = false)
  private int lonIdx;

  /** {@code round(ele / 100) * 100} in metres, or null for a point of unknown altitude. */
  @Column(name = "ele_band")
  private @Nullable Integer eleBand;

  /** Centre of the cell — what the provider is asked about. */
  @Column(name = "latitude", nullable = false)
  private double latitude;

  @Column(name = "longitude", nullable = false)
  private double longitude;

  /** The elevation the provider says it used, once fetched. */
  @Column(name = "grid_elevation")
  private @Nullable Double gridElevation;

  /** IANA zone of the cell as the provider reports it ({@code timezone=auto}), once fetched. */
  @Column(name = "timezone", length = 64)
  private @Nullable String timezone;

  /** When the stored forecast was fetched; null until the first success. */
  @Column(name = "fetched_at")
  private @Nullable Instant fetchedAt;

  /** When the worker should fetch it next — also where a failure's backoff is written. */
  @Column(name = "next_refresh_at", nullable = false)
  private Instant nextRefreshAt;

  /** The closest passage the planner found for this cell, which sets its refresh interval. */
  @Column(name = "nearest_need_at")
  private @Nullable Instant nearestNeedAt;

  /** Last planner tick that needed this cell; the housekeeping drops cells nobody needs any more. */
  @Column(name = "last_demand_at", nullable = false)
  private Instant lastDemandAt;

  /** The lease of the worker that claimed it; null or past when free. */
  @Column(name = "claimed_until")
  private @Nullable Instant claimedUntil;

  /** Consecutive failed fetches; reset by a success. Drives the backoff. */
  @Column(name = "attempts", nullable = false)
  private int attempts;

  /** The last failure, redacted (never the provider URL, which may carry the API key). */
  @Column(name = "last_error", length = 500)
  private @Nullable String lastError;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt = Instant.now();
}
