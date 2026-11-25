package fr.pedalons.domain.platform;

import fr.pedalons.domain.team.Team;
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

/**
 * A dedicated hostname (alias) that resolves to an existing parent {@link Domain} while pinning a
 * single {@link Team}. Lets one team be reachable both on the shared multi-tenant host and on its
 * own dedicated site, sharing the same users and content (the parent domain), only changing the
 * presentation (single-team mode + branding).
 */
@Setter
@Getter
@Entity
@Table(
    name = "domain_aliases",
    indexes = {@Index(columnList = "hostname, active, deleted")})
@NoArgsConstructor
public class DomainAlias {

  @Id @Tsid private Long id;

  @Column(name = "hostname", nullable = false, unique = true, length = 250)
  private String hostname;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "pinned_team_id", nullable = false)
  private Team pinnedTeam;

  @Column(name = "name", nullable = false, length = 250)
  private String name;

  @Column(name = "base_url", nullable = false, length = 500)
  private String baseUrl;

  @Column(name = "android_fingerprints", length = 1000)
  @Nullable
  private String androidFingerprints;

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

  public DomainAlias(String hostname, Domain domain, Team pinnedTeam, String name, String baseUrl) {
    this.hostname = hostname;
    this.domain = domain;
    this.pinnedTeam = pinnedTeam;
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
    DomainAlias that = (DomainAlias) o;
    return getId() != null && Objects.equals(getId(), that.getId());
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClassLazy(this).hashCode();
  }
}
