package fr.pedalons.domain.gps;

import fr.pedalons.domain.user.User;
import fr.pedalons.enums.GpsSyncError;
import io.hypersistence.utils.hibernate.id.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.jspecify.annotations.Nullable;

/**
 * A route Pédalons sent, or is to send, to one of a member's GPS services (docs/LEDGER_*.md
 * API-120, plan {@code docs/plans/2026-10-16-gps-route-autosync.md}).
 *
 * <p>Two kinds of rows:
 *
 * <ul>
 *   <li><b>automatic</b> ({@link #rideId} set): one per connection and ride, the route of the
 *       member's group kept in sync. The planner writes the desired state ({@code desired_*},
 *       {@code ride_group_id}, {@code group_start_at}), the worker the synchronised one ({@code
 *       external_route_id}, {@code synced_*}) under a lease ({@code claimed_until}); the work is
 *       their difference — to create, update, delete. No status column: the state is derived.
 *   <li><b>manual</b> ({@link #rideId} null): a manual upload, one per connection and route,
 *       recorded so that the next manual upload of the same route updates or reuses the route at
 *       the service instead of stacking a copy. Never claimed by the worker, never updated nor
 *       deleted at the service on Pédalons' own initiative. Its desired and synced hashes are
 *       equal.
 * </ul>
 *
 * <p>Standalone and hard-deleted, like {@link GpsServiceConnection}. Written only by native
 * upserts and conditional bulk updates ({@code GpsRouteSyncRepository}), hence no {@code @Version}.
 * No foreign key on the ride, the group or the route: a group removed from a ride is deleted for
 * good, and a cascade would lose the external id, leaving the route at the service forever. The
 * connection's foreign key cascades, for the previous release of a rolling deploy, which deletes
 * connections without knowing this table; the current one deletes the rows first.
 */
@Setter
@Getter
@Entity
@Table(
    name = "gps_route_syncs",
    uniqueConstraints =
        @UniqueConstraint(
            name = "uk_gps_route_syncs_connection_ride",
            columnNames = {"connection_id", "ride_id"}),
    indexes = {
      @Index(name = "idx_gps_route_syncs_user", columnList = "user_id"),
      @Index(name = "idx_gps_route_syncs_route", columnList = "desired_route_id")
    })
@NoArgsConstructor
public class GpsRouteSync {

  @Id @Tsid private Long id;

  @Column(name = "domain_id", nullable = false)
  private Long domainId;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "connection_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private GpsServiceConnection connection;

  /** The ride of an automatic row; null for a manual upload. */
  @Column(name = "ride_id")
  private @Nullable Long rideId;

  /** The member's group in that ride, as last planned. */
  @Column(name = "ride_group_id")
  private @Nullable Long rideGroupId;

  /**
   * The route that should be at the service. Null on an automatic row: it must disappear from the
   * service. On a manual row: the route uploaded.
   */
  @Column(name = "desired_route_id")
  private @Nullable Long desiredRouteId;

  /** SHA-256 of {@code gpx content key | name sent} (D4; the key is the asset id until a track edit stamps a content revision, API-128); null with {@link #desiredRouteId}. */
  @Column(name = "desired_hash", length = 64)
  private @Nullable String desiredHash;

  @Column(name = "desired_name", length = 120)
  private @Nullable String desiredName;

  /** The group's departure, for the retention and the order of the work; null when manual. */
  @Column(name = "group_start_at")
  private @Nullable Instant groupStartAt;

  /** The route's id at the service; null when nothing is there. */
  @Column(name = "external_route_id", length = 100)
  private @Nullable String externalRouteId;

  /** The hash of what is at the service. */
  @Column(name = "synced_hash", length = 64)
  private @Nullable String syncedHash;

  @Column(name = "synced_at")
  private @Nullable Instant syncedAt;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  @Column(name = "next_attempt_at")
  private @Nullable Instant nextAttemptAt;

  /** The worker's lease. */
  @Column(name = "claimed_until")
  private @Nullable Instant claimedUntil;

  @Enumerated(EnumType.STRING)
  @Column(name = "last_error", length = 40)
  private @Nullable GpsSyncError lastError;

  @Column(name = "last_error_at")
  private @Nullable Instant lastErrorAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  public boolean isAutomatic() {
    return rideId != null;
  }
}
