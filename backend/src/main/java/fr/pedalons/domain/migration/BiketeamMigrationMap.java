package fr.pedalons.domain.migration;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

/**
 * Maps a biketeam source row (entityType + biketeamId) to the tribly entity that was created /
 * updated for it. Populated by {@code BiketeamMigrationService} so re-runs find existing tribly
 * entities instead of creating duplicates.
 *
 * <p>Shared by the legacy dump import and the live migration: the key {@code (entityType,
 * biketeamId)} is global, since a biketeam team is migrated into one domain per database.
 */
@Setter
@Getter
@Entity
@Table(name = "biketeam_migration_map")
@IdClass(BiketeamMigrationMap.Key.class)
@NoArgsConstructor
public class BiketeamMigrationMap {

  @Id
  @Column(name = "entity_type", nullable = false, length = 40)
  private String entityType;

  @Id
  @Column(name = "biketeam_id", nullable = false, length = 255)
  private String biketeamId;

  @Column(name = "tribly_id", nullable = false)
  private long triblyId;

  @Column(name = "synced_at", nullable = false)
  private Instant syncedAt = Instant.now();

  /**
   * Digest of the biketeam file this row was last fully built from, or null when the row has no
   * source file — or when the work never completed. Lets a replay tell "already done" from "started
   * and interrupted".
   */
  @Column(name = "source_fingerprint", length = 64)
  private @Nullable String sourceFingerprint;

  /**
   * The biketeam team this row came from, so that setting a trashed team aside can forget exactly
   * that team. Null on the rows
   * the legacy import wrote; the live migration fills it on every upsert.
   */
  @Column(name = "biketeam_team_id", length = 255)
  private @Nullable String biketeamTeamId;

  public BiketeamMigrationMap(String entityType, String biketeamId, long triblyId) {
    this.entityType = entityType;
    this.biketeamId = biketeamId;
    this.triblyId = triblyId;
  }

  public void touch() {
    this.syncedAt = Instant.now();
  }

  @Getter
  @Setter
  @NoArgsConstructor
  public static class Key implements Serializable {
    private String entityType;
    private String biketeamId;

    public Key(String entityType, String biketeamId) {
      this.entityType = entityType;
      this.biketeamId = biketeamId;
    }

    @Override
    public boolean equals(Object o) {
      if (this == o) return true;
      if (!(o instanceof Key key)) return false;
      return Objects.equals(entityType, key.entityType)
          && Objects.equals(biketeamId, key.biketeamId);
    }

    @Override
    public int hashCode() {
      return Objects.hash(entityType, biketeamId);
    }
  }
}
