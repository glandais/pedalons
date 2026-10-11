package fr.pedalons.service.asset;

import static org.junit.jupiter.api.Assertions.*;

import fr.pedalons.AbstractBaseTest;
import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.platform.Domain;
import fr.pedalons.domain.post.Post;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.assets.response.DownloadableAsset;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.AssetNotAvailableDetails;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.enums.TeamRole;
import fr.pedalons.enums.Visibility;
import fr.pedalons.infrastructure.image.ImageFormat;
import fr.pedalons.infrastructure.image.TestImages;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.repository.post.PostRepository;
import fr.pedalons.service.asset.response.AssetWithFile;
import fr.pedalons.service.security.DomainResolver;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.util.GpxPrivacyAssertions;
import fr.pedalons.util.TestDataCleaner;
import fr.pedalons.util.TestDataService;
import io.quarkus.narayana.jta.QuarkusTransaction;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

@QuarkusTest
class AssetServiceTest extends AbstractBaseTest {

  @Inject AssetService assetService;
  @Inject TestDataService dataService;
  @Inject TestDataCleaner dataCleaner;
  @Inject PedalonsQueryContext queryContext;
  @Inject DomainResolver domainResolver;
  @Inject StorageService storageService;
  @Inject AssetRepository assetRepository;
  @Inject PostRepository postRepository;

  private Domain domain;
  private Team team;
  private Team privateTeam;
  private User admin;
  private User organizer;
  private User member;
  private User member2;
  private User nonMember;

  @BeforeEach
  void setUp() {
    dataCleaner.cleanAll();
    domain = dataService.getOrCreateDefaultDomain();
    domainResolver.setDomainForTest(domain);
    admin = dataService.createUser("admin@example.com", "Admin");
    team = dataService.createTeam(admin, "Test Team", "test-team", Visibility.PUBLIC);
    privateTeam = dataService.createTeam(admin, "Private Team", "private-team", Visibility.TEAM);
    organizer = dataService.createUser("organizer@example.com", "Organizer");
    member = dataService.createUser("member@example.com", "Member");
    member2 = dataService.createUser("member2@example.com", "Member2");
    nonMember = dataService.createUser("nonmember@example.com", "NonMember");
    dataService.addUserToTeam(organizer, team, TeamRole.ORGANIZER);
    dataService.addUserToTeam(member, team, TeamRole.MEMBER);
    dataService.addUserToTeam(organizer, privateTeam, TeamRole.ORGANIZER);
    dataService.addUserToTeam(member2, privateTeam, TeamRole.MEMBER);
  }

  @AfterEach
  void cleanup() {
    // Clean up any created files
  }

  private static final String SAMPLE_TXT_CONTENT =
      "This is a plain text file used for unit testing the asset upload pipeline.\n"
          + "It contains regular English sentences with normal punctuation,\n"
          + "so that Magika reliably classifies the content as plain text.";

  private InputStream getExampleGpxStream() {
    InputStream resourceAsStream = getClass().getClassLoader().getResourceAsStream("example.gpx");
    assertNotNull(resourceAsStream, "example.gpx not found in test resources");
    return resourceAsStream;
  }

  private InputStream getTestImageStream() {
    InputStream resourceAsStream = getClass().getClassLoader().getResourceAsStream("image.png");
    assertNotNull(resourceAsStream, "image.png not found in test resources");
    return resourceAsStream;
  }

  private byte[] readStored(Asset asset) throws IOException {
    try (InputStream is = storageService.retrieve(getAssetKey(team, asset.getFileId()))) {
      return is.readAllBytes();
    }
  }

  private InputStream getSampleTxtStream() {
    return new ByteArrayInputStream(SAMPLE_TXT_CONTENT.getBytes(StandardCharsets.UTF_8));
  }

  private String getAssetKey(Team t, long fileId) {
    String teamId = TsidUtils.toString(t.getId());
    String idString = TsidUtils.toString(fileId);
    String subPath = idString.substring(0, 4);
    return "assets/" + teamId + "/" + subPath + "/" + idString;
  }

  @Nested
  class CreateAsset {

    @Test
    void shouldCreateAssetForOrganizer() throws Exception {
      InputStream content = getSampleTxtStream();

      queryContext.setUserForTest(organizer);
      AssetDto result =
          assetService.createAsset(team.getSlug(), AssetType.ATTACHMENT, content, "test.txt");

      assertNotNull(result);
      assertNotNull(result.id());
      assertEquals("test.txt", result.fileName());
      assertTrue(result.url().contains("/api/download/"));
    }

    @Test
    void shouldCreateAssetForNonOrganizer() throws IOException {
      InputStream content = getSampleTxtStream();

      queryContext.setUserForTest(member);
      AssetDto result =
          assetService.createAsset(team.getSlug(), AssetType.ATTACHMENT, content, "test.txt");

      assertNotNull(result);
      assertNotNull(result.id());
      assertEquals("test.txt", result.fileName());
      assertTrue(result.url().contains("/api/download/"));
    }
  }

