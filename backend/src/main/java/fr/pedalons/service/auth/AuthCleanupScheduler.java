package fr.pedalons.service.auth;

import fr.pedalons.common.Crons;
import fr.pedalons.repository.auth.AuthFailureRepository;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.repository.auth.AuthTokenRepository;
import fr.pedalons.repository.auth.DeviceCodeRepository;
import fr.pedalons.repository.auth.OAuthAuthorizationCodeRepository;
import fr.pedalons.repository.auth.WebAuthnChallengeRepository;
import fr.pedalons.repository.calendar.CalendarTokenRepository;
import fr.pedalons.repository.gps.GpsOAuthStateRepository;
import fr.pedalons.service.calendar.CalendarService;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import java.time.Duration;
import java.time.Instant;
import org.jboss.logging.Logger;

/**
 * Scheduled job to clean up expired auth sessions and tokens.
 *
 * <p>Runs daily at 3 AM to remove:
 *
 * <ul>
 *   <li>Expired or revoked auth sessions
 *   <li>Expired or used auth tokens (email verification, OTP)
 *   <li>Expired GPS OAuth states
 *   <li>Expired device pairing codes (Karoo, Garmin) and WebAuthn challenges — the privacy policy
 *       (§6) announces them as deleted, not merely unusable
 *   <li>Expired OAuth authorization codes, which an application never came to exchange
 *       (docs/LEDGER_*.md API-199)
 *   <li>Failed password and pairing-code attempts older than a day: the throttle reads at most the
 *       last quarter of an hour (docs/LEDGER_*.md SEC-4, SEC-7)
 *   <li>Calendar feed tokens silent past their inactivity limit: refused already, the privacy
 *       policy (§6) announces them as deleted (docs/LEDGER_*.md SEC-17)
 * </ul>
 */
@ApplicationScoped
public class AuthCleanupScheduler {

  private static final Logger LOG = Logger.getLogger(AuthCleanupScheduler.class);

  @Inject AuthSessionRepository authSessionRepository;
  @Inject AuthTokenRepository authTokenRepository;
  @Inject GpsOAuthStateRepository gpsOAuthStateRepository;
  @Inject DeviceCodeRepository deviceCodeRepository;
  @Inject OAuthAuthorizationCodeRepository oauthAuthorizationCodeRepository;
  @Inject WebAuthnChallengeRepository webAuthnChallengeRepository;
  @Inject AuthFailureRepository authFailureRepository;
  @Inject CalendarTokenRepository calendarTokenRepository;
  @Inject CalendarService calendarService;

  @Scheduled(cron = "0 0 3 * * ?", timeZone = Crons.ZONE) // Every day at 3 AM
  @Transactional
  void cleanupExpiredAuthData() {
    long deletedSessions = authSessionRepository.deleteExpiredSessions();
    long deletedTokens = authTokenRepository.deleteExpiredTokens();
    long deletedGpsStates = gpsOAuthStateRepository.deleteExpiredStates();
    long deletedDeviceCodes = deviceCodeRepository.deleteExpiredCodes();
    long deletedOAuthCodes = oauthAuthorizationCodeRepository.deleteExpiredCodes();
    long deletedChallenges = webAuthnChallengeRepository.deleteExpiredChallenges();
    long deletedFailures =
        authFailureRepository.deleteOlderThan(Instant.now().minus(Duration.ofDays(1)));
    long deletedCalendarTokens =
        calendarTokenRepository.deleteInactiveSince(calendarService.inactivityCutoff());

    if (deletedSessions
            + deletedTokens
            + deletedGpsStates
            + deletedDeviceCodes
            + deletedOAuthCodes
            + deletedChallenges
            + deletedFailures
            + deletedCalendarTokens
        > 0) {
      LOG.infof(
          "Auth cleanup completed: %d sessions, %d tokens, %d GPS OAuth states, %d device codes, %d"
              + " OAuth codes, %d WebAuthn challenges, %d failed attempts, %d calendar tokens"
              + " deleted",
          deletedSessions,
          deletedTokens,
          deletedGpsStates,
          deletedDeviceCodes,
          deletedOAuthCodes,
          deletedChallenges,
          deletedFailures,
          deletedCalendarTokens);
    }
  }
}
