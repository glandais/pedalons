package fr.pedalons.domain.route;

import fr.pedalons.domain.gpx.GpxPreview;
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
 * A request to recompute a track with the HD elevation source (docs/LEDGER_*.md API-131, plan
 * {@code docs/plans/archive/2026-10-17-altitude-hd-asynchrone.md}): one row per saved route or GPX-tool
 * preview that is still on the fast source, claimed by {@code ElevationRefreshWorker} once {@link
 * #dueAt} has passed.
 *
 * <p>Exactly one of {@link #route} and {@link #preview} is set (a check constraint in the
 * migration), each with a foreign key that cascades, so deleting the target takes its request with
 * it — the same hard-delete model as {@code GpsRouteSync}. Written only by native upserts and
 * conditional updates ({@code ElevationRefreshRepository}), hence no {@code @Version}.
 */
@Setter
@Getter
@Entity
@Table(
    name = "elevation_refresh",
    indexes = {@Index(name = "elevation_refresh_due", columnList = "due_at")})
@NoArgsConstructor
public class ElevationRefresh {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "route_id")
  @OnDelete(action = OnDeleteAction.CASCADE)
  private @Nullable Route route;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "preview_id")
  @OnDelete(action = OnDeleteAction.CASCADE)
  private @Nullable GpxPreview preview;

  /**
   * The version of the track the request is about: the {@code file_id} of a route's original GPX,
   * {@code files_revision} of a preview. A result computed for another one is never written.
   */
  @Column(name = "source_revision", nullable = false)
  private long sourceRevision;

  /** When the first of the saves this request stands for happened: the debounce cap starts here. */
  @Column(name = "first_requested_at", nullable = false)
  private Instant firstRequestedAt;

  @Column(name = "due_at", nullable = false)
  private Instant dueAt;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  /** The worker's lease. */
  @Column(name = "claimed_until")
  private @Nullable Instant claimedUntil;

  @Column(name = "last_error", columnDefinition = "text")
  private @Nullable String lastError;
}
