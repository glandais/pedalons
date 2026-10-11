package fr.pedalons.repository.user;

import fr.pedalons.domain.user.UserExport;
import fr.pedalons.enums.UserExportStatus;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class UserExportRepository implements PanacheRepository<UserExport> {

  /** The user's most recent request, whatever its status — drives both cooldown and UI state. */
  public Optional<UserExport> findLatestByUser(Long userId) {
    return find("user.id = ?1 order by requestedAt desc", userId).firstResultOptional();
  }

  /** A job by id, scoped to its owner: another user's job must 404, not 403. */
  public Optional<UserExport> findByIdAndUser(Long id, Long userId) {
    return find("id = ?1 and user.id = ?2", id, userId).firstResultOptional();
  }

  public boolean hasInFlight(Long userId) {
    return count(
            "user.id = ?1 and status in ?2",
            userId,
            List.of(UserExportStatus.PENDING, UserExportStatus.PROCESSING))
        > 0;
  }

  /**
   * Head of the queue, locked for this transaction.
   *
   * <p>{@code skip locked} is the throughput half of the claim: it stops a second worker from
   * picking a row someone else already holds and then burning a lock wait to discover it lost. The
   * correctness half is the compare-and-set in {@link #claim}.
   */
  public @Nullable Long findNextPendingIdSkipLocked() {
    Object id =
        getEntityManager()
            .createNativeQuery(
                """
                select id from user_exports
                where status = 'PENDING'
                order by requested_at
                limit 1
                for update skip locked
                """)
            .getResultStream()
            .findFirst()
            .orElse(null);
    return id == null ? null : ((Number) id).longValue();
  }

  /**
   * Compare-and-set from PENDING to PROCESSING. Returns true if this caller won the row.
   *
   * <p>Under READ COMMITTED a loser blocks on the row lock, re-evaluates {@code status = PENDING}
   * after the winner commits, and updates 0 rows. This — not the {@code skip locked} above — is what
   * makes the claim safe.
   *
   * <p>A bulk update does not bump {@code @Version} unless written {@code versioned update}. That is
   * deliberate: the CAS on {@code status} <em>is</em> the concurrency control, and the row is
   * reloaded in a fresh transaction afterwards, so no stale managed instance can exist.
   */
  public boolean claim(Long id, Instant now) {
    return update(
            "status = ?1, startedAt = ?2, attempts = attempts + 1 where id = ?3 and status = ?4",
            UserExportStatus.PROCESSING,
            now,
            id,
            UserExportStatus.PENDING)
        == 1;
  }

  /**
   * Resolves a download token, scoped to a domain and to a live user.
   *
   * <p>The value matched is a SHA-256 digest, never the secret, so there is no timing oracle worth
   * having — the same argument that already justifies {@code
   * AuthSessionRepository.findByRefreshTokenHash}. The domain filter is redundant for correctness
   * (the hash is globally unique) and there so a leaked link cannot cross a tenant boundary.
   * Expiry is deliberately <em>not</em> in the predicate: the caller checks it, so an
   * expired-but-not-yet-swept row still 404s.
   */
  public Optional<UserExport> findDownloadableByTokenHash(Long domainId, String tokenHash) {
    return find(
            "domain.id = ?1 and downloadTokenHash = ?2 and status = ?3 and user.deleted = false",
            domainId,
            tokenHash,
            UserExportStatus.READY)
        .firstResultOptional();
  }

  /** READY exports past their expiry, for the retention sweep. */
  public List<UserExport> findExpired(Instant now) {
    return list("status = ?1 and expiresAt < ?2", UserExportStatus.READY, now);
  }

  /**
   * Jobs claimed but never finished — a crash between claim and completion. Left alone they would
   * block the user forever via the partial unique index on in-flight rows.
   */
  public List<UserExport> findStuck(Instant startedBefore) {
    return list("status = ?1 and startedAt < ?2", UserExportStatus.PROCESSING, startedBefore);
  }

  /** READY exports whose "your export is ready" email never went out. */
  public List<UserExport> findWithUnsentEmail() {
    return list("status = ?1 and emailSentAt is null", UserExportStatus.READY);
  }

  /**
   * READY exports owed their email that a retry may take over: either the last send failed and said
   * so ({@code errorMessage} set), or the current link was minted before the grace cutoff — a worker
   * that died mid-send. A link just minted with no recorded failure is a mail still in flight on
   * some instance (another replica during a rolling deploy); minting a new one would kill the link
   * that mail carries (docs/LEDGER_*.md API-96).
   *
   * <p>The mint time is not stored: it is {@code expiresAt - expiryDays}, since both {@code
   * markReady} and a retry set {@code expiresAt = now + expiryDays}. The caller therefore passes
   * {@code mintedBefore + expiryDays} as {@code expiresBefore}.
   */
  public List<UserExport> findEmailRetryDue(Instant expiresBefore) {
    return list(
        "status = ?1 and emailSentAt is null and (errorMessage is not null or expiresAt < ?2)",
        UserExportStatus.READY,
        expiresBefore);
  }

  /**
   * Compare-and-set that hands an export's email to the caller: replaces the link and clears the
   * recorded failure, only while the row still matches {@link #findEmailRetryDue}. Returns true if
   * this caller won it.
   *
   * <p>Same reasoning as {@link #claim}: a concurrent retrier blocks on the row lock, re-evaluates
   * the predicate once the winner commits — {@code errorMessage} now null, {@code expiresAt} fresh —
   * and updates 0 rows, so it neither supersedes the winner's link nor sends a second mail.
   */
  public boolean claimEmailRetry(
      Long id, String tokenHash, Instant expiresAt, Instant expiresBefore) {
    return update(
            "downloadTokenHash = ?1, expiresAt = ?2, errorMessage = null where id = ?3 and status ="
                + " ?4 and emailSentAt is null and (errorMessage is not null or expiresAt < ?5)",
            tokenHash,
            expiresAt,
            id,
            UserExportStatus.READY,
            expiresBefore)
        == 1;
  }

  /** Hard-deletes long-finished rows; the S3 objects are already gone by then. */
  public long deleteOlderThan(Instant cutoff) {
    return delete(
        "requestedAt < ?1 and status in ?2",
        cutoff,
        List.of(UserExportStatus.EXPIRED, UserExportStatus.FAILED));
  }
}
