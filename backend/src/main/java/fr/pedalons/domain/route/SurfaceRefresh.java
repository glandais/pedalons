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
 * A request to compute the surface along a saved track (docs/LEDGER_*.md WEB-100, C1b): one row per
 * saved route or GPX-tool preview, claimed by {@code SurfaceRefreshWorker} once {@link #dueAt} has
 * passed. The same model as {@code ElevationRefresh}, which it is copied from.
 *
 * <p>Exactly one of {@link #route} and {@link #preview} is set (a check constraint in the
 * migration), each with a foreign key that cascades, so deleting the target takes its request with
 * it. Written only by native upserts and conditional updates ({@code SurfaceRefreshRepository}),
 * hence no {@code @Version}.
 */
@Setter
@Getter
@Entity
@Table(
    name = "surface_refresh",
    indexes = {@Index(name = "surface_refresh_due", columnList = "due_at")})
@NoArgsConstructor
public class SurfaceRefresh {

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
