package fr.pedalons.repository.auth;

import fr.pedalons.domain.auth.OAuthAuthorizationCode;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.LockModeType;
import java.util.Optional;

@ApplicationScoped
public class OAuthAuthorizationCodeRepository implements PanacheRepository<OAuthAuthorizationCode> {

  /**
   * The code, its row locked ({@code SELECT … FOR UPDATE}) until the transaction ends: of two
   * exchanges of the same code, the second waits, then finds the row deleted.
   */
  public Optional<OAuthAuthorizationCode> findByCodeHashForUpdate(String codeHash) {
    return find("codeHash", codeHash)
        .withLock(LockModeType.PESSIMISTIC_WRITE)
        .firstResultOptional();
  }

  public long deleteExpiredCodes() {
    return delete("expiresAt < instant");
  }
}
