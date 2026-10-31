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
 * A route the catch-up of raw lines gave a line denser than its stored points (docs/LEDGER_*.md
 * API-147, phase D): its surface, computed on those points, is worth asking again. Written whatever
 * {@code pedalons.raw-backfill.resurface} says; the surface catch-up queues it while that switch is
 * on, under its cap, and deletes the row. One row per route; the foreign key cascades. Written only
 * by native statements ({@code RawTrackBackfillRepository}, {@code SurfaceRefreshRepository}).
 */
@Setter
@Getter
@Entity
@Table(name = "raw_track_resurface")
@NoArgsConstructor
public class RawTrackResurface {

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

  /** The {@code file_id} of the original GPX the raw line was read from. */
  @Column(name = "source_revision", nullable = false)
  private Long sourceRevision;

  @Column(name = "wanted_at", nullable = false)
  private Instant wantedAt;
}
