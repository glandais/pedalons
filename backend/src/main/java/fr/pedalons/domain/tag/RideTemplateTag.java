package fr.pedalons.domain.tag;

import fr.pedalons.domain.ridetemplate.RideTemplate;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

/**
 * A {@code RIDE} tag on a ride template, copied onto each ride created from it (plan D14). Same
 * shape and rules as {@link TeamEntityTag}; the template is hard-deleted, and its links go with it
 * in the database.
 */
@Setter
@Getter
@Entity
@Table(
    name = "ride_template_tags",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_ride_template_tags_template_tag",
          columnNames = {"ride_template_id", "tag_id"})
    },
    indexes = {@Index(name = "idx_ride_template_tags_tag", columnList = "tag_id")})
@NoArgsConstructor
public class RideTemplateTag {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "ride_template_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private RideTemplate rideTemplate;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "tag_id", nullable = false)
  @OnDelete(action = OnDeleteAction.CASCADE)
  private Tag tag;

  public RideTemplateTag(RideTemplate rideTemplate, Tag tag) {
    this.rideTemplate = rideTemplate;
    this.tag = tag;
  }
}
