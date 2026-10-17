package fr.pedalons.domain.asset;

import fr.pedalons.domain.common.BaseEntity;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@EntityListeners(AssetRemoveListener.class)
@Table(
    name = "assets",
    indexes = {
      @Index(name = "idx_assets_team_entity", columnList = "team_entity_id"),
      @Index(name = "idx_assets_team", columnList = "team_id")
    })
@NoArgsConstructor
public class Asset extends BaseEntity {

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  protected Team team;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_entity_id")
  @Nullable
  protected TeamEntity teamEntity;

  @Enumerated(EnumType.STRING)
  @Column(name = "type", nullable = false, length = 25)
  protected AssetType type;

  @Column(name = "file_id", nullable = false)
  protected Long fileId;

  @Column(name = "file_name", nullable = false, length = 200)
  protected String fileName;

  @Column(name = "content_type", nullable = false, length = 200)
  protected String contentType;

  @Column(name = "width")
  @Nullable
  protected Integer width;

  @Column(name = "height")
  @Nullable
  protected Integer height;

  /**
   * Bytes of the file as stored — after an image was re-encoded, so what a download returns, not
   * what was uploaded. Null until known: a row written by a release that did not record it, or
   * whose file is not uploaded yet, is filled in by {@code AssetSizeBackfill}. docs/LEDGER_*.md
   * API-7.
   */
  @Column(name = "file_size")
  @Nullable
  protected Long fileSize;

  /**
   * Set to the new file id when the content of the asset was replaced in place (a track edit
   * rewrites the route's GPX and FIT files under the same asset row), null otherwise. GPS sync
   * fingerprints use {@code coalesce(contentRevision, id)}, so existing rows keep their hash and
   * only a real content change re-pushes. docs/LEDGER_*.md API-128.
   */
  @Column(name = "content_revision")
  @Nullable
  protected Long contentRevision;

  @Column(name = "sort_order", nullable = false)
  private int sortOrder = 0;

  /**
   * The stored file was uploaded before storage re-encoded images to remove their metadata, and
   * still has to go through {@code AssetMetadataBackfill}. Always false for a new asset: storage
   * re-encodes on write. docs/LEDGER_*.md API-43.
   */
  @Column(name = "metadata_pending", nullable = false)
  private boolean metadataPending = false;

  public Asset(
      User createdBy, Team team, AssetType type, Long fileId, String fileName, String contentType) {
    super(createdBy);
    this.team = team;
    this.type = type;
    this.fileId = fileId;
    this.fileName = fileName;
    this.contentType = contentType;
  }
}
