package fr.pedalons.repository.feedback;

import fr.pedalons.domain.feedback.FeedbackReport;
import fr.pedalons.enums.GithubSyncStatus;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;

@ApplicationScoped
public class FeedbackReportRepository implements PanacheRepository<FeedbackReport> {

  /** Reports this member filed since {@code since} — the rate limit. */
  public long countByUserSince(Long userId, Instant since) {
    return count("user.id = ?1 and createdAt >= ?2", userId, since);
  }

  /** The ids of the reports still to publish, oldest first. */
  public List<Long> findPendingIds(int limit) {
    return getEntityManager()
        .createQuery(
            "select f.id from FeedbackReport f where f.githubStatus = :pending"
                + " order by f.createdAt asc, f.id asc",
            Long.class)
        .setParameter("pending", GithubSyncStatus.PENDING)
        .setMaxResults(limit)
        .getResultList();
  }

  /**
   * Leases the report to the calling worker until {@code until}, unless another one holds an
   * unexpired lease — same claim as {@code ErrorSignatureRepository.claim} (docs/LEDGER_*.md
   * ISSUE-8).
   *
   * @return whether the lease was taken
   */
  public boolean claim(Long id, Instant now, Instant until) {
    return update(
            "githubClaimedUntil = ?1 where id = ?2"
                + " and (githubClaimedUntil is null or githubClaimedUntil < ?3)",
            until,
            id,
            now)
        == 1;
  }

  /** Gives back the lease {@link #claim} took, unless it expired and another worker took it. */
  public int release(Long id, Instant until) {
    return update("githubClaimedUntil = null where id = ?1 and githubClaimedUntil = ?2", id, until);
  }

  /** The reports a member filed, for the GDPR export. */
  public List<FeedbackReport> findByUser(Long domainId, Long userId) {
    return list("user.id = ?1 and domain.id = ?2 order by createdAt", userId, domainId);
  }

  public long deleteCreatedBefore(Instant before) {
    return delete("createdAt < ?1", before);
  }
}
