package fr.pedalons.infrastructure.storage;

import java.io.InputStream;
import java.util.Map;

/** Storage service abstraction for file storage operations. */
public interface StorageService {

  /**
   * Stores content in the storage backend.
   *
   * @param key the storage key (path within the bucket)
   * @param content the input stream containing the content
   * @param contentType the MIME type of the content
   * @param contentLength the length of the content in bytes
   */
  void store(String key, InputStream content, String contentType, long contentLength);

  /**
   * Stores content in the storage backend with custom metadata.
   *
   * <p><strong>An image is stored re-encoded, without its metadata</strong> (EXIF with the GPS
   * position, XMP, IPTC, comments), rotated upright, whatever the caller: the stored object differs
   * from {@code content}, in size and possibly in format and content type (a HEIC becomes a JPEG).
   * See {@code ImageFormat}, docs/LEDGER_*.md API-43.
   *
   * @param key the storage key (path within the bucket)
   * @param content the input stream containing the content
   * @param contentType the MIME type of the content
   * @param contentLength the length of the content in bytes
   * @param metadata custom metadata to attach to the object
   * @return the size in bytes of what was stored — not {@code contentLength} for a re-encoded image
   */
  long store(
      String key,
      InputStream content,
      String contentType,
      long contentLength,
      Map<String, String> metadata);

  /**
   * Retrieves content from the storage backend.
   *
   * @param key the storage key
   * @return an input stream for reading the content
   */
  InputStream retrieve(String key);

  /**
   * The first bytes of stored content, without downloading the rest — enough to sniff a format.
   *
   * @param key the storage key
   * @param length how many leading bytes to return at most
   * @return up to {@code length} bytes, fewer when the content is shorter
   */
  byte[] retrieveHead(String key, int length);

  /**
   * Deletes content from the storage backend.
   *
   * @param key the storage key
   */
  void delete(String key);

  /**
   * Deletes every object whose key starts with {@code prefix}, listing the bucket to find them.
   *
   * @param prefix the key prefix, ending with {@code /} to stay inside one folder
   */
  void deleteByPrefix(String prefix);

  /**
   * Checks if content exists in the storage backend.
   *
   * @param key the storage key
   * @return true if the content exists, false otherwise
   */
  boolean exists(String key);

  /**
   * Size of the stored content, read from its metadata without downloading it.
   *
   * @param key the storage key
   * @return the size in bytes, or -1 if there is no such content
   */
  long size(String key);

  /**
   * Returns the S3 path for use with imgproxy.
   *
   * @param key the storage key
   * @return the S3 URI in format s3://bucket/key
   */
  String getS3Path(String key);
}
