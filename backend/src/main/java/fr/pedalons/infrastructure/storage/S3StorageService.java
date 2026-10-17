package fr.pedalons.infrastructure.storage;

import fr.pedalons.common.exception.BadRequestException;
import fr.pedalons.dto.error.ErrorCode;
import fr.pedalons.infrastructure.image.ImageFormat;
import fr.pedalons.infrastructure.imgproxy.ImgProxyClient;
import io.quarkus.runtime.Startup;
import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.WebApplicationException;
import java.io.BufferedInputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.Map;
import java.util.UUID;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;
import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.BucketLifecycleConfiguration;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadObjectRequest;
import software.amazon.awssdk.services.s3.model.LifecycleExpiration;
import software.amazon.awssdk.services.s3.model.LifecycleRule;
import software.amazon.awssdk.services.s3.model.LifecycleRuleFilter;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;
import software.amazon.awssdk.services.s3.model.NoSuchKeyException;
import software.amazon.awssdk.services.s3.model.PutBucketLifecycleConfigurationRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;
import software.amazon.awssdk.services.s3.model.S3Object;

/** S3-based implementation of {@link StorageService} for MinIO/S3 storage. */
@Startup
@ApplicationScoped
public class S3StorageService implements StorageService {

  private static final Logger LOG = Logger.getLogger(S3StorageService.class);

  /** Where an image waits, with its metadata, for imgproxy to re-encode it. Never kept. */
  static final String REENCODE_PREFIX = "tmp/reencode/";

  @Inject S3Client s3Client;

  @Inject @RestClient ImgProxyClient imgProxyClient;

  @ConfigProperty(name = "storage.bucket", defaultValue = "pedalons")
  String bucket;

  /** How long boot waits for MinIO, restarting beside us when a deploy changes its spec. */
  private static final int BUCKET_CHECK_ATTEMPTS = 12;

  private static final long BUCKET_CHECK_DELAY_MS = 5_000;

  @PostConstruct
  void init() {
    // Like Flyway's connect-retries (docs/LEDGER_DONE.md OPS-20): an unreachable MinIO at boot
    // would otherwise fail the new task and roll the deploy back.
    for (int attempt = 1; ; attempt++) {
      try {
        ensureBucketExists();
        expireTemporaryObjects();
        return;
      } catch (SdkClientException e) {
        if (attempt == BUCKET_CHECK_ATTEMPTS) {
          throw e;
        }
        LOG.warnf(
            "S3 unreachable (%s), attempt %d/%d", e.getMessage(), attempt, BUCKET_CHECK_ATTEMPTS);
        try {
          Thread.sleep(BUCKET_CHECK_DELAY_MS);
        } catch (InterruptedException interrupted) {
          Thread.currentThread().interrupt();
          throw e;
        }
      }
    }
  }

  private void ensureBucketExists() {
    try {
      s3Client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
      LOG.infof("S3 bucket '%s' exists", bucket);
    } catch (NoSuchBucketException e) {
      LOG.infof("Creating S3 bucket '%s'", bucket);
      s3Client.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
    }
  }

  /**
   * Has the bucket delete what is left under {@link #REENCODE_PREFIX} after a day. {@link #store}
   * deletes its original there in a {@code finally}; only a JVM killed in between leaves
   * one, with the metadata it was about to lose (docs/LEDGER_*.md OPS-17). Replaces the bucket's
   * lifecycle configuration, which holds nothing else. A failure is logged, not fatal: the rule
   * only sweeps up after a crash.
   */
  private void expireTemporaryObjects() {
    try {
      s3Client.putBucketLifecycleConfiguration(
          PutBucketLifecycleConfigurationRequest.builder()
              .bucket(bucket)
              .lifecycleConfiguration(
                  BucketLifecycleConfiguration.builder()
                      .rules(
                          LifecycleRule.builder()
                              .id("expire-reencode-originals")
                              .filter(LifecycleRuleFilter.builder().prefix(REENCODE_PREFIX).build())
                              .expiration(LifecycleExpiration.builder().days(1).build())
                              .status("Enabled")
                              .build())
                      .build())
              .build());
    } catch (S3Exception e) {
      LOG.warnf(
          "Cannot set the expiry of %s in bucket '%s': %s",
          REENCODE_PREFIX, bucket, e.getMessage());
    }
  }

  @Override
  public void store(String key, InputStream content, String contentType, long contentLength) {
    store(key, content, contentType, contentLength, Map.of());
  }

