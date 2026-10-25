package fr.pedalons.repository.auth;

import fr.pedalons.domain.auth.DeviceCode;
import io.quarkus.hibernate.orm.panache.PanacheRepository;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;

@ApplicationScoped
public class DeviceCodeRepository implements PanacheRepository<DeviceCode> {

  public Optional<DeviceCode> findByDeviceCodeHash(String deviceCodeHash) {
    return find("deviceCodeHash", deviceCodeHash).firstResultOptional();
  }

  public Optional<DeviceCode> findByUserCode(String userCode) {
    return find("userCode", userCode.toUpperCase()).firstResultOptional();
  }

  /** A pending code of {@code domainId}: another domain's code is as unknown as a wrong one. */
  public Optional<DeviceCode> findValidByUserCode(Long domainId, String userCode) {
    return find(
            "domainId = ?1 and userCode = ?2 and expiresAt > instant",
            domainId,
            userCode.toUpperCase())
        .firstResultOptional();
  }

  /**
   * {@link #findValidByUserCode}, the row locked ({@code SELECT … FOR UPDATE}) until the
   * transaction ends: two approvals of the same code then run one after the other, and the second
   * sees the first (docs/LEDGER_*.md AUD-16).
   */
  public Optional<DeviceCode> findValidByUserCodeForUpdate(Long domainId, String userCode) {
    return find(
            "domainId = ?1 and userCode = ?2 and expiresAt > instant",
            domainId,
            userCode.toUpperCase())
        .withLock(LockModeType.PESSIMISTIC_WRITE)
        .firstResultOptional();
  }

  public Optional<DeviceCode> findValidByDeviceCodeHash(String deviceCodeHash) {
    return find("deviceCodeHash = ?1 and expiresAt > instant", deviceCodeHash)
        .firstResultOptional();
  }

  /** Device-flow pairings a user authorized on a domain — for the GDPR data export. */
  public List<DeviceCode> findByUser(Long domainId, Long userId) {
    return list("user.id = ?2 and domainId = ?1 order by createdAt", domainId, userId);
  }

  public long deleteExpiredCodes() {
    return delete("expiresAt < instant");
  }
}
