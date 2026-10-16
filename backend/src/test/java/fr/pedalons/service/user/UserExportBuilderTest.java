package fr.pedalons.service.user;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.notification.Notification;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.ride.Ride;
import fr.pedalons.domain.ride.RideGroup;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.GpsServiceType;
import fr.pedalons.enums.NotificationChannel;
import fr.pedalons.enums.NotificationType;
import fr.pedalons.enums.PushPlatform;
import fr.pedalons.enums.ReportReason;
import fr.pedalons.enums.ReportTargetType;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.NotificationTestData;
import fr.pedalons.util.PushDeviceTestData;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * The redaction suite.
 *
 * <p>Every secret the fixture plants is asserted absent from the whole archive by raw substring
 * search. That is blunt on purpose: it keeps working when somebody adds a field to an export record
 * later, which is exactly the change most likely to leak something.
 */
@QuarkusTest
class UserExportBuilderTest extends AbstractBaseTest {

  private static final String REFRESH_TOKEN_HASH = "REFRESH-HASH-SHOULD-NOT-APPEAR";
  private static final String CALENDAR_TOKEN = "CALENDAR-TOKEN-SHOULD-NOT-APPEAR";
  private static final String OAUTH_STATE = "OAUTH-STATE-SHOULD-NOT-APPEAR";
  private static final String PASSWORD_HASH = "PASSWORD-HASH-SHOULD-NOT-APPEAR";
  private static final String PUSH_TOKEN = "PUSH-TOKEN-SHOULD-NOT-APPEAR";

  /** Every JSON section the export promises. Asserting the exact set makes an omission fail here. */
  private static final Set<String> EXPECTED_JSON_ENTRIES =
      Set.of(
          "README.txt",
          "manifest.json",
          "account/profile.json",
          "account/sessions.json",
          "account/passkeys.json",
          "account/calendar-token.json",
          "account/gps-connections.json",
          "account/gps-route-syncs.json",
          "account/auth-tokens.json",
          "account/device-codes.json",
          "account/oauth-states.json",
          "account/notification-preferences.json",
          "account/notification-settings.json",
          "account/push-devices.json",
          "account/blocked-users.json",
          "account/reports.json",
          "account/feedback.json",
          "memberships/teams.json",
          "participations/rides.json",
          "participations/trips.json",
          "notifications/inbox.json",
          "content/teams.json",
          "content/publications.json",
          "content/trip-stages.json",
          "content/routes.json",
          "content/ads.json",
          "content/team-pages.json",
          "content/places.json",
          "content/comments.json",
          "content/ride-groups.json",
          "content/ride-templates.json",
          "content/gpx-previews.json",
          "content/assets.json");

  @Inject UserExportBuilder builder;
  @Inject StorageService storageService;
  @Inject PedalonsQueryContext context;
  @Inject DomainResolver domainResolver;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject NotificationTestData notifications;
  @Inject PushDeviceTestData pushDevices;

