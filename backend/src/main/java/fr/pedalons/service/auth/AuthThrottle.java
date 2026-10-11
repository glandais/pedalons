package fr.pedalons.service.auth;

import fr.pedalons.common.exception.TooManyRequestsException;
import fr.pedalons.domain.auth.AuthFailure;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AuthFailureKind;
import fr.pedalons.repository.auth.AuthFailureRepository;
import io.quarkus.logging.Log;
import io.quarkus.narayana.jta.QuarkusTransaction;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Locale;
import java.util.Optional;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * Refuses a guess at a secret once too many recent guesses failed — before paying for it (audit H5
 * and M4, docs/LEDGER_*.md SEC-4 and SEC-7).
 *
 * <p>Only failures are counted, so nobody who types their password right, or pairs the device in
 * front of them, ever meets the limit. The check comes first and a refused guess records nothing:
 * past the limit, a flood neither costs a bcrypt nor grows the table.
 *
 * <p>An admitted guess is counted as a failure <em>up front</em>, in the same locked step as the
 * check, and taken back when it succeeds (docs/LEDGER_*.md SEC-36). Checking committed failures and
 * recording one only after the bcrypt let every concurrent guess read the same count below the
 * limit — about one guess per pooled connection, not five. The step takes a transaction-scoped
 * advisory lock per budget, released as soon as the row is committed: nobody waits through a
 * bcrypt, and a waiter holds no connection the holder needs. A guess whose request dies midway stays
 * counted, which errs on the side of the limit. During a rolling deploy the previous release still
 * records after the bcrypt, into the same rows: each counts the other's guesses, no migration.
 *
 * <p>Keyed on what the attacker cannot vary for free — the targeted address, the signed-in account,
 * the domain — never on the client IP: the first {@code X-Forwarded-For} hop is whatever the client
 * sent ({@code forwardedHeaders.insecure} on the Traefik entry point), so a per-IP count would stop
 * only the attackers who don't bother to lie. Spreading one password over many addresses (credential
 * stuffing) is therefore not stopped here: that is the global rate limit of audit M10.
 *
 * <p>Failures are written in their own transaction: the caller's rolls back with the error it throws,
 * and would take the count with it. Taking a success back happens in the caller's, so it is undone
 * if the caller fails after all.
 */
@ApplicationScoped
public class AuthThrottle {

  /** The subject of an anonymous pairing-code lookup: counted only in the domain's budget. */
  static final String ANONYMOUS = "-";

  @Inject AuthFailureRepository authFailureRepository;

  /**
   * Wrong passwords an address survives per window. The lock is per address whoever tries, so a
   * stranger can hold someone's password sign-in shut — only that one: the e-mailed code and the
   * passkeys stay open, and the window is short.
   */
  @ConfigProperty(name = "pedalons.auth.password.max-failures", defaultValue = "5")
  int passwordMaxFailures;

  @ConfigProperty(name = "pedalons.auth.password.failure-window-minutes", defaultValue = "15")
  int passwordWindowMinutes;

  /** Unknown pairing codes one signed-in account may submit per window. */
  @ConfigProperty(name = "pedalons.auth.device-code.max-failures-per-user", defaultValue = "5")
  int deviceCodeMaxFailuresPerUser;

  /**
   * Unknown pairing codes the whole domain may submit per window, signed in or not. With 32⁶ codes,
   * 300 guesses find a given pending code once in 3.5 million windows. The price: a flood holds
   * pairing shut for the whole domain until the window slides — a nuisance, where the per-account
   * limit alone let a crowd of throwaway accounts guess without bound.
   */
  @ConfigProperty(name = "pedalons.auth.device-code.max-failures-per-domain", defaultValue = "300")
  int deviceCodeMaxFailuresPerDomain;

  /** The life of a pairing code: a guess can only ever hit a code created in the last window. */
  @ConfigProperty(name = "pedalons.auth.device-code.failure-window-minutes", defaultValue = "10")
  int deviceCodeWindowMinutes;

