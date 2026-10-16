package fr.pedalons.service.config;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.platform.DomainAlias;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.config.ConfigDto;
import fr.pedalons.enums.Visibility;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

@QuarkusTest
class ConfigServiceTest extends AbstractBaseTest {

  @Inject ConfigService configService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject DomainResolver domainResolver;

  private Domain domain;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
  }

  @Test
  void getConfig_shouldReturnConfigDto() {
    ConfigDto config = configService.getConfig();

    assertNotNull(config);
    assertNotNull(config.webAuthnRpId());
    assertNotNull(config.appName());
  }

  /**
   * The flag of pedalons.gps-sync.enabled (GPS_SYNC_ENABLED, off by default in production — the
   * clients then show no switch, API-120), which the test profile turns on.
   */
  @Test
  void getConfig_gpsAutoSyncReflectsTheFlag() {
    assertTrue(configService.getConfig().gpsAutoSyncEnabled());
  }

  @Test
  void getConfig_onRegularDomain_hasNoPinnedTeamAndReflectsDomain() {
    ConfigDto config = configService.getConfig();

    assertEquals(domain.getDomain(), config.webAuthnRpId());
    assertEquals(domain.getName(), config.appName());
    assertFalse(config.singleTeam());
    assertNull(config.pinnedTeamSlug());
  }

  @Test
  void getConfig_onAlias_isSingleTeamAndReturnsPinnedTeamSlugAndAliasBranding() {
    User user = dataService.createUser("owner@example.com", "Owner");
    Team team = dataService.createTeam(user, "My Team", "my-team", Visibility.PUBLIC);
    DomainAlias alias =
        dataService.createDomainAlias(
            "myteam.localhost", domain, team, "My Team Site", "http://myteam.localhost");
    domainResolver.setAliasForTest(alias);

    ConfigDto config = configService.getConfig();

    assertTrue(config.singleTeam());
    assertEquals("myteam.localhost", config.webAuthnRpId());
    assertEquals("My Team Site", config.appName());
    assertEquals("my-team", config.pinnedTeamSlug());
  }

  @Test
  void getConfig_onAliasWithSoftDeletedPinnedTeam_fallsBackToNoPinnedSlug() {
    User user = dataService.createUser("owner@example.com", "Owner");
    Team team = dataService.createTeam(user, "Gone Team", "gone-team", Visibility.PUBLIC);
    DomainAlias alias =
        dataService.createDomainAlias(
            "gone.localhost", domain, team, "Gone Site", "http://gone.localhost");
    dataService.softDeleteTeam(team);
    domainResolver.setAliasForTest(alias);

    ConfigDto config = configService.getConfig();

    // Still single-team mode (alias), but the pinned team no longer resolves.
    assertTrue(config.singleTeam());
    assertNull(config.pinnedTeamSlug());
  }

  @Test
  void getConfig_withoutPushChannel_offersNoWebPush() {
    // The test profile configures no FCM service account: a browser must not be told to subscribe
    // to a channel that could never send it anything.
    assertNull(configService.getConfig().webPush());
  }

  @Test
  void getConfig_withoutCountPath_offersNoAnalytics() {
    // The test profile sets no PEDALONS_ANALYTICS_COUNT_PATH, like dev, a workstation and e2e: the
    // site must count nothing (docs/LEDGER_*.md API-117).
    assertNull(configService.getConfig().analytics());
  }

  @Test
  void analytics_isNullWhenAbsentOrBlank() {
    assertNull(ConfigService.analytics(Optional.empty()));
    assertNull(ConfigService.analytics(Optional.of("")));
    assertNull(ConfigService.analytics(Optional.of("   ")));
  }

  @Test
  void analytics_carriesTheTrimmedSameOriginPath() {
    assertEquals("/count", ConfigService.analytics(Optional.of("/count")).countPath());
    assertEquals("/count", ConfigService.analytics(Optional.of(" /count ")).countPath());
  }

  @Test
  void analytics_refusesAPathThatWouldLeaveTheOrigin() {
    // A full or protocol-relative URL would send every page view to the host it names.
    assertNull(ConfigService.analytics(Optional.of("https://stats.example.com/count")));
    assertNull(ConfigService.analytics(Optional.of("//stats.example.com/count")));
    assertNull(ConfigService.analytics(Optional.of("count")));
    // Browsers read a backslash as a slash and drop tabs and newlines inside a URL.
    assertNull(ConfigService.analytics(Optional.of("/\\evil.example/count")));
    assertNull(ConfigService.analytics(Optional.of("/\t/evil.example/count")));
    assertNull(ConfigService.analytics(Optional.of("/\n/evil.example/count")));
    assertNull(ConfigService.analytics(Optional.of("/count?x=1")));
    assertNull(ConfigService.analytics(Optional.of("/")));
  }
}
