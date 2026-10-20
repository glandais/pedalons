package fr.pedalons.domain.platform;

import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.Objects;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.Hibernate;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

@Setter
@Getter
@Entity
@Table(
    name = "domains",
    indexes = {@Index(columnList = "domain, active, deleted")})
@NoArgsConstructor
public class Domain {

  @Id @Tsid private Long id;

  @Column(name = "domain", nullable = false, unique = true, length = 250)
  private String domain;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  @Column(name = "base_url", nullable = false, length = 500)
  private String baseUrl;

  @Column(name = "single_team", nullable = false)
  private boolean singleTeam = false;

  @Column(name = "android_fingerprints", length = 1000)
  @Nullable
  private String androidFingerprints;

  /**
   * Whether the interactive planner is open in the team-independent GPX tools. Off by default and
   * platform-admin only; uploading a .gpx to the tools stays available when it is false.
   */
  @Column(name = "enable_gpx_planner", nullable = false)
  private boolean enableGpxPlanner = false;

  @Column(name = "active", nullable = false)
  private boolean active = true;

  @Column(name = "deleted", nullable = false)
  private boolean deleted = false;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt = Instant.now();

  @Version private Long version = 0L;

  public Domain(String domain, String name, String baseUrl) {
    this.domain = domain;
    this.name = name;
    this.baseUrl = baseUrl;
  }

  @Override
  public final boolean equals(Object o) {
    if (this == o) return true;
    if (o == null) return false;
    Class<?> oEffectiveClass = Hibernate.getClassLazy(o);
    Class<?> thisEffectiveClass = Hibernate.getClassLazy(this);
    if (thisEffectiveClass != oEffectiveClass) return false;
    Domain domain = (Domain) o;
    return getId() != null && Objects.equals(getId(), domain.getId());
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClassLazy(this).hashCode();
  }
}
