package fr.pedalons.service.gps;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.endsWith;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.domain.gps.DomainGpsCredential;
import fr.pedalons.domain.gps.GpsServiceConnection;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.gps.response.GpsOAuthUrlResponse;
import fr.pedalons.dto.gps.response.RouteUploadResponse;
import fr.pedalons.enums.GpsConnectReturn;
import fr.pedalons.enums.GpsOAuthVersion;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.infrastructure.gps.GarminOAuth1Client;
import fr.pedalons.infrastructure.gps.RouteMeta;
import fr.pedalons.infrastructure.gps.RouteUploadResult;
import fr.pedalons.infrastructure.security.TokenEncryptionService;
import fr.pedalons.repository.gps.GpsServiceConnectionRepository;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Garmin over OAuth 1.0a, the domain's credential saying so (docs/LEDGER_*.md API-62). Garmin
 * itself is mocked: the three legs and the upload are {@link GarminOAuth1Client}'s, whose signing
 * {@code OAuth1SignerTest} covers.
 */
@QuarkusTest
class GpsServiceOAuth1Test extends AbstractBaseTest {

  private static final String REQUEST_TOKEN = "request-token";
  private static final String REQUEST_SECRET = "request-secret";
  private static final String AUTHORIZE_URL =
      "https://connect.garmin.com/oauthConfirm?oauth_token=" + REQUEST_TOKEN;

  @Inject GpsService gpsService;
  @Inject GpsServiceConnectionRepository connectionRepository;
  @Inject TokenEncryptionService encryptionService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext pedalonsContext;
  @Inject DomainResolver domainResolver;

  @InjectMock GarminOAuth1Client garminOAuth1Client;

  private User user;
  private DomainGpsCredential credential;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    Domain domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createVerifiedUser("garmin1@example.com", "Garmin User");
    credential =
        dataService.createDomainGpsCredential(
            domain,
            GpsServiceType.GARMIN,
            "consumer-key",
            encryptionService.encrypt("consumer-secret"));
    dataService.setDomainGpsCredentialOAuthVersion(credential, GpsOAuthVersion.OAUTH1);

    when(garminOAuth1Client.requestToken(anyString()))
        .thenReturn(new GarminOAuth1Client.Token(REQUEST_TOKEN, REQUEST_SECRET));
    when(garminOAuth1Client.authorizationUrl(REQUEST_TOKEN)).thenReturn(AUTHORIZE_URL);
    when(garminOAuth1Client.accessToken(REQUEST_TOKEN, REQUEST_SECRET, "verifier"))
        .thenReturn(new GarminOAuth1Client.Token("access-token", "access-secret"));
  }

  @Test
  void initiateOAuth_sendsTheUserToGarminWithARequestToken() {
    pedalonsContext.setUserForTest(user);

    GpsOAuthUrlResponse response = gpsService.initiateOAuth(GpsServiceType.GARMIN);

    assertEquals(AUTHORIZE_URL, response.authorizationUrl());
    verify(garminOAuth1Client).requestToken(endsWith("/api/gps/callback/garmin"));
  }

  @Test
  void callback_storesTheAccessTokenAndItsSecret() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);

    gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier");

    GpsServiceConnection connection =
        connectionRepository
            .findByUserAndService(user.getId(), GpsServiceType.GARMIN)
            .orElseThrow();
    assertEquals(GpsOAuthVersion.OAUTH1, connection.oauthVersion());
    assertEquals("access-token", encryptionService.decrypt(connection.getAccessTokenEncrypted()));
    assertEquals(
        "access-secret", encryptionService.decrypt(connection.getAccessTokenSecretEncrypted()));
    assertNull(connection.getRefreshTokenEncrypted());
    assertNull(connection.getTokenExpiresAt());
  }

  @Test
  void callback_isSingleUse() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);
    gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier");

    assertThrows(
        BusinessException.class,
        () -> gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier"));
  }

  @Test
  void returnTarget_isFoundByTheRequestToken() {
    // Garmin sends back no state: the callback looks the return target up by the request token
    // (docs/LEDGER_*.md API-63).
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN, GpsConnectReturn.DEVICE_KAROO);

    assertEquals(GpsConnectReturn.DEVICE_KAROO, gpsService.findReturnTarget(REQUEST_TOKEN));
  }

  @Test
  void returnTarget_defaultsToTheProfile() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);

    assertEquals(GpsConnectReturn.PROFILE, gpsService.findReturnTarget(REQUEST_TOKEN));
  }

  @Test
  void callback_rejectsAnUnknownRequestToken() {
    assertThrows(
        BusinessException.class,
        () -> gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, "unknown", "verifier"));
    verify(garminOAuth1Client, never()).accessToken(anyString(), anyString(), anyString());
  }

  @Test
  void oauth2Callback_rejectsARequestToken() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);

    assertThrows(
        BusinessException.class,
        () -> gpsService.handleCallback(GpsServiceType.GARMIN, "code", REQUEST_TOKEN));
  }

  @Test
  void upload_signsWithTheConnectionsTokenAndSecret() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);
    gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier");
    byte[] gpx = "<gpx/>".getBytes();
    when(garminOAuth1Client.uploadRoute(
            "access-token", "access-secret", gpx, RouteMeta.manual("Route")))
        .thenReturn(RouteUploadResult.success("42"));

    RouteUploadResponse response = gpsService.uploadGpx(GpsServiceType.GARMIN, gpx, "Route");

    assertTrue(response.success());
    assertEquals("42", response.externalRouteId());
  }

  @Test
  void upload_dropsAConnectionMadeOverOAuth2() {
    // An OAuth 2.0 connection (no token secret), from before the domain switched its credential.
    dataService.createGpsServiceConnection(user, GpsServiceType.GARMIN);
    pedalonsContext.setUserForTest(user);

    RouteUploadResponse response =
        gpsService.uploadGpx(GpsServiceType.GARMIN, "<gpx/>".getBytes(), "Route");

    assertFalse(response.success());
    assertTrue(
        connectionRepository.findByUserAndService(user.getId(), GpsServiceType.GARMIN).isEmpty());
    verify(garminOAuth1Client, never())
        .uploadRoute(anyString(), anyString(), any(byte[].class), any(RouteMeta.class));
  }

  @Test
  void initiateOAuth_replacesAConnectionMadeOverOAuth2() {
    dataService.createGpsServiceConnection(user, GpsServiceType.GARMIN);
    pedalonsContext.setUserForTest(user);

    gpsService.initiateOAuth(GpsServiceType.GARMIN);
    gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier");

    GpsServiceConnection connection =
        connectionRepository
            .findByUserAndService(user.getId(), GpsServiceType.GARMIN)
            .orElseThrow();
    assertEquals(GpsOAuthVersion.OAUTH1, connection.oauthVersion());
  }

  @Test
  void initiateOAuth_refusesASecondOAuth1Connection() {
    pedalonsContext.setUserForTest(user);
    gpsService.initiateOAuth(GpsServiceType.GARMIN);
    gpsService.handleOAuth1Callback(GpsServiceType.GARMIN, REQUEST_TOKEN, "verifier");

    assertThrows(BusinessException.class, () -> gpsService.initiateOAuth(GpsServiceType.GARMIN));
  }
}