  @Nested
  class AddAssetStream {

    @Test
    void shouldCreateAssetWithContent() throws Exception {
      InputStream content = getSampleTxtStream();

      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(team, AssetType.ATTACHMENT, null, content, "file.txt");

      assertNotNull(result);
      assertNotNull(result.asset());
      assertNotNull(result.file());
      assertEquals("file.txt", result.asset().getFileName());
      // Temp file is deleted after S3 upload when content is provided
      assertFalse(result.file().exists());
      // docs/LEDGER_*.md API-7: recorded on write
      assertEquals(
          storageService.size(getAssetKey(team, result.asset().getFileId())),
          result.asset().getFileSize());
    }

    // docs/LEDGER_*.md API-49, API-55: a track file attached as a plain attachment is cleaned
    // like a route's before it is stored.

    @Test
    void shouldStripClockSensorsAndAuthorFromAnAttachedGpx() throws Exception {
      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(
              team,
              AssetType.ATTACHMENT,
              null,
              Files.newInputStream(GpxPrivacyAssertions.activityGpx()),
              "sortie.gpx");

      assertEquals("application/gpx+xml", result.asset().getContentType());
      String stored = new String(readStored(result.asset()), StandardCharsets.UTF_8);
      GpxPrivacyAssertions.assertGpxHasNoPersonalData(stored);
      assertTrue(stored.contains("<trkpt lat=\"47.20626\" lon=\"-1.54564\">"), "geometry lost");
      // docs/LEDGER_*.md API-7: the recorded size is that of the cleaned file
      assertEquals(
          storageService.size(getAssetKey(team, result.asset().getFileId())),
          result.asset().getFileSize());
    }

    @Test
    void shouldStripClockAndSensorsFromAnAttachedFit() throws Exception {
      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(
              team,
              AssetType.ATTACHMENT,
              null,
              new ByteArrayInputStream(GpxPrivacyAssertions.activityFit()),
              "sortie.fit");

      assertEquals("application/vnd.ant.fit", result.asset().getContentType());
      GpxPrivacyAssertions.assertFitHasNoPersonalData(readStored(result.asset()));
    }

    @Test
    void shouldRefuseAGpxAttachmentThatIsNotAGpx() {
      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () ->
                  assetService.addAssetStream(
                      team, AssetType.ATTACHMENT, null, getSampleTxtStream(), "notes.gpx"));
      assertEquals(ErrorCode.GPX_FAILURE, ex.getErrorCode());
    }

