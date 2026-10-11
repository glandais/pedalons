package fr.pedalons.service.auth;

import static fr.pedalons.common.TokenUtils.generateSecureToken;
import static fr.pedalons.common.TokenUtils.hashToken;

import fr.pedalons.domain.auth.AuthSession;
import fr.pedalons.repository.auth.AuthSessionRepository;
import io.quarkus.logging.Log;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.Instant;
import java.util.Optional;
import java.util.function.Consumer;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jspecify.annotations.Nullable;

/**
 * The rotation of a refresh token, shared by the site and the app ({@code AuthService}) and by the
 * GPS devices ({@code DeviceAuthService}) — audit M7, docs/LEDGER_*.md SEC-27 and SEC-11.
 *
 * <p>Every refresh gives a new token and keeps the one presented as the session's previous token.
 * Within {@link #graceSeconds} of the rotation, the previous token still refreshes, without rotating
 * again: that is another tab, the SSR render, an app resuming, whose refresh left with the same token
 * and lost the race — the winner's token is already where the client keeps it.
 *
 * <p>After that grace, the previous token rotates again, from itself. Its successor was never
 * presented (presenting it would have made it the previous token), and the server cannot tell a
 * client whose refresh response was lost — a cellular drop, an app killed mid-request, a Karoo behind
 * its phone's Bluetooth — from a stolen copy. It used to be taken for a replay that revoked the
 * session, which signed an honest client out for one lost response (docs/LEDGER_*.md API-94). The
 * successor it replaces dies there: whoever holds it is refused at their next refresh; and the
 * previous token itself dies as soon as the new one is presented.
 *
 * <p>Nothing here writes the session as an entity: a versioned or whole-row write would fail
 * concurrent refreshes on the optimistic lock, and could resurrect a session revoked meanwhile. Each
 * rotation is one conditional bulk update, so exactly one of two racing refreshes wins it.
 */
@ApplicationScoped
public class RefreshTokenRotation {

  @Inject AuthSessionRepository authSessionRepository;

  /** How long a rotated-out refresh token still refreshes (without rotating again). */
  @ConfigProperty(name = "pedalons.auth.refresh-token.rotation-grace-seconds", defaultValue = "60")
  int graceSeconds;

  /** What a refresh token turned out to be. */
  public enum Outcome {
    /**
     * The session's current token, or its previous one past the grace: rotated, {@link
     * Refresh#nextToken()} is the new one.
     */
    ROTATED,
    /** A token just rotated away, within the grace: refreshes, with no new token. */
    IN_GRACE,
    /** No live session holds it, current or previous. */
    UNKNOWN
  }

  /**
   * @param session the session the token belongs to; null when {@link #outcome()} is UNKNOWN
   * @param nextToken the new token when {@link #outcome()} is ROTATED, else null
   */
  public record Refresh(
      Outcome outcome, @Nullable AuthSession session, @Nullable String nextToken) {}

  /**
   * Resolves {@code presented} and rotates it when it is the session's current token.
   *
   * @param check run on the session before anything is written — it throws when the session may not
   *     be refreshed (expired, another site's)
   */
  public Refresh refresh(String presented, Consumer<AuthSession> check) {
    String presentedHash = hashToken(presented);

    Optional<AuthSession> current = authSessionRepository.findByRefreshTokenHash(presentedHash);
    if (current.isPresent()) {
      AuthSession session = current.get();
      check.accept(session);
      String nextToken = generateSecureToken();
      if (authSessionRepository.rotate(session.getId(), presentedHash, hashToken(nextToken)) == 1) {
        return new Refresh(Outcome.ROTATED, session, nextToken);
      }
      // A concurrent refresh rotated it first: this one is inside that rotation's grace.
      return new Refresh(Outcome.IN_GRACE, session, null);
    }

    Optional<AuthSession> previous =
        authSessionRepository.findByPreviousRefreshTokenHash(presentedHash);
    if (previous.isEmpty()) {
      return new Refresh(Outcome.UNKNOWN, null, null);
    }
    AuthSession session = previous.get();
    check.accept(session);
    Instant rotatedAt = session.getRotatedAt();
    if (rotatedAt != null && Instant.now().isBefore(rotatedAt.plusSeconds(graceSeconds))) {
      authSessionRepository.markUsed(session.getId());
      return new Refresh(Outcome.IN_GRACE, session, null);
    }

    // Past the grace: the response that carried the successor was lost. Rotate again from this
    // token rather than revoke the session (docs/LEDGER_*.md API-94).
    String nextToken = generateSecureToken();
    if (authSessionRepository.rotateFromPrevious(
            session.getId(), presentedHash, session.getRefreshTokenHash(), hashToken(nextToken))
        == 1) {
      Log.infof("Refresh token rotated again from its predecessor: session=%d", session.getId());
      return new Refresh(Outcome.ROTATED, session, nextToken);
    }
    // A concurrent refresh with the same token rotated it first: this one is inside that grace.
    return new Refresh(Outcome.IN_GRACE, session, null);
  }
}
