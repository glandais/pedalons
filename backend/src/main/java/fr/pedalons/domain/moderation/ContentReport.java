package fr.pedalons.domain.moderation;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.ReportReason;
import fr.pedalons.enums.ReportStatus;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.jspecify.annotations.Nullable;

/**
 * A member's report of a comment, a publication, an ad, a route or another member (App Store
 * guideline 1.2).
 *
 * <p>Not a {@code BaseEntity}: its author, the reporter, becomes null when their account is erased,
 * while the report stays as the record of the decision it led to. The target is kept by type and id
 * rather than by foreign key: a comment is hard-deleted when a moderator removes it, and the report
 * must outlive it.
 *
 * <p>Always filed <em>in a team</em>, which decides who moderates it. The reporter is shown to
 * platform administrators only.
 */
@Setter
@Getter
@Entity
@Table(
    name = "content_reports",
    uniqueConstraints = {
      @UniqueConstraint(
          name = "uk_content_reports_reporter_target",
          columnNames = {"reporter_id", "target_type", "target_id"})
    },
    indexes = {
      @Index(name = "idx_content_reports_team_status", columnList = "team_id, status, created_at"),
      @Index(
          name = "idx_content_reports_domain_status",
          columnList = "domain_id, status, created_at"),
      @Index(name = "idx_content_reports_target", columnList = "target_type, target_id"),
      @Index(name = "idx_content_reports_target_user", columnList = "target_user_id")
    })
@NoArgsConstructor
public class ContentReport {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "team_id", nullable = false)
  private Team team;

  /** Null once the reporter's account is erased. */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "reporter_id")
  private @Nullable User reporter;

  @Enumerated(EnumType.STRING)
  @Column(name = "target_type", nullable = false, length = 20)
  private ReportTargetType targetType;

  /** The comment, team entity or user reported. No foreign key: see the class comment. */
  @Column(name = "target_id", nullable = false)
  private Long targetId;

  /** The author of the content, or the member reported: who the moderation is about. */
  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "target_user_id", nullable = false)
  private User targetUser;

  @Enumerated(EnumType.STRING)
  @Column(name = "reason", nullable = false, length = 30)
  private ReportReason reason;

  @Column(name = "message", length = 500)
  private @Nullable String message;

  /** The reported text as it was, so the moderator reads what was reported even if it changed. */
  @Column(name = "excerpt", length = 1000)
  private @Nullable String excerpt;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private ReportStatus status = ReportStatus.OPEN;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "resolved_by_id")
  private @Nullable User resolvedBy;

  @Column(name = "resolved_at")
  private @Nullable Instant resolvedAt;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();

  public ContentReport(
      Domain domain,
      Team team,
      User reporter,
      ReportTargetType targetType,
      Long targetId,
      User targetUser,
      ReportReason reason,
      @Nullable String message,
      @Nullable String excerpt) {
    this.domain = domain;
    this.team = team;
    this.reporter = reporter;
    this.targetType = targetType;
    this.targetId = targetId;
    this.targetUser = targetUser;
    this.reason = reason;
    this.message = message;
    this.excerpt = excerpt;
  }

  public boolean isOpen() {
    return status == ReportStatus.OPEN;
  }
}