    @Test
    void shouldCreateAssetWithoutContent() throws Exception {
      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(team, AssetType.IMAGE, null, null, "placeholder.png");

      assertNotNull(result);
      assertNotNull(result.asset());
      assertEquals("placeholder.png", result.asset().getFileName());
      // File is created but empty
      assertFalse(result.file().exists());
      // Not uploaded yet: uploadAssetFile records it
      assertNull(result.asset().getFileSize());
    }
  }

  @Nested
  class GetAssetFile {

    @Test
    void shouldReturnCorrectFilePath() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");

      File file = assetService.getAssetFile(asset);

      assertNotNull(file);
      String fileIdString = TsidUtils.toString(asset.getFileId());
      assertTrue(file.getPath().contains(fileIdString.substring(0, 4)));
      assertEquals(fileIdString, file.getName());
    }
  }

  @Nested
  class GetDownloadableAsset {

    @Test
    void shouldReturnAssetForPublicTeam() throws Exception {
      // Create a public post to attach the asset to
      Post publicPost =
          dataService.createPost(team, admin, "Public Post", Instant.now(), Visibility.PUBLIC);
      InputStream content = getExampleGpxStream();
      queryContext.setUserForTest(member);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(
              team, AssetType.ROUTE_ORIGINAL_GPX, publicPost, content, "route.gpx");
      Long assetId = assetWithFile.asset().getId();

      queryContext.setUserForTest(null);
      DownloadableAsset result = assetService.getDownloadableAsset(team.getSlug(), assetId);

      assertNotNull(result);
      assertNotNull(result.content());
      assertEquals("application/gpx+xml", result.contentType());
    }

    @Test
    void shouldDetectContentTypeForPng() throws Exception {
      InputStream content = getTestImageStream();
      queryContext.setUserForTest(organizer);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(team, AssetType.IMAGE, null, content, "image.png");
      Long assetId = assetWithFile.asset().getId();

      queryContext.setUserForTest(organizer);
      DownloadableAsset result = assetService.getDownloadableAsset(team.getSlug(), assetId);

      assertNotNull(result);
      assertEquals("image/png", result.contentType());
    }
  }

  @Nested
  class GetAssetWithSecurity {

    @Test
    void shouldReturnAssetFromPublicTeamWithoutTeamEntity() {
      Asset asset = dataService.createAsset(team, member, AssetType.IMAGE, "test.png");

      queryContext.setUserForTest(member);
      DownloadableAsset result = assetService.getDownloadableAsset(team.getSlug(), asset.getId());

      assertNotNull(result);
    }

    @Test
    void shouldRequireOwnerForPrivateTeamWithoutTeamEntity() {
      Asset asset = dataService.createAsset(privateTeam, member2, AssetType.IMAGE, "test.png");

      // Organizer of private team can access
      queryContext.setUserForTest(member2);
      DownloadableAsset result =
          assetService.getDownloadableAsset(privateTeam.getSlug(), asset.getId());
      assertNotNull(result);

      // Non-member cannot access
      queryContext.setUserForTest(nonMember);
      assertThrows(
          PedalonsException.class,
          () -> assetService.getDownloadableAsset(privateTeam.getSlug(), asset.getId()));
    }

    @Test
    void shouldCheckTeamEntityVisibility() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "post-image.png");
      asset.setTeamEntity(post);
      dataService.updateAsset(asset);

      // Public post asset accessible to anyone
      queryContext.setUserForTest(null);
      DownloadableAsset result = assetService.getDownloadableAsset(team.getSlug(), asset.getId());
      assertNotNull(result);
    }

    @Test
    void shouldThrowForInaccessibleTeamEntity() {
      Post post = dataService.createPost(team, admin, "Team Post", Instant.now(), Visibility.TEAM);
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "post-image.png");
      asset.setTeamEntity(post);
      dataService.updateAsset(asset);

      // Non-member cannot access team-visibility post asset
      queryContext.setUserForTest(nonMember);
      assertThrows(
          PedalonsException.class,
          () -> assetService.getDownloadableAsset(team.getSlug(), asset.getId()));
    }
  }

  @Nested
  class DeleteAsset {

    @Test
    void shouldDeleteFromS3() throws Exception {
      InputStream content = getSampleTxtStream();
      queryContext.setUserForTest(organizer);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(team, AssetType.ATTACHMENT, null, content, "delete-me.txt");
      // Temp file is deleted after S3 upload
      assertFalse(assetWithFile.file().exists());

      queryContext.setUserForTest(organizer);
      // Should not throw - deletes from S3
      assertDoesNotThrow(
          () -> assetService.deleteAsset(team.getSlug(), assetWithFile.asset().getId()));
    }

    @Test
    void shouldHandleNonExistentFile() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "no-file.txt");

      // Should not throw even if file doesn't exist
      queryContext.setUserForTest(admin);
      assertDoesNotThrow(() -> assetService.deleteAsset(team.getSlug(), asset.getId()));
    }

    @Test
    void shouldThrowForNonexistentAsset() {
      queryContext.setUserForTest(organizer);
      assertThrows(
          PedalonsException.class, () -> assetService.deleteAsset(team.getSlug(), 999999L));
    }
  }

  @Nested
  class MapAsset {

    @Test
    void shouldMapAssetWithoutTeamEntity() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertEquals(TsidUtils.toString(asset.getId()), result.id());
      assertEquals("test.png", result.fileName());
      assertTrue(result.url().contains("/team/")); // No teamEntity -> authent
      assertTrue(result.imageUrl().contains("/team/")); // No teamEntity -> authent
    }

    @Test
    void shouldMapAssetWithTeamEntity() {
      Post post = dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.TEAM);
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "post-image.png");
      asset.setTeamEntity(post);
      dataService.updateAsset(asset);

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertTrue(result.url().contains("/team/")); // Post is team-visibility
    }

    @Test
    void shouldIncludeImageUrlForImageAssets() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertNotNull(result.imageUrl(), "imageUrl should be set for image assets");
      assertTrue(result.imageUrl().contains("/images/"));
      assertTrue(result.imageUrl().contains("/{size}"));
    }

    @Test
    void shouldNotIncludeImageUrlForNonImageAssets() throws Exception {
      InputStream content = getExampleGpxStream();
      queryContext.setUserForTest(member);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(
              team, AssetType.ROUTE_ORIGINAL_GPX, null, content, "route.gpx");

      AssetDto result = assetService.map(assetWithFile.asset());

      assertNotNull(result);
      assertNull(result.imageUrl(), "imageUrl should be null for non-image assets");
    }

    @Test
    void shouldIncludeDimensionsWhenAvailable() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");
      asset.setWidth(800);
      asset.setHeight(600);
      dataService.updateAsset(asset);

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertNotNull(
          result.imageDimensions(), "dimensions should be set when width/height available");
      assertEquals(800, result.imageDimensions().width());
      assertEquals(600, result.imageDimensions().height());
    }

    @Test
    void shouldNotIncludeDimensionsWhenNotAvailable() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");
      // No width/height set

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertNull(result.imageDimensions(), "dimensions should be null when not available");
    }

    @Test
    void shouldIncludeContentType() {
      Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "test.png");

      AssetDto result = assetService.map(asset);

      assertNotNull(result);
      assertNotNull(result.contentType());
    }
  }

  @Nested
  class FileTypeValidation {

    private static final String HTML_PAYLOAD =
        "<!DOCTYPE html>\n"
            + "<html>\n"
            + "<head><title>Malicious</title></head>\n"
            + "<body>\n"
            + "<h1>Not an image</h1>\n"
            + "<p>Long enough html content for Magika to identify the type reliably.</p>\n"
            + "<script>alert('xss');</script>\n"
            + "</body>\n"
            + "</html>\n";

    @Test
    void shouldRejectPngForGpxSlot() {
      InputStream pngContent = getTestImageStream();

      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () ->
                  assetService.addAssetStream(
                      team, AssetType.ROUTE_ORIGINAL_GPX, null, pngContent, "fake.png"));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void shouldRejectScriptedContentForImageSlot() {
      InputStream content = new ByteArrayInputStream(HTML_PAYLOAD.getBytes(StandardCharsets.UTF_8));

      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () -> assetService.addAssetStream(team, AssetType.IMAGE, null, content, "evil.png"));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void shouldRejectScriptedContentForAttachmentSlot() {
      InputStream content = new ByteArrayInputStream(HTML_PAYLOAD.getBytes(StandardCharsets.UTF_8));

      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () ->
                  assetService.addAssetStream(
                      team, AssetType.ATTACHMENT, null, content, "evil.html"));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }
  }

  /** docs/LEDGER_*.md API-43: an uploaded photo is stored re-encoded, without its metadata. */
  @Nested
  class MetadataRemoval {

    private byte[] stored(AssetDto dto) throws IOException {
      Asset asset = assetRepository.findById(TsidUtils.toLong(dto.id()));
      try (InputStream in = storageService.retrieve(getAssetKey(team, asset.getFileId()))) {
        return in.readAllBytes();
      }
    }

    private AssetDto upload(AssetType type, String testImage, String fileName) throws IOException {
      return assetService.createAsset(
          team.getSlug(), type, new ByteArrayInputStream(TestImages.load(testImage)), fileName);
    }

    @Test
    void storesAPhotoWithoutItsMetadata() throws IOException {
      queryContext.setUserForTest(member);
      AssetDto dto = upload(AssetType.IMAGE, TestImages.JPEG, "photo.jpg");

      assertFalse(TestImages.contains(stored(dto), TestImages.SECRET), "metadata left in storage");
      assertEquals("image/jpeg", dto.contentType());
      assertEquals("photo.jpg", dto.fileName());
      // docs/LEDGER_*.md API-7: the size of what a download returns, not of what was uploaded
      assertEquals((long) stored(dto).length, dto.size());
      assertNotEquals((long) TestImages.load(TestImages.JPEG).length, dto.size());
      // Rotated upright: the dimensions are those of what is stored
      Asset asset = assetRepository.findById(TsidUtils.toLong(dto.id()));
      assertEquals(20, asset.getWidth());
      assertEquals(40, asset.getHeight());
    }

    @Test
    void reencodesAPhotoUploadedAsAnAttachment() throws IOException {
      queryContext.setUserForTest(member);
      AssetDto dto = upload(AssetType.ATTACHMENT, TestImages.PNG, "scan.png");

      assertFalse(TestImages.contains(stored(dto), TestImages.SECRET));
      assertEquals("image/png", dto.contentType());
    }

    @Test
    void reencodesWhatAnImporterWritesToTheTempFile() throws IOException {
      // The biketeam import and the thumbnails write a temp file, then call uploadAssetFile
      queryContext.setUserForTest(admin);
      AssetWithFile awf =
          assetService.addAssetStream(team, AssetType.IMAGE, null, null, "imported.heic");
      java.nio.file.Files.write(awf.file().toPath(), TestImages.load(TestImages.HEIC));
      assetService.uploadAssetFile(awf.asset());

      byte[] stored;
      try (InputStream in = assetService.getAssetContent(awf.asset())) {
        stored = in.readAllBytes();
      }
      assertFalse(TestImages.contains(stored, TestImages.SECRET));
      assertEquals("image/jpeg", awf.asset().getContentType());
      assertEquals("imported.jpg", awf.asset().getFileName());
      assertEquals((long) stored.length, awf.asset().getFileSize());
    }

    @Test
    void acceptsAHeicPhotoAndStoresAJpeg() throws IOException {
      queryContext.setUserForTest(member);
      for (AssetType type : new AssetType[] {AssetType.IMAGE, AssetType.ATTACHMENT}) {
        AssetDto dto = upload(type, TestImages.HEIC, "IMG_0042.HEIC");

        assertEquals("image/jpeg", dto.contentType(), type.name());
        assertEquals("IMG_0042.jpg", dto.fileName(), type.name());
        byte[] stored = stored(dto);
        assertEquals(ImageFormat.JPEG, ImageFormat.sniff(stored), type.name());
        assertFalse(TestImages.contains(stored, TestImages.SECRET), type.name());
      }
    }

    /** docs/LEDGER_*.md API-48: an icon's PNG keeps no text or EXIF chunk. */
    @Test
    void storesAnIconAsAPngWithoutItsMetadata() throws IOException {
      queryContext.setUserForTest(member);
      AssetDto dto = upload(AssetType.IMAGE, TestImages.ICO, "favicon.ico");

      assertEquals("image/png", dto.contentType());
      assertEquals("favicon.png", dto.fileName());
      byte[] stored = stored(dto);
      assertEquals(ImageFormat.PNG, ImageFormat.sniff(stored));
      assertFalse(TestImages.contains(stored, TestImages.SECRET));
    }

    @Test
    void acceptsATiffAnAvifAndAJpegXl() throws IOException {
      queryContext.setUserForTest(member);
      for (String testImage : new String[] {TestImages.TIFF, TestImages.AVIF, TestImages.JXL}) {
        AssetDto dto = upload(AssetType.IMAGE, testImage, testImage);

        assertEquals("image/jpeg", dto.contentType(), testImage);
        assertEquals("photo.jpg", dto.fileName(), testImage);
        assertFalse(TestImages.contains(stored(dto), TestImages.SECRET), testImage);
      }
    }

    @Test
    void refusesAJpeg2000() {
      byte[] jp2 = new byte[64];
      byte[] box = {0, 0, 0, 0x0C, 'j', 'P', ' ', ' ', '\r', '\n', (byte) 0x87, '\n'};
      System.arraycopy(box, 0, jp2, 0, box.length);

      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () ->
                  assetService.createAsset(
                      team.getSlug(),
                      AssetType.ATTACHMENT,
                      new ByteArrayInputStream(jp2),
                      "scan.jp2"));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }
  }

  @Nested
  class ImageDimensionExtraction {

    @Test
    void shouldExtractDimensionsFromValidImage() throws Exception {
      InputStream imageContent = getTestImageStream();

      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(team, AssetType.IMAGE, null, imageContent, "photo.png");

      assertNotNull(result);
      assertNotNull(result.asset().getWidth(), "Width should be extracted from valid image");
      assertNotNull(result.asset().getHeight(), "Height should be extracted from valid image");
      assertTrue(result.asset().getWidth() > 0);
      assertTrue(result.asset().getHeight() > 0);
    }

    @Test
    void shouldHandleInvalidImageGracefully() {
      InputStream invalidContent =
          new ByteArrayInputStream("not an image".getBytes(StandardCharsets.UTF_8));

      queryContext.setUserForTest(member);
      PedalonsException ex =
          assertThrows(
              PedalonsException.class,
              () ->
                  assetService.addAssetStream(
                      team, AssetType.IMAGE, null, invalidContent, "fake.png"));
      assertEquals(ErrorCode.FILE_TYPE_REJECTED, ex.getErrorCode());
    }

    @Test
    void shouldNotExtractDimensionsForNonImageFiles() throws Exception {
      InputStream content = getExampleGpxStream();

      queryContext.setUserForTest(member);
      AssetWithFile result =
          assetService.addAssetStream(
              team, AssetType.ROUTE_ORIGINAL_GPX, null, content, "route.gpx");

      assertNotNull(result);
      assertNull(result.asset().getWidth());
      assertNull(result.asset().getHeight());
    }
  }

  @Nested
  class GetImage {

    @Test
    void shouldReturnResizedImage() throws Exception {
      // Upload a valid image first
      InputStream imageContent = getTestImageStream();

      queryContext.setUserForTest(organizer);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(team, AssetType.IMAGE, null, imageContent, "photo.png");
      Long assetId = assetWithFile.asset().getId();

      // Request resized image
      queryContext.setUserForTest(organizer);
      jakarta.ws.rs.core.Response response =
          assetService.getImage(team.getSlug(), assetId, 200, "image/jpeg");

      assertNotNull(response);
      assertEquals(200, response.getStatus());
    }

    @Test
    void shouldThrowForNonexistentAsset() {
      queryContext.setUserForTest(null);
      assertThrows(
          PedalonsException.class,
          () -> assetService.getImage(team.getSlug(), 999999999L, 200, "image/jpeg"));
    }

    @Test
    void shouldRespectSecurityForPrivateTeamAsset() throws Exception {
      // Upload image to private team
      InputStream imageContent = getTestImageStream();
      queryContext.setUserForTest(admin);
      AssetWithFile assetWithFile =
          assetService.addAssetStream(
              privateTeam, AssetType.IMAGE, null, imageContent, "private-photo.png");
      Long assetId = assetWithFile.asset().getId();

      // Non-member should not be able to access
      queryContext.setUserForTest(nonMember);
      assertThrows(
          PedalonsException.class,
          () -> assetService.getImage(privateTeam.getSlug(), assetId, 200, "image/jpeg"));
    }
  }

  @Nested
  class GetAssetsDto {

    @Test
    void shouldGroupAssetsByType() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset logo = dataService.createAsset(team, admin, AssetType.LOGO, "logo.png");
      logo.setTeamEntity(post);
      dataService.updateAsset(logo);
      post.getAssets().add(logo);
      Asset image1 = dataService.createAsset(team, admin, AssetType.IMAGE, "image1.png");
      image1.setTeamEntity(post);
      dataService.updateAsset(image1);
      post.getAssets().add(image1);
      Asset image2 = dataService.createAsset(team, admin, AssetType.IMAGE, "image2.png");
      image2.setTeamEntity(post);
      dataService.updateAsset(image2);
      post.getAssets().add(image2);

      AssetsDto result = assetService.getAssetsDto(post);

      assertNotNull(result);
      assertNotNull(result.logo());
      assertEquals(2, result.images().size());
      assertTrue(result.attachments().isEmpty());
    }

    @Test
    void shouldReturnEmptyListsForNoAssets() {
      Post post =
          dataService.createPost(team, admin, "Empty Post", Instant.now(), Visibility.PUBLIC);

      AssetsDto result = assetService.getAssetsDto(post);

      assertNotNull(result);
      assertNull(result.logo());
      assertTrue(result.images().isEmpty());
    }
  }

  @Nested
  class UpdateAssets {

    @Test
    void shouldKeepTheImageOrderOfTheRequest() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset img1 = dataService.createAsset(team, admin, AssetType.IMAGE, "img1.png");
      Asset img2 = dataService.createAsset(team, admin, AssetType.IMAGE, "img2.png");
      Asset img3 = dataService.createAsset(team, admin, AssetType.IMAGE, "img3.png");
      // Neither upload order nor id order: only a persisted rank can reproduce it.
      List<String> requested =
          List.of(
              TsidUtils.toString(img3.getId()),
              TsidUtils.toString(img1.getId()),
              TsidUtils.toString(img2.getId()));

      AssetsDto assetsDto =
          AssetsDto.builder()
              .images(requested.stream().map(id -> AssetDto.builder().id(id).build()).toList())
              .build();
      String markdown =
          String.join("\n", requested.stream().map(id -> "::asset{id=\"" + id + "\"}").toList());

      assetService.updateAssets(post, new MediaDto(markdown, assetsDto));

      assertEquals(
          requested, assetService.getAssetsDto(post).images().stream().map(AssetDto::id).toList());
    }

    @Test
    void shouldFallBackToUploadOrderWhenRanksTie() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      // Created in this order, all left at the default rank — the state of images saved before
      // the rank was persisted.
      List<Asset> images = new java.util.ArrayList<>();
      for (int i = 0; i < 5; i++) {
        Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "img" + i + ".png");
        image.setTeamEntity(post);
        dataService.updateAsset(image);
        post.getAssets().add(image);
        images.add(image);
      }

      assertEquals(
          images.stream().map(a -> TsidUtils.toString(a.getId())).toList(),
          assetService.getAssetsDto(post).images().stream().map(AssetDto::id).toList());
    }

    @Test
    void shouldUpdateAssetsFromDto() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "new-image.png");
      String imageId = TsidUtils.toString(image.getId());

      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      String markdown = "Some text\n::asset{id=\"" + imageId + "\" size=\"medium\"}\nMore text";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())));
    }

    @Test
    void shouldPreserveSystemAssets() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset systemAsset =
          dataService.createAsset(team, admin, AssetType.ROUTE_ORIGINAL_GPX, "route.gpx");
      systemAsset.setTeamEntity(post);
      dataService.updateAsset(systemAsset);
      post.getAssets().add(systemAsset);

      // Update with null assets should preserve system assets
      MediaDto mediaDto = new MediaDto("markdown", AssetsDto.builder().build());
      assetService.updateAssets(post, mediaDto);

      assertTrue(post.getAssets().stream().anyMatch(a -> a.getType().isSystem()));
    }

    @Test
    void shouldHandleNullAssets() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      MediaDto mediaDto = new MediaDto("markdown", AssetsDto.builder().build());

      // Should not throw
      assertDoesNotThrow(() -> assetService.updateAssets(post, mediaDto));
    }

    /** docs/LEDGER_*.md API-68: refused by name, never skipped in silence. */
    @Test
    void shouldRefuseAssetFromDifferentTeam() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset foreignAsset =
          dataService.createAsset(privateTeam, admin, AssetType.IMAGE, "foreign.png");
      String foreignId = TsidUtils.toString(foreignAsset.getId());

      AssetsDto assetsDto =
          AssetsDto.builder().logo(AssetDto.builder().id(foreignId).build()).build();
      MediaDto mediaDto = new MediaDto("markdown", assetsDto);

      assertAssetNotAvailable(foreignId, () -> assetService.updateAssets(post, mediaDto));
    }

    /** docs/LEDGER_*.md API-68: an unknown id gets the very answer of a held one — no oracle. */
    @Test
    void shouldRefuseUnknownAssetLikeAHeldOne() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      String unknownId = TsidUtils.toString(1L);

      AssetsDto assetsDto =
          AssetsDto.builder()
              .attachments(List.of(AssetDto.builder().id(unknownId).build()))
              .build();
      MediaDto mediaDto = new MediaDto("markdown", assetsDto);

      assertAssetNotAvailable(unknownId, () -> assetService.updateAssets(post, mediaDto));
    }

    private void assertAssetNotAvailable(String assetId, Runnable update) {
      PedalonsException e = assertThrows(PedalonsException.class, update::run);
      assertEquals(ErrorCode.ASSET_NOT_AVAILABLE, e.getErrorCode());
      assertEquals(400, e.getStatus().getStatusCode());
      AssetNotAvailableDetails details =
          assertInstanceOf(AssetNotAvailableDetails.class, e.getErrorDetails());
      assertEquals(assetId, details.getAssetId());
    }

    @Test
    void shouldAddAssetAlreadyAssignedToSameEntity() {
      // Branch: same team + asset.teamEntity == same entity → add
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "existing-image.png");
      image.setTeamEntity(post);
      dataService.updateAsset(image);
      String imageId = TsidUtils.toString(image.getId());

      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      String markdown = "::asset{id=\"" + imageId + "\"}";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())));
    }

    @Test
    void shouldRefuseAssetAssignedToDifferentEntity() {
      // Branch: same team + asset.teamEntity == different entity → refused (API-68)
      Post post1 = dataService.createPost(team, admin, "Post 1", Instant.now(), Visibility.PUBLIC);
      Post post2 = dataService.createPost(team, admin, "Post 2", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "other-post-image.png");
      image.setTeamEntity(post1);
      dataService.updateAsset(image);
      String imageId = TsidUtils.toString(image.getId());

      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      String markdown = "::asset{id=\"" + imageId + "\"}";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assertAssetNotAvailable(imageId, () -> assetService.updateAssets(post2, mediaDto));
    }

    @Test
    void shouldRemoveImagesNotReferencedInMarkdown() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset usedImage = dataService.createAsset(team, admin, AssetType.IMAGE, "used.png");
      Asset unusedImage = dataService.createAsset(team, admin, AssetType.IMAGE, "unused.png");
      String usedId = TsidUtils.toString(usedImage.getId());
      String unusedId = TsidUtils.toString(unusedImage.getId());

      // Both images in DTO, but only one referenced in markdown
      AssetsDto assetsDto =
          AssetsDto.builder()
              .images(
                  List.of(
                      AssetDto.builder().id(usedId).build(),
                      AssetDto.builder().id(unusedId).build()))
              .build();
      String markdown = "Some text ::asset{id=\"" + usedId + "\"} more text";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(usedImage.getId())),
          "Image referenced in markdown should be kept");
      assertFalse(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(unusedImage.getId())),
          "Image not referenced in markdown should be removed");
    }

    @Test
    void shouldRemoveOldAssetFromCollection() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);

      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "to-remove.png");
      image.setTeamEntity(post);
      dataService.updateAsset(image);
      post.getAssets().add(image);

      // Update without the image → removed from collection
      MediaDto mediaDto = new MediaDto("no images here", AssetsDto.builder().build());

      assetService.updateAssets(post, mediaDto);

      assertFalse(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())),
          "Image should be removed from entity");
    }

    @Test
    void shouldKeepReferencedImageInCollection() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "kept.png");
      String imageId = TsidUtils.toString(image.getId());

      image.setTeamEntity(post);
      dataService.updateAsset(image);
      post.getAssets().add(image);

      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      String markdown = "::asset{id=\"" + imageId + "\"}";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())),
          "Image should still be on entity");
    }

    @Test
    void shouldRemoveImageInDtoButNotInMarkdown() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "orphaned.png");
      String imageId = TsidUtils.toString(image.getId());

      image.setTeamEntity(post);
      dataService.updateAsset(image);
      post.getAssets().add(image);

      // Image in DTO but NOT in markdown
      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      MediaDto mediaDto = new MediaDto("text without any asset directives", assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertFalse(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())),
          "Image not in markdown should be removed from entity");
    }

    @Test
    void shouldHandleEmptyMarkdown() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "img.png");
      String imageId = TsidUtils.toString(image.getId());

      AssetsDto assetsDto =
          AssetsDto.builder().images(List.of(AssetDto.builder().id(imageId).build())).build();
      MediaDto mediaDto = new MediaDto("", assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertFalse(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())),
          "No images should be kept when markdown is empty");
    }

    @Test
    void shouldHandleMultipleAssetDirectivesInMarkdown() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset img1 = dataService.createAsset(team, admin, AssetType.IMAGE, "img1.png");
      Asset img2 = dataService.createAsset(team, admin, AssetType.IMAGE, "img2.png");
      Asset img3 = dataService.createAsset(team, admin, AssetType.IMAGE, "img3.png");
      String id1 = TsidUtils.toString(img1.getId());
      String id2 = TsidUtils.toString(img2.getId());
      String id3 = TsidUtils.toString(img3.getId());

      AssetsDto assetsDto =
          AssetsDto.builder()
              .images(
                  List.of(
                      AssetDto.builder().id(id1).build(),
                      AssetDto.builder().id(id2).build(),
                      AssetDto.builder().id(id3).build()))
              .build();
      String markdown =
          "Intro\n::asset{id=\""
              + id1
              + "\" size=\"full\"}\nMiddle\n::asset{id=\""
              + id3
              + "\" alt=\"photo\"}\nEnd";
      MediaDto mediaDto = new MediaDto(markdown, assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(post.getAssets().stream().anyMatch(a -> a.getId().equals(img1.getId())));
      assertFalse(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(img2.getId())),
          "img2 not in markdown should be removed");
      assertTrue(post.getAssets().stream().anyMatch(a -> a.getId().equals(img3.getId())));
    }

    @Test
    void shouldPreserveLogoAndAttachmentsRegardlessOfMarkdown() {
      Post post =
          dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
      Asset logo = dataService.createAsset(team, admin, AssetType.IMAGE, "logo.png");
      Asset attachment = dataService.createAsset(team, admin, AssetType.IMAGE, "doc.pdf");
      String logoId = TsidUtils.toString(logo.getId());
      String attachmentId = TsidUtils.toString(attachment.getId());

      // Logo and attachments are not filtered by markdown references
      AssetsDto assetsDto =
          AssetsDto.builder()
              .logo(AssetDto.builder().id(logoId).build())
              .attachments(List.of(AssetDto.builder().id(attachmentId).build()))
              .build();
      MediaDto mediaDto = new MediaDto("no directives here", assetsDto);

      assetService.updateAssets(post, mediaDto);

      assertTrue(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(logo.getId())),
          "Logo should be kept regardless of markdown");
      assertTrue(
          post.getAssets().stream().anyMatch(a -> a.getId().equals(attachment.getId())),
          "Attachment should be kept regardless of markdown");
    }
  }

  @Test
  void shouldDeleteS3WhenAssetIsDeleted() {
    Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "file.png");
    String s3Key = getAssetKey(team, asset.getFileId());
    assertTrue(storageService.exists(s3Key), "S3 file should exist before delete");

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              assetRepository.delete(assetRepository.findById(asset.getId()));
              assetRepository.flush();
              // docs/LEDGER_*.md API-97: never before the commit
              assertTrue(storageService.exists(s3Key), "S3 file must survive until the commit");
            });

    assertFalse(storageService.exists(s3Key), "S3 file should be deleted once the delete commits");
  }

  @Test
  void shouldKeepS3WhenAssetDeleteRollsBack() {
    Asset asset = dataService.createAsset(team, admin, AssetType.IMAGE, "file.png");
    String s3Key = getAssetKey(team, asset.getFileId());

    assertThrows(
        IllegalStateException.class,
        () ->
            QuarkusTransaction.requiringNew()
                .run(
                    () -> {
                      assetRepository.delete(assetRepository.findById(asset.getId()));
                      assetRepository.flush();
                      throw new IllegalStateException("a later step fails, the delete rolls back");
                    }));

    assertTrue(
        QuarkusTransaction.requiringNew()
            .call(() -> assetRepository.findByIdOptional(asset.getId()).isPresent()),
        "the rolled-back delete keeps the row");
    assertTrue(storageService.exists(s3Key), "a rolled-back delete must keep the file (API-97)");
  }

  @Test
  void shouldDeleteS3WhenOrphanRemoved() {
    Post post = dataService.createPost(team, admin, "Test Post", Instant.now(), Visibility.PUBLIC);
    Asset image = dataService.createAsset(team, admin, AssetType.IMAGE, "orphan.png");
    String s3Key = getAssetKey(team, image.getFileId());

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Post managed = postRepository.findById(post.getId());
              Asset managedImage = assetRepository.findById(image.getId());
              managedImage.setTeamEntity(managed);
              managed.getAssets().add(managedImage);
            });

    QuarkusTransaction.requiringNew()
        .run(
            () -> {
              Post managed = postRepository.findById(post.getId());
              assertTrue(
                  managed.getAssets().stream().anyMatch(a -> a.getId().equals(image.getId())),
                  "Image should be in collection before removal");

              // Remove from collection → orphanRemoval triggers @PreRemove
              managed.getAssets().removeIf(a -> a.getId().equals(image.getId()));
              postRepository.flush();
            });

    assertFalse(
        storageService.exists(s3Key), "S3 file should be deleted by orphanRemoval + @PreRemove");
  }
}