  /**
   * Stores {@code content}; an image is stored re-encoded, hence without its metadata.
   *
   * <p>The one place every file reaches the bucket through — uploaded assets and attachments,
   * avatars, generated thumbnails, the biketeam import — hence the one place metadata is removed,
   * so that no new write path can forget to (docs/LEDGER_*.md API-43). The format is read from the
   * bytes, not from {@code contentType}: a JPEG uploaded as an attachment under a generic type is
   * re-encoded all the same, and stored under the content type of what imgproxy wrote (a HEIC
   * becomes an {@code image/jpeg}, see {@link ImageFormat}).
   *
   * <p>imgproxy reads its sources from the bucket: the original goes under {@link
   * #REENCODE_PREFIX} for the time of the call, and is deleted whatever the outcome.
   *
   * @throws BadRequestException {@link ErrorCode#FILE_TYPE_REJECTED} for an image imgproxy cannot
   *     read (JPEG 2000), {@link ErrorCode#INVALID_FORMAT} for an image imgproxy refuses to decode;
   *     nothing is stored in either case
   */
  @Override
  public long store(
      String key,
      InputStream content,
      String contentType,
      long contentLength,
      Map<String, String> metadata) {
    try {
      BufferedInputStream in = new BufferedInputStream(content, 8192);
      in.mark(ImageFormat.SNIFF_LENGTH);
      ImageFormat format = ImageFormat.sniff(in.readNBytes(ImageFormat.SNIFF_LENGTH));
      in.reset();
      if (format.isRefused()) {
        LOG.warnf("Refusing to store %s: %s image, its metadata cannot be removed", key, format);
        throw new BadRequestException(ErrorCode.FILE_TYPE_REJECTED);
      }
      if (!format.isReencoded()) {
        put(key, in, contentType, contentLength, metadata);
        return contentLength;
      }
      String originalKey = REENCODE_PREFIX + UUID.randomUUID();
      put(originalKey, in, contentType, contentLength, Map.of());
      try {
        byte[] reencoded = reencode(key, format, originalKey);
        LOG.debugf(
            "Re-encoded %s (%s): %d -> %d bytes", key, format, contentLength, reencoded.length);
        put(
            key,
            new ByteArrayInputStream(reencoded),
            format.storedMimeType(),
            reencoded.length,
            metadata);
        return reencoded.length;
      } finally {
        delete(originalKey);
      }
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to store " + key, e);
    }
  }

  private byte[] reencode(String key, ImageFormat format, String originalKey) {
    try {
      return imgProxyClient.reencode(getS3Path(originalKey), format.storedExtension());
    } catch (WebApplicationException e) {
      int status = e.getResponse().getStatus();
      if (status >= 400 && status < 500) {
        LOG.warnf("Refusing to store %s: imgproxy cannot decode this %s (%d)", key, format, status);
        throw new BadRequestException(ErrorCode.INVALID_FORMAT, e);
      }
      throw e;
    }
  }

  private void put(
      String key,
      InputStream content,
      String contentType,
      long contentLength,
      Map<String, String> metadata) {
    PutObjectRequest.Builder requestBuilder =
        PutObjectRequest.builder().bucket(bucket).key(key).contentType(contentType);

    if (metadata != null && !metadata.isEmpty()) {
      requestBuilder.metadata(metadata);
    }

    s3Client.putObject(requestBuilder.build(), RequestBody.fromInputStream(content, contentLength));
    LOG.debugf("Stored object: s3://%s/%s with metadata: %s", bucket, key, metadata);
  }

  @Override
  public InputStream retrieve(String key) {
    GetObjectRequest request = GetObjectRequest.builder().bucket(bucket).key(key).build();

    return s3Client.getObject(request);
  }

  @Override
  public byte[] retrieveHead(String key, int length) {
    GetObjectRequest request =
        GetObjectRequest.builder().bucket(bucket).key(key).range("bytes=0-" + (length - 1)).build();
    try (InputStream in = s3Client.getObject(request)) {
      return in.readNBytes(length);
    } catch (IOException e) {
      throw new UncheckedIOException("Failed to read the head of " + key, e);
    }
  }

  @Override
  public void delete(String key) {
    DeleteObjectRequest request = DeleteObjectRequest.builder().bucket(bucket).key(key).build();

    s3Client.deleteObject(request);
    LOG.debugf("Deleted object: s3://%s/%s", bucket, key);
  }

  @Override
  public void deleteByPrefix(String prefix) {
    for (var page :
        s3Client.listObjectsV2Paginator(
            ListObjectsV2Request.builder().bucket(bucket).prefix(prefix).build())) {
      for (S3Object object : page.contents()) {
        delete(object.key());
      }
    }
  }

  @Override
  public boolean exists(String key) {
    try {
      HeadObjectRequest request = HeadObjectRequest.builder().bucket(bucket).key(key).build();

      s3Client.headObject(request);
      return true;
    } catch (NoSuchKeyException e) {
      return false;
    }
  }

  @Override
  public long size(String key) {
    try {
      HeadObjectRequest request = HeadObjectRequest.builder().bucket(bucket).key(key).build();
      return s3Client.headObject(request).contentLength();
    } catch (NoSuchKeyException e) {
      return -1;
    }
  }

  @Override
  public String getS3Path(String key) {
    return "s3://" + bucket + "/" + key;
  }
}
