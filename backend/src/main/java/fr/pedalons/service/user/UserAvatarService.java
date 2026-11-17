package fr.pedalons.service.user;

import fr.pedalons.common.TsidUtils;
import fr.pedalons.common.exception.BusinessException;
import fr.pedalons.common.exception.NotFoundException;
import fr.pedalons.common.exception.PedalonsException;
import fr.pedalons.domain.user.User;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.enums.AssetType;
import fr.pedalons.infrastructure.filetype.DetectedFileType;
import fr.pedalons.infrastructure.filetype.FileTypeDetector;
import fr.pedalons.infrastructure.imgproxy.ImgProxyService;
import fr.pedalons.infrastructure.storage.StorageService;
import fr.pedalons.repository.user.UserRepository;
import fr.pedalons.service.security.PedalonsQueryContext;
import fr.pedalons.service.security.annotation.Logged;
import fr.pedalons.service.security.annotation.Public;
import io.hypersistence.tsid.TSID;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.core.Response;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;
import org.jboss.logging.Logger;
import org.jspecify.annotations.Nullable;

@ApplicationScoped
public class UserAvatarService {

  private static final Logger LOG = Logger.getLogger(UserAvatarService.class);

  private static final int AVATAR_SIZE = 256;
  private static final String AVATARS_PREFIX = "avatars";

  @Inject UserRepository userRepository;

  @Inject ImgProxyService imgProxyService;

  @Inject PedalonsQueryContext pedalonsContext;

  @Inject StorageService storageService;

  @Inject FileTypeDetector fileTypeDetector;

  @Logged
  @Transactional
  public void uploadAvatar(InputStream content, String fileName) throws IOException {
    User user = pedalonsContext.getUser();

    // Create temp file for content type validation
    long tempFileId = TSID.Factory.getTsid().toLong();
    File tempFile = createTempFile(tempFileId);
    long fileId = TSID.Factory.getTsid().toLong();
    File avatarFile = createTempFile(fileId);
    String tempKey = getAvatarKey(tempFileId);
    boolean tempStored = false;
    // Both local copies and the S3 original go whatever happens — refused type, interrupted copy,
    // imgproxy or storage failure (docs/LEDGER_*.md SEC-42).
    try {
      // Save original file temporarily
      Files.copy(content, tempFile.toPath());

      DetectedFileType detected;
      try {
        detected = fileTypeDetector.detectAndValidate(tempFile, fileName, AssetType.IMAGE);
      } catch (PedalonsException e) {
        throw e;
      } catch (RuntimeException e) {
        throw new BusinessException(ErrorCode.INVALID_FORMAT, e);
      }
      String contentType = detected.mimeType();
      if (!contentType.startsWith("image/")) {
        throw new BusinessException(ErrorCode.INVALID_FORMAT);
      }

      // Upload temp file to S3 for imgproxy processing; an image imgproxy cannot decode to
      // re-encode it fails here or below (docs/LEDGER_*.md API-43)
      try (InputStream fis = new FileInputStream(tempFile)) {
        tempStored = true;
        storageService.store(tempKey, fis, contentType, tempFile.length());
      }

      // Use ImgProxy to resize to 256x256
      try (InputStream resizedStream =
          imgProxyService.getPhotoContent("image/jpeg", tempKey, AVATAR_SIZE, AVATAR_SIZE)) {
        Files.copy(resizedStream, avatarFile.toPath());
      } catch (Exception e) {
        throw new BusinessException(ErrorCode.INVALID_FORMAT, e);
      }

      // Upload resized avatar to S3
      String avatarKey = getAvatarKey(fileId);
      Map<String, String> metadata =
          Map.of(
              "file-id", TsidUtils.toString(fileId),
              "user-id", TsidUtils.toString(user.getId()),
              "type", "avatar");
      try (InputStream fis = new FileInputStream(avatarFile)) {
        storageService.store(avatarKey, fis, "image/jpeg", avatarFile.length(), metadata);
      }
    } finally {
      deleteQuietly(tempFile);
      deleteQuietly(avatarFile);
      if (tempStored) {
        try {
          storageService.delete(tempKey);
        } catch (RuntimeException e) {
          LOG.warnf(e, "Failed to delete temp avatar object %s", tempKey);
        }
      }
    }

    // Delete old avatar file if exists
    String oldAvatarUrl = user.getAvatarUrl();
    if (oldAvatarUrl != null) {
      deleteAvatarFromUrl(oldAvatarUrl);
    }

    // Update user with new avatar URL
    String avatarUrl =
        "/api/download/public/avatars/" + TsidUtils.toString(fileId) + "/" + AVATAR_SIZE;
    user.setAvatarUrl(avatarUrl);
    userRepository.persist(user);
  }

