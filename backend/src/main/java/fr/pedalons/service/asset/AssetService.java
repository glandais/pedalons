package fr.pedalons.service.asset;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.domain.asset.Asset;
import fr.pedalons.domain.common.TeamEntity;
import fr.pedalons.domain.team.Team;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.assets.response.DownloadableAsset;
import fr.pedalons.dto.common.asset.AssetDimensionsDto;
import fr.pedalons.dto.common.asset.AssetDto;
import fr.pedalons.dto.common.asset.AssetsDto;
import fr.pedalons.dto.common.asset.MediaDto;
import fr.pedalons.dto.error.AssetNotAvailableDetails;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.*;
import fr.pedalons.infrastructure.exception.NotFoundException;
import fr.pedalons.infrastructure.filetype.DetectedFileType;
import fr.pedalons.infrastructure.filetype.FileTypeDetector;
import fr.pedalons.infrastructure.image.ImageFormat;
import fr.pedalons.infrastructure.imgproxy.ImgProxyService;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.asset.AssetRepository;
import fr.pedalons.service.asset.response.AssetWithFile;
import fr.pedalons.service.gpx.TrackAttachmentSanitizer;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.CheckAccess;
import fr.pedalons.service.team.TeamService;
import io.hypersistence.tsid.TSID;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Status;
import jakarta.transaction.Synchronization;
import jakarta.transaction.TransactionSynchronizationRegistry;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URLConnection;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import javax.imageio.ImageIO;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class AssetService {

  private static final Logger LOG = Logger.getLogger(AssetService.class);

  private static final String ASSETS_PREFIX = "assets";

  /**
   * The order the editor arranged an entity's assets in. The id breaks ties — TSIDs grow with
   * creation — so assets saved before the rank was persisted keep their upload order instead of
   * the hash order of {@link TeamEntity#getAssets()}.
   */
  private static final Comparator<Asset> EDITOR_ORDER =
      Comparator.comparingInt(Asset::getSortOrder).thenComparing(Asset::getId);

  /**
   * An asset directive in markdown ({@code ::asset} followed by its attributes in braces), the
   * attributes in group 1. Possessive, and stopped by an opening brace as well as by the closing
   * one: the former pattern, which looked for the id inside greedy runs on either side, backtracked
   * in cubic time over a run of unclosed directives — 28 KB of them took 78 s of CPU
   * (docs/LEDGER_*.md SEC-10, audit M6). This one reads each character once.
   */
  private static final Pattern ASSET_DIRECTIVE_PATTERN = Pattern.compile("::asset\\{([^{}]*+)\\}");

  /** The {@code id="…"} attribute inside a directive's attributes. */
  private static final Pattern ASSET_ID_ATTRIBUTE = Pattern.compile("id=\"([^\"]+)\"");

  @Inject AssetRepository assetRepository;

  @Inject ImgProxyService imgProxyService;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject TeamService teamService;

  @Inject StorageService storageService;

  @Inject TransactionSynchronizationRegistry txRegistry;

  @Inject FileTypeDetector fileTypeDetector;

  @Inject TrackAttachmentSanitizer trackAttachmentSanitizer;

  @CheckAccess(entityType = EntityType.ASSET, action = ActionType.CREATE)
  public AssetDto createAsset(
      String teamSlug, AssetType assetType, InputStream inputStream, String fileName)
      throws IOException {
    Team team = teamService.getTeam(teamSlug);
    // every member can create asset (ads, ...)
    AssetWithFile assetFile = addAssetStream(team, assetType, null, inputStream, fileName);
    return map(assetFile.asset());
  }

  /**
   * Creates an asset with a temp file for external libraries to write to. After writing, call
   * {@link #uploadAssetFile(Asset)} to upload the file to S3.
   */
  public AssetWithFile addAsset(TeamEntity teamEntity, AssetType type, String fileName)
      throws IOException {
    return addAssetStream(teamEntity.getTeam(), type, teamEntity, null, fileName);
  }

  @Transactional
  protected AssetWithFile addAssetStream(
      Team team,
      AssetType type,
      @Nullable TeamEntity teamEntity,
      @Nullable InputStream content,
      String fileName)
      throws IOException {
    User creator = pedalonsContext.getUser();
    long fileId = TSID.Factory.getTsid().toLong();

    // Create temp file for content type detection and possible external writing
    File tempFile = createTempFile(fileId);
    String contentType;
    String storedName = fileName;
    Long size = null;

    if (content != null) {
      // Copy content to temp file for content type detection
      Files.copy(content, tempFile.toPath());
      contentType = detectAndValidate(tempFile, fileName, type);
      storedName = storedFileName(tempFile, fileName);
      if (TrackAttachmentSanitizer.applies(type, contentType)) {
        // docs/LEDGER_*.md API-49, API-55: an attached GPX or FIT loses its clock and sensors
        // like a route's.
        byte[] raw = Files.readAllBytes(tempFile.toPath());
        try {
          Files.write(tempFile.toPath(), trackAttachmentSanitizer.sanitize(raw, contentType));
        } catch (RuntimeException e) {
          // Refused: nothing is stored, and the upload's copy must not stay on disk either.
          deleteTempFile(tempFile);
          throw e;
        }
      }

      // Upload to S3 with metadata
      String key = getAssetKey(team, fileId);
      Map<String, String> metadata =
          Map.of(
              "file-id", TsidUtils.toString(fileId),
              "team-id", TsidUtils.toString(team.getId()),
              "file-name", storedName);
      try (InputStream fis = new FileInputStream(tempFile)) {
        size = storageService.store(key, fis, contentType, tempFile.length(), metadata);
      }

      deleteTempFile(tempFile);
    } else {
      // No content - create temp file for external writing. Magika validation cannot run yet
      // because there is no payload; the caller is expected to populate the temp file and then
      // invoke uploadAssetFile(...) which re-runs detectAndValidate against the written bytes.
      contentType = getContentTypeFromFileName(fileName);
      LOG.debugf(
          "Skipping Magika validation: no upload payload yet for fileName=%s assetType=%s"
              + " (caller must invoke uploadAssetFile after writing the temp file)",
          fileName, type);
    }

    Asset asset = new Asset(creator, team, type, fileId, storedName, contentType);
    asset.setTeamEntity(teamEntity);
    asset.setFileSize(size);

    if (content != null && contentType.startsWith("image/")) {
      try (InputStream is =
          imgProxyService.getPhotoContent("image/jpeg", getAssetKey(team, fileId), 4096, 4096)) {
        BufferedImage read = ImageIO.read(is);
        asset.setWidth(read.getWidth());
        asset.setHeight(read.getHeight());
      } catch (Exception e) {
        LOG.warnf(
            e,
            "Failed to extract image dimensions for asset fileId=%s",
            TsidUtils.toString(fileId));
      }
    }

    assetRepository.persistAndFlush(asset);

    return new AssetWithFile(asset, tempFile);
  }

  /**
   * Uploads an asset file from temp location to S3. Call this after external libraries have
   * written to the temp file returned by {@link #addAsset(TeamEntity, AssetType, String)}.
   */
  public void uploadAssetFile(Asset asset) throws IOException {
    File tempFile = getTempFile(asset.getFileId());
    if (!tempFile.exists()) {
      throw new IOException("Temp file not found for asset: " + asset.getId());
    }

    String contentType = detectAndValidate(tempFile, asset.getFileName(), asset.getType());
    asset.setContentType(contentType);
    asset.setFileName(storedFileName(tempFile, asset.getFileName()));

    String key = getAssetKey(asset.getTeam(), asset.getFileId());
    Map<String, String> metadata =
        Map.of(
            "asset-id", TsidUtils.toString(asset.getId()),
            "file-id", TsidUtils.toString(asset.getFileId()),
            "team-id", TsidUtils.toString(asset.getTeam().getId()),
            "file-name", asset.getFileName());
    try (InputStream fis = new FileInputStream(tempFile)) {
      asset.setFileSize(storageService.store(key, fis, contentType, tempFile.length(), metadata));
    }

    deleteTempFile(tempFile);
  }

  /**
   * Gets the temp file for an asset (for external libraries to write to).
   */
  public File getAssetFile(Asset asset) {
    return getTempFile(asset.getFileId());
  }

  /**
   * Retrieves asset content as an InputStream from S3.
   */
  public InputStream getAssetContent(Asset asset) {
    String key = getAssetKey(asset.getTeam(), asset.getFileId());
    return storageService.retrieve(key);
  }

  public File createTempFile(long fileId) throws IOException {
    Path tempDir = Path.of(System.getProperty("java.io.tmpdir"), "pedalons-assets");
    Files.createDirectories(tempDir);
    return new File(tempDir.toFile(), TsidUtils.toString(fileId));
  }

  private File getTempFile(long fileId) {
    String idString = TsidUtils.toString(fileId);
    return Path.of(System.getProperty("java.io.tmpdir"), "pedalons-assets", idString).toFile();
  }

  public String getAssetKey(Team team, long fileId) {
    return getAssetKey(team.getId(), fileId);
  }

  public String getAssetKey(Long teamId, long fileId) {
    String teamIdString = TsidUtils.toString(teamId);
    String idString = TsidUtils.toString(fileId);
    String subPath = idString.substring(0, 4);
    return ASSETS_PREFIX + "/" + teamIdString + "/" + subPath + "/" + idString;
  }

  /** What {@link #uploadTempFileToS3} stored: the detected content type and the stored bytes. */
  public record UploadedFile(String contentType, long size) {}

  /**
   * Uploads a pre-computed temp file to S3. Used by GPX processing pipeline where the file
   * content is prepared before the DB transaction to minimize connection hold time.
   */
  public UploadedFile uploadTempFileToS3(Team team, AssetType type, long fileId, String fileName)
      throws IOException {
    File tempFile = getTempFile(fileId);
    String contentType = detectAndValidate(tempFile, fileName, type);
    String key = getAssetKey(team, fileId);
    Map<String, String> metadata =
        Map.of(
            "file-id", TsidUtils.toString(fileId),
            "team-id", TsidUtils.toString(team.getId()),
            "file-name", fileName);
    long size;
    try (InputStream fis = new FileInputStream(tempFile)) {
      size = storageService.store(key, fis, contentType, tempFile.length(), metadata);
    }
    deleteTempFile(tempFile);
    return new UploadedFile(contentType, size);
  }

  private static void deleteTempFile(File tempFile) {
    if (!tempFile.delete() && tempFile.exists()) {
      LOG.warnf(
          "Failed to delete temp asset file %s — may leak on disk", tempFile.getAbsolutePath());
    }
  }

  /**
   * Persists an asset record for a file already uploaded to S3. Used by GPX processing pipeline
   * after {@link #uploadTempFileToS3}.
   */
  @Transactional
  public Asset persistAsset(
      Team team,
      TeamEntity owner,
      AssetType type,
      long fileId,
      String fileName,
      UploadedFile stored) {
    User creator = pedalonsContext.getUser();
    Asset asset = new Asset(creator, team, type, fileId, fileName, stored.contentType());
    asset.setTeamEntity(owner);
    asset.setFileSize(stored.size());
    owner.getAssets().add(asset);
    assetRepository.persist(asset);
    return asset;
  }

  @CheckAccess(entityType = EntityType.ASSET, action = ActionType.READ)
  public DownloadableAsset getDownloadableAsset(String teamSlug, Long assetId) {
    Asset asset = getAsset(assetId);
    InputStream content = getAssetContent(asset);
    return new DownloadableAsset(content, asset.getContentType(), asset.getFileName());
  }

  @CheckAccess(entityType = EntityType.ASSET, action = ActionType.READ)
  public Response getImage(String teamSlug, Long assetId, int size, String accept) {
    Asset asset = getAsset(assetId);
    String key = getAssetKey(asset.getTeam(), asset.getFileId());
    return Response.fromResponse(imgProxyService.getPhoto(accept, key, size, size)).build();
  }

  private String detectAndValidate(File file, String fileName, AssetType type) {
    DetectedFileType detected = fileTypeDetector.detectAndValidate(file, fileName, type);
    return detected.mimeType();
  }

  /**
   * The name the asset keeps once storage has re-encoded it: a HEIC stored as a JPEG ends in
   * {@code .jpg}. docs/LEDGER_*.md API-43.
   */
  private static String storedFileName(File file, String fileName) throws IOException {
    return ImageFormat.sniff(file.toPath()).storedFileName(fileName);
  }

  private String getContentTypeFromFileName(String fileName) {
    String guessed = URLConnection.guessContentTypeFromName(fileName);
    return guessed != null ? guessed : MediaType.APPLICATION_OCTET_STREAM;
  }

  private Asset getAsset(Long id) {
    return assetRepository
        .findByIdOptional(id)
        .orElseThrow(() -> new NotFoundException(EntityType.ASSET, id));
  }

  @Transactional
  @CheckAccess(entityType = EntityType.ASSET, action = ActionType.DELETE)
  protected void deleteAsset(String teamSlug, Long id) {
    Asset asset =
        assetRepository
            .findByIdOptional(id)
            .orElseThrow(() -> new NotFoundException(EntityType.ASSET, id));
    assetRepository.delete(asset);
  }

  protected AssetDto map(Asset asset) {
    Visibility visibility;
    if (asset.getTeamEntity() == null) {
      visibility = Visibility.TEAM;
    } else {
      visibility = asset.getTeamEntity().getVisibility();
    }
    String teamSlug = asset.getTeam().getSlug();
    AssetDimensionsDto assetDimensionsDto;
    String imageUrl;
    if (asset.getContentType().startsWith("image/")) {
      imageUrl = getImageUrl(asset);
    } else {
      imageUrl = null;
    }
    if (asset.getWidth() != null && asset.getHeight() != null) {
      assetDimensionsDto = new AssetDimensionsDto(asset.getWidth(), asset.getHeight());
    } else {
      assetDimensionsDto = null;
    }
    String url =
        "/api/download/"
            + visibility.name().toLowerCase()
            + "/assets/"
            + teamSlug
            + "/"
            + TsidUtils.toString(asset.getId())
            + "/"
            + encodePathSegment(asset.getFileName())
            + versionQuery(asset.getFileId());
    return new AssetDto(
        TsidUtils.toString(asset.getId()),
        asset.getFileName(),
        asset.getContentType(),
        url,
        imageUrl,
        assetDimensionsDto,
        asset.getFileSize());
  }

  /**
   * The file name as one path segment. The download endpoint ignores it — it only names the file
   * for whoever saves it — but raw, a {@code ?}, a {@code #} or a {@code /} in an uploaded name cut
   * the URL short or sent it elsewhere (docs/LEDGER_*.md SEC-12, audit L9).
   */
  static String encodePathSegment(String segment) {
    return URLEncoder.encode(segment, StandardCharsets.UTF_8).replace("+", "%20");
  }

  public String getImageUrl(Asset asset) {
    String teamSlug = asset.getTeam().getSlug();
    Visibility visibility;
    if (asset.getTeamEntity() == null) {
      visibility = Visibility.TEAM;
    } else {
      visibility = asset.getTeamEntity().getVisibility();
    }
    return buildImageUrl(teamSlug, visibility, asset.getId(), asset.getFileId());
  }

  /**
   * The URL template of the entity's first image, in the order the editor arranged them.
   *
   * <p>Entities with no generated thumbnail — a post, an ad — still have a picture to show on a
   * card, and it is the first of their images. Exposing it as a scalar is what lets a compact list
   * row drop {@code media.assets} entirely instead of carrying the whole inventory to read one URL.
   *
   * @return {@code null} when the entity has no image
   */
  public @Nullable String getFirstImageUrl(TeamEntity teamEntity) {
    return teamEntity.getAssets().stream()
        .filter(asset -> asset.getType() == AssetType.IMAGE)
        .min(EDITOR_ORDER)
        .map(this::getImageUrl)
        .orElse(null);
  }

  /**
   * The URL templates of every image on the entity, in the order the editor arranged them.
   *
   * <p>A gallery — a classified ad's photos, say — needs the whole list, but not the filenames,
   * content types and dimensions that {@link #getAssetsDto} carries alongside them. Reads the same
   * already-materialised collection as {@link #getFirstImageUrl}, so a caller that exposes both
   * pays for one, and a compact row that already carries a thumbnail can carry a gallery for free.
   *
   * @return an empty list when the entity has no image
   */
  public List<String> getImageUrls(TeamEntity teamEntity) {
    return teamEntity.getAssets().stream()
        .filter(asset -> asset.getType() == AssetType.IMAGE)
        .sorted(EDITOR_ORDER)
        .map(this::getImageUrl)
        .toList();
  }

  /**
   * The image URL template for an asset described by scalars rather than by the entity itself.
   *
   * <p>{@link #getImageUrl(Asset)} walks two lazy to-one associations to reach the team slug and the
   * owning entity's visibility, which is fine for one asset and a per-row cost for a page of them.
   * Bulk callers project those two scalars in their own query and land here, so the URL shape stays
   * defined in exactly one place. See {@code ThumbnailLookup}.
   */
  public static String buildImageUrl(
      String teamSlug, Visibility visibility, Long assetId, Long fileId) {
    return "/api/download/"
        + visibility.name().toLowerCase()
        + "/images/"
        + teamSlug
        + "/"
        + TsidUtils.toString(assetId)
        + "/{size}"
        + versionQuery(fileId);
  }

  /**
   * The cache-buster of an asset URL. The asset id is stable across a replacement of its file
   * (docs/LEDGER_*.md API-128) while imgproxy answers with a one-year {@code Cache-Control} and
   * mobile clients cache images by URL, so the URL must change with the stored file. The download
   * endpoints ignore it.
   */
  private static String versionQuery(Long fileId) {
    return "?v=" + TsidUtils.toString(fileId);
  }

  /**
   * Replaces the stored file of an existing asset row, keeping its id — and so every published URL
   * — stable. docs/LEDGER_*.md API-128.
   *
   * <p>The new file is already uploaded under {@code newFileId}. The old key is deleted after the
   * commit; on any other outcome (rollback, lost optimistic-lock race) the new key is deleted
   * instead, so a failed edit leaves neither a dangling row nor an orphaned file. Needs an active
   * transaction: without one neither outcome could be observed, so the new file is deleted and the
   * call fails rather than leave state half-done.
   *
   * @param newContent the content changed (a track edit) rather than just being re-rendered
   *     (a thumbnail): sets {@code contentRevision}, which makes GPS sync push the file again
   */
  public void replaceStoredFile(
      Asset asset, long newFileId, UploadedFile stored, String fileName, boolean newContent) {
    String newKey = getAssetKey(asset.getTeam(), newFileId);
    if (txRegistry.getTransactionStatus() != Status.STATUS_ACTIVE) {
      deleteQuietly(newKey);
      throw new IllegalStateException(
          "replaceStoredFile needs an active transaction (asset " + asset.getId() + ")");
    }
    String oldKey = getAssetKey(asset.getTeam(), asset.getFileId());
    asset.setFileId(newFileId);
    asset.setFileName(fileName);
    asset.setContentType(stored.contentType());
    asset.setFileSize(stored.size());
    asset.setWidth(null);
    asset.setHeight(null);
    if (newContent) {
      asset.setContentRevision(newFileId);
    }
    deleteAfterCommit(oldKey);
    deleteUnlessCommitted(newKey);
  }

  /**
   * Stores an already uploaded file as the asset of {@code type} on {@code owner}: the existing row
   * (the newest if several) takes the new file and keeps its id and so its URLs, surplus rows are
   * removed (the orphan removal deletes their files), and a missing row is created. Works on the
   * in-memory {@code owner.getAssets()} only, no query: callers may sit between a collection clear
   * and its refill. docs/LEDGER_*.md API-128.
   */
  public void putStoredFile(
      Team team,
      TeamEntity owner,
      AssetType type,
      long fileId,
      String fileName,
      UploadedFile stored,
      boolean newContent) {
    List<Asset> existing =
        owner.getAssets().stream()
            .filter(a -> a.getType() == type)
            .sorted(Comparator.comparing(Asset::getId).reversed())
            .toList();
    if (existing.isEmpty()) {
      String newKey = getAssetKey(team, fileId);
      if (txRegistry.getTransactionStatus() != Status.STATUS_ACTIVE) {
        // persistAsset would commit the row on its own and the file would then be deleted
        deleteQuietly(newKey);
        throw new IllegalStateException("putStoredFile needs an active transaction");
      }
      deleteUnlessCommitted(newKey);
      persistAsset(team, owner, type, fileId, fileName, stored);
      return;
    }
    replaceStoredFile(existing.get(0), fileId, stored, fileName, newContent);
    owner.getAssets().removeAll(existing.subList(1, existing.size()));
  }

  /** Removes the assets of the given types from {@code owner}; orphan removal deletes the files. */
  public void removeAssetsOfTypes(TeamEntity owner, Collection<AssetType> types) {
    owner.getAssets().removeIf(a -> types.contains(a.getType()));
  }

  /**
   * Deletes {@code key} once the current transaction has committed, and only then. Deleted at once
   * when there is no transaction, as the change is then already committed.
   */
  public void deleteAfterCommit(String key) {
    registerCleanup(key, true);
  }

  /**
   * Deletes {@code key} unless the current transaction commits: a file uploaded ahead of its row
   * must not outlive a rollback. Deleted at once when there is no transaction to wait for.
   */
  public void deleteUnlessCommitted(String key) {
    registerCleanup(key, false);
  }

  private void registerCleanup(String key, boolean onCommit) {
    int status = txRegistry.getTransactionStatus();
    if (status == Status.STATUS_NO_TRANSACTION) {
      // Nothing to wait for: whatever changed is already committed (same as AssetRemoveListener).
      deleteQuietly(key);
      return;
    }
    if (status != Status.STATUS_ACTIVE) {
      // Marked for rollback or completing: the outcome is a rollback.
      if (!onCommit) {
        deleteQuietly(key);
      }
      return;
    }
    txRegistry.registerInterposedSynchronization(
        new Synchronization() {
          @Override
          public void beforeCompletion() {
            // the outcome is not known yet
          }

          @Override
          public void afterCompletion(int outcome) {
            if ((outcome == Status.STATUS_COMMITTED) == onCommit) {
              deleteQuietly(key);
            }
          }
        });
  }

  private void deleteQuietly(String key) {
    try {
      storageService.delete(key);
    } catch (Exception e) {
      LOG.warnv("Failed to delete {0} from storage: {1}", key, e.getMessage());
    }
  }

  /**
   * Called to create DTO in MediaDto.from
   * @param teamEntity
   * @return
   */
  public AssetsDto getAssetsDto(TeamEntity teamEntity) {
    Map<AssetType, List<Asset>> assets =
        teamEntity.getAssets().stream().collect(Collectors.groupingBy(Asset::getType));
    AssetDto thumbnailLight =
        coalesce(
            getAssetDto(assets, AssetType.RIDE_THUMBNAIL_LIGHT),
            getAssetDto(assets, AssetType.TRIP_THUMBNAIL_LIGHT),
            getAssetDto(assets, AssetType.ROUTE_THUMBNAIL_LIGHT));
    AssetDto thumbnailDark =
        coalesce(
            getAssetDto(assets, AssetType.RIDE_THUMBNAIL_DARK),
            getAssetDto(assets, AssetType.TRIP_THUMBNAIL_DARK),
            getAssetDto(assets, AssetType.ROUTE_THUMBNAIL_DARK));
    return new AssetsDto(
        getAssetDto(assets, AssetType.LOGO),
        getAssetDtoList(assets, AssetType.IMAGE),
        getAssetDtoList(assets, AssetType.ATTACHMENT),
        getAssetDto(assets, AssetType.ROUTE_ORIGINAL_GPX),
        getAssetDto(assets, AssetType.ROUTE_FILTERED_GPX),
        getAssetDto(assets, AssetType.ROUTE_FIT),
        thumbnailLight,
        thumbnailDark);
  }

  @SafeVarargs
  private static <T> @Nullable T coalesce(@Nullable T... values) {
    for (T value : values) {
      if (value != null) {
        return value;
      }
    }
    return null;
  }

  private @Nullable AssetDto getAssetDto(Map<AssetType, List<Asset>> assets, AssetType assetType) {
    return Optional.ofNullable(assets.get(assetType))
        .filter(l -> !l.isEmpty())
        .map(List::getFirst)
        .map(this::map)
        .orElse(null);
  }

  private List<AssetDto> getAssetDtoList(Map<AssetType, List<Asset>> assets, AssetType assetType) {
    List<Asset> assetsForType = assets.get(assetType);
    if (assetsForType == null) {
      return List.of();
    }
    return assetsForType.stream().sorted(EDITOR_ORDER).map(this::map).toList();
  }

  /**
   * Called in service having MediaDto
   * @param teamEntity
   * @param mediaRequest
   */
  public void updateAssets(TeamEntity teamEntity, MediaDto mediaRequest) {
    teamEntity.setMarkdown(mediaRequest.markdown());
    AssetsDto assets = mediaRequest.assets();

    // Parse markdown to find which image assets are actually referenced
    Set<String> referencedAssetIds = extractAssetIdsFromMarkdown(mediaRequest.markdown());

    // Only keep images that are referenced in the markdown
    List<AssetDto> usedImages =
        assets.images().stream().filter(img -> referencedAssetIds.contains(img.id())).toList();

    Set<Asset> unmodifiable =
        teamEntity.getAssets().stream()
            .filter(s -> s.getType().isSystem())
            .collect(Collectors.toSet());
    // orphanRemoval deletes removed assets from DB; AssetRemoveListener handles S3 cleanup
    teamEntity.getAssets().clear();
    int order = 0;
    for (Asset asset : unmodifiable) {
      asset.setSortOrder(order++);
      teamEntity.getAssets().add(asset);
    }

    order = addAssetToEntity(order, teamEntity, AssetType.LOGO, assets.logo());
    order = addAssetsToEntity(order, teamEntity, AssetType.IMAGE, usedImages);
    addAssetsToEntity(order, teamEntity, AssetType.ATTACHMENT, assets.attachments());
  }

  static Set<String> extractAssetIdsFromMarkdown(String markdown) {
    Set<String> assetIds = new HashSet<>();
    if (markdown.isEmpty()) {
      return assetIds;
    }
    Matcher directive = ASSET_DIRECTIVE_PATTERN.matcher(markdown);
    while (directive.find()) {
      // The last id="…" of the directive, as the former greedy pattern picked it.
      Matcher id = ASSET_ID_ATTRIBUTE.matcher(directive.group(1));
      @Nullable String last = null;
      while (id.find()) {
        last = id.group(1);
      }
      if (last != null) {
        assetIds.add(last);
      }
    }
    return assetIds;
  }

  private int addAssetsToEntity(
      int order, TeamEntity teamEntity, AssetType assetType, List<AssetDto> assetRequests) {
    for (AssetDto assetDto : assetRequests) {
      addAssetToEntity(order, teamEntity, assetType, assetDto);
      order++;
    }
    return order;
  }

  /**
   * An asset belongs to one content only: one of another team, one already attached to another
   * content, or an unknown id is refused with ASSET_NOT_AVAILABLE naming the id as cited — the same
   * answer in all three cases, so the API is no oracle of what other contents hold. It used to be
   * skipped in silence, and the client believed the file attached (docs/LEDGER_*.md API-68). The
   * request's transaction rolls back, so the content's assets are left as they were.
   */
  private int addAssetToEntity(
      int order, TeamEntity teamEntity, AssetType assetType, @Nullable AssetDto assetRequest) {
    if (assetRequest == null) {
      return order;
    }
    Asset asset = findAvailableAsset(teamEntity, assetRequest.id());
    asset.setTeamEntity(teamEntity);
    asset.setType(assetType);
    asset.setSortOrder(order);
    assetRepository.persist(asset);
    teamEntity.getAssets().add(asset);
    return order + 1;
  }

  private Asset findAvailableAsset(TeamEntity teamEntity, String assetId) {
    Long id;
    try {
      id = TsidUtils.toLong(assetId);
    } catch (IllegalArgumentException e) {
      throw assetNotAvailable(assetId);
    }
    Asset asset =
        assetRepository.findByIdOptional(id).orElseThrow(() -> assetNotAvailable(assetId));
    boolean sameTeam = asset.getTeam().getId().equals(teamEntity.getTeam().getId());
    boolean freeOrOurs =
        asset.getTeamEntity() == null || asset.getTeamEntity().getId().equals(teamEntity.getId());
    if (!sameTeam || !freeOrOurs) {
      throw assetNotAvailable(assetId);
    }
    return asset;
  }

  private static BadRequestException assetNotAvailable(String assetId) {
    return new BadRequestException(
        ErrorCode.ASSET_NOT_AVAILABLE, new AssetNotAvailableDetails(assetId), null);
  }
}
