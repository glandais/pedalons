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
 * A request of the former surface queue (docs/LEDGER_*.md WEB-100, C1b): one row per saved route or
 * GPX-tool preview. Nothing here claims it any more since docs/LEDGER_*.md API-150 (phase E): only
 * a previous release does, during a rolling deploy or after a rollback, and a row it leaves is
 * inert. The entity stays until phase F, one release before its table: it is what creates the
 * table in the test schema ({@code drop-and-create}), which {@code import-test.sql} completes with its partial
 * indexes, as for {@code RawTrackResurface}.
 *
 * <p>Exactly one of {@link #route} and {@link #preview} is set (a check constraint in the
 * migration), each with a foreign key that cascades, so a request left here never holds back the
 * deletion of its target.
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

  /** The lease of a previous release's worker. */
  @Column(name = "claimed_until")
  private @Nullable Instant claimedUntil;

  @Column(name = "last_error", columnDefinition = "text")
  private @Nullable String lastError;

  /**
   * Queued by the former catch-up of old tracks, gone with docs/LEDGER_*.md API-150 (phase D), not
   * by a save: taken only once no normal request is due. A row may be left from the previous
   * release; an upsert of the previous release makes it a normal request again.
   */
  @Column(name = "backfill", nullable = false)
  private boolean backfill;
}
