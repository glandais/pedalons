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
 * API-149, phase D). Nothing reads or writes it since docs/LEDGER_*.md API-150 (phase D): a
 * recompute starts from the original GPX, which holds that line. Kept for the table, and for the
 * schema of the tests, until its migration (phase F); the rows left are inert.
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
