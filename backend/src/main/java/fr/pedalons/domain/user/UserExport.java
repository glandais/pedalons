package fr.pedalons.domain.user;

import fr.pedalons.domain.platform.Domain;
import fr.pedalons.enums.UserExportStatus;
import fr.pedalons.infrastructure.hibernate.Tsid;
import jakarta.persistence.*;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.jspecify.annotations.Nullable;

/**
 * A self-service GDPR data export (DSAR). The row <em>is</em> the job queue: the request inserts it
 * as {@link UserExportStatus#PENDING} and returns immediately, a scheduler claims it, builds the
 * ZIP outside any transaction, stores it and emails the user a link.
 *
 * <p>Standalone entity (hard delete, no {@code BaseEntity} hierarchy): an export belongs to a domain
 * and a user, never to a team — and {@code BaseEntity.createdBy} would only duplicate {@code user}.
 *
 * <p>{@code downloadTokenHash} holds a SHA-256 of the token, never the token itself. Unlike {@link
 * fr.pedalons.domain.calendar.CalendarToken} — which stores plaintext because the UI has to display
 * it again — this token is written once and lives only inside one email, so there is nothing to
 * display and no reason to keep a recoverable copy.
 *
 * <p>{@code baseUrl}/{@code siteName} are a snapshot of the request's {@code ResolvedSite}, not a
 * lookup on {@link Domain}. The scheduler runs with no HTTP request, so {@code DomainResolver} is
 * unavailable; and for a request that arrived on a domain alias, {@code domains.base_url} is the
 * <em>parent</em> URL, which may not even serve that user a session.
 */
@Setter
@Getter
@Entity
@Table(
    name = "user_exports",
    indexes = {
      @Index(name = "idx_user_exports_user_requested", columnList = "user_id, requested_at"),
      @Index(name = "idx_user_exports_status_requested", columnList = "status, requested_at"),
      @Index(name = "idx_user_exports_expires_at", columnList = "expires_at")
    })
@NoArgsConstructor
public class UserExport {

  @Id @Tsid private Long id;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "domain_id", nullable = false)
  private Domain domain;

  @ManyToOne(fetch = FetchType.LAZY)
  @JoinColumn(name = "user_id", nullable = false)
  private User user;

  @Enumerated(EnumType.STRING)
  @Column(name = "status", nullable = false, length = 20)
  private UserExportStatus status = UserExportStatus.PENDING;

  @Column(name = "requested_at", nullable = false)
  private Instant requestedAt = Instant.now();

  @Column(name = "started_at")
  private @Nullable Instant startedAt;

  @Column(name = "completed_at")
  private @Nullable Instant completedAt;

  @Column(name = "expires_at")
  private @Nullable Instant expiresAt;

  /** Null while the "your export is ready" email is still owed — the retry sweep keys off this. */
  @Column(name = "email_sent_at")
  private @Nullable Instant emailSentAt;

  @Column(name = "storage_key", length = 300)
  private @Nullable String storageKey;

  @Column(name = "file_size")
  private @Nullable Long fileSize;

  /** SHA-256 of the download token, Base64. The plaintext exists only in the email. */
  @Column(name = "download_token_hash", unique = true, length = 100)
  private @Nullable String downloadTokenHash;

  @Column(name = "attempts", nullable = false)
  private int attempts;

  /** Operator diagnostics. Never returned by the API — it can carry internal detail. */
  @Column(name = "error_message", length = 500)
  private @Nullable String errorMessage;

  @Column(name = "base_url", nullable = false, length = 500)
  private String baseUrl;

  @Column(name = "site_name", nullable = false, length = 250)
  private String siteName;

  @Column(name = "language", nullable = false, length = 5)
  private String language;

  @CreationTimestamp
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @UpdateTimestamp
  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version private Long version;

  public UserExport(Domain domain, User user, String baseUrl, String siteName, String language) {
    this.domain = domain;
    this.user = user;
    this.baseUrl = baseUrl;
    this.siteName = siteName;
    this.language = language;
  }

  public boolean isInFlight() {
    return status == UserExportStatus.PENDING || status == UserExportStatus.PROCESSING;
  }
}
