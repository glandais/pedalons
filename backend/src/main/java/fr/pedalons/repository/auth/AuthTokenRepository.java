package fr.pedalons.repository.auth;

import fr.pedalons.domain.auth.AuthToken;
import fr.pedalons.enums.AuthTokenType;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class AuthTokenRepository implements PanacheRepository<AuthToken> {

  public Optional<AuthToken> findValidByTokenHash(String tokenHash) {
    return find("tokenHash = ?1 and usedAt is null and expiresAt > CURRENT_TIMESTAMP", tokenHash)
        .firstResultOptional();
  }

  /** A mailed link's token, on the site it was issued for only. */
  public Optional<AuthToken> findValidByTokenHashAndDomain(String tokenHash, Long domainId) {
    return find(
            "tokenHash = ?1 and domainId = ?2 and usedAt is null and expiresAt > CURRENT_TIMESTAMP",
            tokenHash,
            domainId)
        .firstResultOptional();
  }

  public Optional<AuthToken> findValidByEmailAndType(
      String email, AuthTokenType tokenType, Long domainId) {
    return find(
            "email = ?1 and tokenType = ?2 and domainId = ?3 and usedAt is null and expiresAt >"
                + " CURRENT_TIMESTAMP",
            email,
            tokenType,
            domainId)
        .firstResultOptional();
  }

  /**
   * The newest live code of the address, its row locked ({@code SELECT … FOR UPDATE}) until the
   * transaction ends. Two guesses at the same code then run one after the other: each counts its
   * miss on top of the other's, and one that waited on a guess that burnt the code, or on the
   * owner's login, no longer finds it. Unlocked, a guess that read the row earlier wrote its stale
   * snapshot back last — counter reset, code alive again (docs/LEDGER_*.md SEC-34). Take {@code
   * UserRepository.findByEmailAndDomainForUpdate} first: requesting a code locks the account, then
   * the code.
   */
  public Optional<AuthToken> findValidByEmailAndTypeForUpdate(
      String email, AuthTokenType tokenType, Long domainId) {
    return find(
            "email = ?1 and tokenType = ?2 and domainId = ?3 and usedAt is null and expiresAt >"
                + " CURRENT_TIMESTAMP order by createdAt desc",
            email,
            tokenType,
            domainId)
        .withLock(LockModeType.PESSIMISTIC_WRITE)
        .firstResultOptional();
  }

  public int invalidateByEmailAndType(String email, AuthTokenType tokenType, Long domainId) {
    return update(
        "usedAt = CURRENT_TIMESTAMP where email = ?1 and tokenType = ?2 and domainId = ?3 and"
            + " usedAt is null",
        email,
        tokenType,
        domainId);
  }

  /** Tokens issued to a user on a domain — for the GDPR data export. */
  public List<AuthToken> findByUser(Long domainId, Long userId) {
    return list("user.id = ?2 and domainId = ?1 order by createdAt", domainId, userId);
  }

  public long deleteExpiredTokens() {
    return delete("expiresAt < CURRENT_TIMESTAMP or usedAt is not null");
  }

  /**
   * Counts recent OTP tokens created for a given email within a time window. Used for rate
   * limiting.
   */
  public long countRecentByEmailAndType(
      String email, AuthTokenType tokenType, int minutes, Long domainId) {
    Instant cutoff = Instant.now().minus(minutes, ChronoUnit.MINUTES);
    return count(
        "email = ?1 and tokenType = ?2 and createdAt > ?3 and domainId = ?4",
        email,
        tokenType,
        cutoff,
        domainId);
  }
}