  /**
   * Throws {@code 429 LOGIN_RATE_LIMITED} once {@code email} has too many recent wrong passwords;
   * otherwise counts this guess as one until {@link #clearPassword} — every outcome but the right
   * password is a failure.
   */
  public void admitPassword(Long domainId, String email) {
    String subject = emailSubject(email);
    Duration window = Duration.ofMinutes(passwordWindowMinutes);
    Instant since = Instant.now().minus(window);
    boolean admitted =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  lock(domainId, AuthFailureKind.PASSWORD, subject);
                  if (authFailureRepository.countSince(
                          domainId, AuthFailureKind.PASSWORD, subject, since)
                      >= passwordMaxFailures) {
                    return false;
                  }
                  authFailureRepository.persist(
                      new AuthFailure(domainId, AuthFailureKind.PASSWORD, subject));
                  return true;
                });
    if (!admitted) {
      Log.warnf("Password sign-in throttled domain=%d subject=%s", domainId, subject);
      throw new TooManyRequestsException(ErrorCode.LOGIN_RATE_LIMITED, window.toSeconds());
    }
  }

  /**
   * A right password wipes the slate: the failures before it were the owner's typos, and the guess
   * {@link #admitPassword} counted was this one.
   */
  public void clearPassword(Long domainId, String email) {
    authFailureRepository.deleteBySubject(domainId, AuthFailureKind.PASSWORD, emailSubject(email));
  }

  /**
   * Throws {@code 429 DEVICE_CODE_RATE_LIMITED} once the domain, or {@code userId} when signed in,
   * has too many recent unknown pairing codes; otherwise counts this guess as one, until the caller
   * hands the returned id to {@link #forgetDeviceCode} because the code was known.
   *
   * <p>One lock per domain covers both budgets, since every guess draws on the domain's; it is held
   * for two counts and an insert.
   *
   * @param userId null for an anonymous lookup, which only the domain's budget bounds
   * @return the id of the failure counted for this guess
   */
  public Long admitDeviceCode(Long domainId, @Nullable Long userId) {
    Duration window = Duration.ofMinutes(deviceCodeWindowMinutes);
    Instant since = Instant.now().minus(window);
    String subject = userId == null ? ANONYMOUS : userId.toString();
    Optional<Long> admitted =
        QuarkusTransaction.requiringNew()
            .call(
                () -> {
                  lock(domainId, AuthFailureKind.DEVICE_CODE, "");
                  boolean userOver =
                      userId != null
                          && authFailureRepository.countSince(
                                  domainId, AuthFailureKind.DEVICE_CODE, subject, since)
                              >= deviceCodeMaxFailuresPerUser;
                  boolean domainOver =
                      !userOver
                          && authFailureRepository.countSince(
                                  domainId, AuthFailureKind.DEVICE_CODE, since)
                              >= deviceCodeMaxFailuresPerDomain;
                  if (userOver || domainOver) {
                    Log.warnf(
                        "Device pairing throttled domain=%d user=%s scope=%s",
                        domainId, userId, userOver ? "user" : "domain");
                    return Optional.<Long>empty();
                  }
                  AuthFailure guess =
                      new AuthFailure(domainId, AuthFailureKind.DEVICE_CODE, subject);
                  authFailureRepository.persist(guess);
                  return Optional.of(guess.getId());
                });
    return admitted.orElseThrow(
        () -> new TooManyRequestsException(ErrorCode.DEVICE_CODE_RATE_LIMITED, window.toSeconds()));
  }

  /** The code {@link #admitDeviceCode} counted was known: that guess failed nothing. */
  public void forgetDeviceCode(Long guessId) {
    authFailureRepository.deleteById(guessId);
  }

  /**
   * Serialises the count and the insert of one budget (docs/LEDGER_*.md SEC-36), across backends:
   * the lock lives as long as the {@code requiringNew} transaction that counts and records.
   */
  private void lock(Long domainId, AuthFailureKind kind, String subject) {
    authFailureRepository.lockUntilEndOfTransaction(
        "auth_failures:" + domainId + ":" + kind + ":" + subject);
  }

  /**
   * The address as the counter knows it: case-folded, so {@code Alice@} and {@code alice@} share
   * one budget, and hashed, so the table holds no address in clear.
   */
  static String emailSubject(String email) {
    try {
      byte[] hash =
          MessageDigest.getInstance("SHA-256")
              .digest(email.strip().toLowerCase(Locale.ROOT).getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(hash);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 not available", e);
    }
  }
}
