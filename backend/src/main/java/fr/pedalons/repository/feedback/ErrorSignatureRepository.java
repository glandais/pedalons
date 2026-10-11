package fr.pedalons.repository.feedback;

import fr.pedalons.domain.feedback.ErrorSignature;
import fr.pedalons.enums.ClientPlatform;
import fr.pedalons.enums.GithubSyncStatus;
import io.hypersistence.tsid.TSID;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.LockModeType;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class ErrorSignatureRepository implements PanacheRepository<ErrorSignature> {

  public Optional<ErrorSignature> findByFingerprint(String fingerprint) {
    return find("fingerprint", fingerprint).firstResultOptional();
  }

  /**
   * The signature of this fingerprint, created if needed, and locked for the caller's transaction.
   *
   * <p>Native insert first, like {@code ContentReportRepository.insertIfAbsent}: a lookup followed
   * by a {@code persist} lets two clients reporting the same new error at once both miss, and the
   * second would fail on {@code uk_error_signatures_fingerprint}. The lock then serializes the
   * counter updates of concurrent occurrences.
   */
  public ErrorSignature lockOrCreate(
      String fingerprint, ClientPlatform platform, String title, Instant now) {
    getEntityManager()
        .createNativeQuery(
            """
            insert into error_signatures
              (id, fingerprint, platform, title, first_seen_at, last_seen_at, occurrence_count,
               versions, github_status, github_attempts, issue_closed, versions_at_close)
            values
              (:id, :fingerprint, :platform, :title, :now, :now, 0,
               '[]'::jsonb, :pending, 0, false, '[]'::jsonb)
            on conflict (fingerprint) do nothing
            """)
        .setParameter("id", TSID.Factory.getTsid().toLong())
        .setParameter("fingerprint", fingerprint)
        .setParameter("platform", platform.name())
        .setParameter("title", title)
        .setParameter("now", Timestamp.from(now))
        .setParameter("pending", GithubSyncStatus.PENDING.name())
        .executeUpdate();
    return find("fingerprint", fingerprint).withLock(LockModeType.PESSIMISTIC_WRITE).firstResult();
  }

  /**
   * The signature, locked for the caller's transaction like {@link #lockOrCreate} locks it: the
   * worker's read-modify-writes must not interleave with a concurrent occurrence (docs/LEDGER_*.md
   * ISSUE-9).
   */
  public ErrorSignature lock(Long id) {
    return findById(id, LockModeType.PESSIMISTIC_WRITE);
  }

  /**
   * Leases the signature to the calling worker until {@code until}, unless another one holds an
   * unexpired lease — a conditional update, so of two backends only one wins (docs/LEDGER_*.md
   * ISSUE-8). In its own transaction, committed before the GitHub call.
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

  /** Signatures whose issue is still to open, oldest first. */
  public List<Long> findPendingIds(int limit) {
    return getEntityManager()
        .createQuery(
            "select s.id from ErrorSignature s where s.githubStatus = :pending"
                + " order by s.firstSeenAt asc, s.id asc",
            Long.class)
        .setParameter("pending", GithubSyncStatus.PENDING)
        .setMaxResults(limit)
        .getResultList();
  }

  /** Signatures whose closed issue a newer version reproduced. */
  public List<Long> findRegressionIds() {
    return getEntityManager()
        .createQuery(
            "select s.id from ErrorSignature s where s.githubStatus = :created"
                + " and s.regressionVersion is not null",
            Long.class)
        .setParameter("created", GithubSyncStatus.CREATED)
        .getResultList();
  }

  /** Signatures with an issue, seen again since their last summary. */
  public List<Long> findToSummarizeIds() {
    return getEntityManager()
        .createQuery(
            "select s.id from ErrorSignature s where s.githubStatus = :created"
                + " and s.lastSeenAt > coalesce(s.summarizedUntil, s.githubCreatedAt)",
            Long.class)
        .setParameter("created", GithubSyncStatus.CREATED)
        .getResultList();
  }

  /** Issues opened since {@code since} — the daily cap on new issues. */
  public long countIssuesCreatedSince(Instant since) {
    return count("githubCreatedAt >= ?1", since);
  }
}
