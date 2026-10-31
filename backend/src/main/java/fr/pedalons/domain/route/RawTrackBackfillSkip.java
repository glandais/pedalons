package fr.pedalons.domain.route;

import fr.pedalons.domain.common.NotNullableDbValue;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * A route the catch-up of raw lines gave up on (docs/LEDGER_*.md API-147, phase D): its original
 * GPX is missing or unreadable, or holds another number of tracks than the stored ones. One row per
 * route, so that no pass picks it again; the foreign key cascades, so deleting the route takes the
 * row with it. Written only by a native insert ({@code RawTrackBackfillRepository}).
 */
@Setter
@Getter
@Entity
@Table(name = "raw_track_backfill_skip")
@NoArgsConstructor
public class RawTrackBackfillSkip {

  /** Why a route was given up. */
  public enum Reason {
    /** The route has no original GPX asset, or its object is not in the bucket. */
    MISSING_ORIGINAL,
    /** The original is not a GPX the import would accept (parse, sanitizing, limits). */
    UNREADABLE,
    /** The original holds another number of tracks (of two points or more) than the route. */
    TRACK_COUNT,
    /**
     * The parse broke on something else than a rejected GPX, or the write failed several passes in
     * a row; the log has the cause. A failure of the bucket or the database alone never gives a
     * route up.
     */
    ERROR
  }

  @Id
  @Column(name = "route_id")
  private Long routeId;

  // The primary key itself (@MapsId): never null, which the nullability rule cannot see on a
  // @OneToOne
  @NotNullableDbValue
  @MapsId
  @OneToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "route_id")
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Route route;

  @Column(name = "reason", nullable = false, columnDefinition = "text")
  private String reason;

  @Column(name = "skipped_at", nullable = false)
  private Instant skippedAt;
}
