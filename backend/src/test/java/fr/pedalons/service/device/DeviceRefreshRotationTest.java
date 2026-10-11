package fr.pedalons.service.device;

import static fr.pedalons.common.TokenUtils.hashToken;
import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.device.response.DeviceTokenResponse;
import fr.pedalons.repository.auth.AuthSessionRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * A GPS device's refresh token rotates like the site's and the app's (audit M7 and M9,
 * docs/LEDGER_*.md SEC-11), and its access token lives 15 minutes.
 */
@QuarkusTest
class DeviceRefreshRotationTest extends AbstractBaseTest {

  @Inject DeviceAuthService deviceAuthService;
  @Inject AuthSessionRepository authSessionRepository;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domainResolver.setDomainForTest(dataService.getOrCreateDefaultDomain());
  }

  @Test
  void refresh_rotatesTheDevicesRefreshToken() {
    User user = dataService.createVerifiedUser("karoo@example.com", "Karoo User");
    String first = dataService.createRefreshTokenForUser(user);

    DeviceTokenResponse response = deviceAuthService.refreshToken(first, "karoo");

    assertNotNull(response.refreshToken());
    assertNotEquals(first, response.refreshToken());
    assertEquals(15 * 60, response.expiresIn());
    assertNotNull(deviceAuthService.refreshToken(response.refreshToken(), "karoo").refreshToken());
  }

  @Test
  void refresh_previousTokenWithinTheGrace_refreshesWithoutANewToken() {
    User user = dataService.createVerifiedUser("garmin@example.com", "Garmin User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = deviceAuthService.refreshToken(first, "garmin").refreshToken();

    DeviceTokenResponse late = deviceAuthService.refreshToken(first, "garmin");

    assertNotNull(late.accessToken());
    assertNull(late.refreshToken());
    assertNotNull(deviceAuthService.refreshToken(second, "garmin").refreshToken());
  }

  @Test
  void refresh_previousTokenAfterTheGrace_rotatesAgainFromIt() {
    User user = dataService.createVerifiedUser("replay@example.com", "Replay User");
    String first = dataService.createRefreshTokenForUser(user);
    String second = deviceAuthService.refreshToken(first, "karoo").refreshToken();
    QuarkusTransaction.requiringNew()
        .run(
            () ->
                authSessionRepository.update(
                    "rotatedAt = ?1 where previousRefreshTokenHash = ?2",
                    Instant.now().minus(Duration.ofMinutes(5)),
                    hashToken(first)));

    // The response that carried the second token was lost (docs/LEDGER_*.md API-94): the device
    // stays paired, on a third token; the second is dead.
    String third = deviceAuthService.refreshToken(first, "karoo").refreshToken();
    assertNotNull(third);
    assertNotEquals(second, third);
    assertThrows(BadRequestException.class, () -> deviceAuthService.refreshToken(second, "karoo"));
    assertNotNull(deviceAuthService.refreshToken(third, "karoo").refreshToken());
  }
}