  @Logged
  @Transactional
  public void deleteAvatar() {
    forgetAvatar(pedalonsContext.getUser());
  }

  /** Deletes a user's avatar from storage and clears the URL; nothing to do if they have none. */
  @Transactional
  public void forgetAvatar(User user) {
    String avatarUrl = user.getAvatarUrl();
    if (avatarUrl != null) {
      deleteAvatarFromUrl(avatarUrl);
      user.setAvatarUrl(null);
      userRepository.persist(user);
    }
  }

  @Public
  public Response getAvatar(String fileId, int size, String accept) {
    // Limit size to AVATAR_SIZE (avatars are stored at 256x256)
    int effectiveSize = Math.min(size, AVATAR_SIZE);
    long fileIdLong = TsidUtils.toLong(fileId);

    String key = getAvatarKey(fileIdLong);

    // Verify file exists
    if (!storageService.exists(key)) {
      throw new NotFoundException(ErrorCode.NOT_FOUND);
    }

    return Response.fromResponse(
            imgProxyService.getPhoto(accept, key, effectiveSize, effectiveSize))
        .build();
  }

  private static void deleteQuietly(File file) {
    if (!file.delete() && file.exists()) {
      LOG.warnf("Failed to delete temp avatar file %s — may leak on disk", file.getAbsolutePath());
    }
  }

  private File createTempFile(long fileId) throws IOException {
    Path tempDir = Path.of(System.getProperty("java.io.tmpdir"), "pedalons-avatars");
    Files.createDirectories(tempDir);
    return new File(tempDir.toFile(), TsidUtils.toString(fileId));
  }

  private String getAvatarKey(long fileId) {
    String idString = TsidUtils.toString(fileId);
    String subPath = idString.substring(0, 4);
    return AVATARS_PREFIX + "/" + subPath + "/" + idString;
  }

  /**
   * The storage key behind a stored {@code avatarUrl}, or null if the URL is malformed.
   *
   * <p>{@code User} keeps only the public URL, so anything that needs the actual bytes — the GDPR
   * data export, for one — has to come back through this class, which owns the key layout.
   */
  public @Nullable String getAvatarKeyFromUrl(@Nullable String avatarUrl) {
    if (avatarUrl == null) {
      return null;
    }
    // Extract fileId from URL: /api/download/public/avatars/{fileId}/{size}
    String[] parts = avatarUrl.split("/");
    if (parts.length < 6) {
      LOG.warnf("Malformed avatar URL %s", avatarUrl);
      return null;
    }
    try {
      return getAvatarKey(TsidUtils.toLong(parts[5]));
    } catch (Exception e) {
      LOG.warnf(e, "Malformed avatar URL %s", avatarUrl);
      return null;
    }
  }

  private void deleteAvatarFromUrl(@Nullable String avatarUrl) {
    String key = getAvatarKeyFromUrl(avatarUrl);
    if (key == null) {
      LOG.warnf("Skipping avatar deletion: malformed avatar URL %s", avatarUrl);
      return;
    }
    try {
      storageService.delete(key);
    } catch (Exception e) {
      LOG.warnf(e, "Failed to delete old avatar from S3 (orphaned object) avatarUrl=%s", avatarUrl);
    }
  }
}