  private Domain domain;
  private User user;
  private ExportJobContext ctx;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    user = dataService.createUser(domain, "owner@example.com", "Owner");
    context.setUserForTest(user);
    ctx =
        new ExportJobContext(
            1L,
            "test-export",
            user.getId(),
            TsidUtils.toString(user.getId()),
            domain.getId(),
            user.getEmail(),
            user.getDisplayName(),
            domain.getBaseUrl(),
            domain.getName(),
            "fr",
            null);
  }

  @Test
  void build_shouldWriteEverySection() throws IOException {
    Path zip = builder.build(ctx);
    try {
      Set<String> names = ZipReader.entryNames(zip);
      assertTrue(
          names.containsAll(EXPECTED_JSON_ENTRIES),
          "missing sections: " + difference(EXPECTED_JSON_ENTRIES, names));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  /**
   * Jackson closes the stream it writes to by default, which would kill the ZIP after the first
   * entry. Several JSON entries surviving is the assertion that the shield stream still works.
   */
  @Test
  void build_shouldKeepTheZipOpenAcrossEveryJsonEntry() throws IOException {
    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      assertTrue(entries.size() > 20, "expected many entries, got " + entries.size());
      // The last-written entry proves nothing closed the stream early.
      assertTrue(entries.containsKey("manifest.json"));
      assertTrue(ZipReader.text(entries, "manifest.json").contains("generatedAt"));
      assertTrue(ZipReader.text(entries, "account/profile.json").contains("owner@example.com"));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldNotLeakAnyCredentialMaterial() throws IOException {
    seedSecrets();

    Path zip = builder.build(ctx);
    try {
      String everything = ZipReader.allText(ZipReader.readAll(zip));

      assertFalse(everything.contains(REFRESH_TOKEN_HASH), "session refresh hash leaked");
      assertFalse(everything.contains(CALENDAR_TOKEN), "calendar token leaked");
      assertFalse(everything.contains(OAUTH_STATE), "OAuth state leaked");
      assertFalse(everything.contains(PASSWORD_HASH), "password hash leaked");
      assertFalse(everything.contains(PUSH_TOKEN), "push token leaked");

      // The surrounding metadata must still be there, or the redaction went too far.
      String sessions = ZipReader.text(ZipReader.readAll(zip), "account/sessions.json");
      assertTrue(sessions.contains("expiresAt"), "session metadata should still be exported");
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldIncludeUploadedFiles() throws IOException {
    Team team = dataService.createTeam(domain, user, "Team", "team", Visibility.PUBLIC);
    Asset asset = dataService.createAsset(team, user, AssetType.IMAGE, "photo.jpg");

    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      String path = "files/assets/" + TsidUtils.toString(asset.getId()) + "/photo.jpg";
      assertTrue(entries.containsKey(path), "missing " + path + " in " + entries.keySet());
      assertEquals(
          "test content for photo.jpg", new String(entries.get(path), StandardCharsets.UTF_8));
      // The index must point at the same path the bytes landed on.
      assertTrue(ZipReader.text(entries, "content/assets.json").contains(path));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  /** A vanished storage object must degrade to a note in the manifest, never fail the export. */
  @Test
  void build_withAMissingStorageObject_shouldRecordItAndCarryOn() throws IOException {
    Team team = dataService.createTeam(domain, user, "Team", "team", Visibility.PUBLIC);
    Asset asset = dataService.createAsset(team, user, AssetType.IMAGE, "gone.jpg");
    // Delete the bytes but leave the row, i.e. what an interrupted cleanup leaves behind.
    storageService.delete(assetKey(team, asset));

    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      String manifest = ZipReader.text(entries, "manifest.json");
      assertTrue(manifest.contains("missingFiles"));
      assertTrue(
          manifest.contains("gone.jpg"), "manifest should name the missing file: " + manifest);
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldIncludeGpxPreviewMetadata() throws IOException {
    dataService.createGpxPreview(domain, user, UUID.randomUUID());

    Path zip = builder.build(ctx);
    try {
      String previews = ZipReader.text(ZipReader.readAll(zip), "content/gpx-previews.json");
      assertTrue(previews.contains("preview"));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldIncludeAuthoredContentAndParticipations() throws IOException {
    Team team = dataService.createTeam(domain, user, "Team", "team", Visibility.PUBLIC);
    Ride ride = dataService.createRide(team, user, "Sortie du dimanche", "sortie", Instant.now());
    RideGroup group = dataService.createRideGroup(user, ride, "Groupe 1");
    dataService.createParticipation(group, user);
    dataService.createComment(user, ride, "Belle sortie");

    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      assertTrue(ZipReader.text(entries, "content/publications.json").contains("sortie"));
      assertTrue(ZipReader.text(entries, "content/ride-groups.json").contains("Groupe 1"));
      assertTrue(ZipReader.text(entries, "content/comments.json").contains("Belle sortie"));
      assertTrue(ZipReader.text(entries, "participations/rides.json").contains("sortie"));
      assertTrue(ZipReader.text(entries, "memberships/teams.json").contains("team"));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldIncludeTheNotificationInboxWithItsDeliveries() throws IOException {
    Team team = dataService.createTeam(domain, user, "Team", "team", Visibility.PUBLIC);
    List<Notification> inbox = notifications.seedInbox(user, team, 2);
    notifications.seedDelivery(inbox.getFirst(), NotificationChannel.EMAIL);
    notifications.seedPreference(
        user, NotificationType.RIDE_CANCELLED, NotificationChannel.EMAIL, false);
    pushDevices.seed(user, PushPlatform.ANDROID, "some-token");

    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      String exported = ZipReader.text(entries, "notifications/inbox.json");
      assertTrue(exported.contains("Ride 0") && exported.contains("Ride 1"), exported);
      assertTrue(exported.contains("\"channel\" : \"EMAIL\""), exported);
      // The zone the subject's date reads in travels with it (docs/LEDGER_*.md API-60).
      assertTrue(exported.contains("\"subjectTimezone\" : \"Europe/Paris\""), exported);
      assertTrue(
          ZipReader.text(entries, "account/notification-preferences.json")
              .contains("RIDE_CANCELLED"));
      assertTrue(ZipReader.text(entries, "account/push-devices.json").contains("ANDROID"));
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldIncludeBlocksAndReports() throws IOException {
    Team team = dataService.createTeam(domain, user, "Team", "team", Visibility.PUBLIC);
    User other = dataService.createUser(domain, "other@example.com", "Someone Blocked");
    Post post = dataService.createPost(team, other, "Billet", Instant.now(), Visibility.PUBLIC);
    dataService.createBlock(user, other);
    dataService.createReport(
        team, user, ReportTargetType.POST, post.getId(), other, ReportReason.HARASSMENT);

    Path zip = builder.build(ctx);
    try {
      Map<String, byte[]> entries = ZipReader.readAll(zip);
      assertTrue(ZipReader.text(entries, "account/blocked-users.json").contains("Someone Blocked"));
      String reports = ZipReader.text(entries, "account/reports.json");
      assertTrue(reports.contains("HARASSMENT"), reports);
      assertTrue(reports.contains("OPEN"), reports);
      // Someone else's content: the reported text is not part of the reporter's export.
      assertFalse(reports.contains("excerpt"), reports);
    } finally {
      Files.deleteIfExists(zip);
    }
  }

  @Test
  void build_shouldNotLeaveTheTempFileBehindOnFailure() throws IOException {
    // A context pointing at a user that does not exist fails inside the first section.
    ExportJobContext broken =
        new ExportJobContext(
            1L,
            "broken",
            -1L,
            "broken",
            domain.getId(),
            "x@example.com",
            "X",
            "http://x",
            "X",
            "fr",
            null);

    assertThrows(RuntimeException.class, () -> builder.build(broken));

    Path tempDir = Path.of(System.getProperty("java.io.tmpdir"), "pedalons-exports");
    if (Files.exists(tempDir)) {
      try (var files = Files.list(tempDir)) {
        assertTrue(
            files.noneMatch(p -> p.getFileName().toString().startsWith("export-broken-")),
            "a failed build left its temp file behind");
      }
    }
  }

  // ------------------------------------------------------------------ helpers

  private void seedSecrets() {
    dataService.setUserPasswordHash(user, PASSWORD_HASH);
    dataService.createAuthSession(user, REFRESH_TOKEN_HASH, Instant.now().plusSeconds(3600));
    dataService.createCalendarToken(user, CALENDAR_TOKEN);
    dataService.createGpsOAuthState(
        user, OAUTH_STATE, GpsServiceType.HAMMERHEAD, Instant.now().plusSeconds(600));
    pushDevices.seed(user, PushPlatform.IOS, PUSH_TOKEN);
  }

  private String assetKey(Team team, Asset asset) {
    String teamId = TsidUtils.toString(team.getId());
    String fileId = TsidUtils.toString(asset.getFileId());
    return "assets/" + teamId + "/" + fileId.substring(0, 4) + "/" + fileId;
  }

  private static Set<String> difference(Set<String> expected, Set<String> actual) {
    return expected.stream()
        .filter(e -> !actual.contains(e))
        .collect(java.util.stream.Collectors.toSet());
  }
}
