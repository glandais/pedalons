package fr.pedalons.domain.common;

import fr.pedalons.domain.user.User;
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
@MappedSuperclass
@NoArgsConstructor
public abstract class BaseEntity {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "created_by_id", nullable = false)
  protected User createdBy;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt = Instant.now();

  @Version private Long version = 0L;

  public BaseEntity(@Nullable User createdBy) {
    if (createdBy != null) {
      this.createdBy = createdBy;
    }
  }

  @Override
  public final boolean equals(Object o) {
    if (this == o) return true;
    if (o == null) return false;
    Class<?> oEffectiveClass = Hibernate.getClassLazy(o);
    Class<?> thisEffectiveClass = Hibernate.getClassLazy(this);
    if (thisEffectiveClass != oEffectiveClass) return false;
    BaseEntity baseEntity = (BaseEntity) o;
    return getId() != null && Objects.equals(getId(), baseEntity.getId());
  }

  @Override
  public final int hashCode() {
    return Hibernate.getClassLazy(this).hashCode();
  }
}
