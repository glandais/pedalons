package fr.pedalons.service.weather;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

/**
 * The {@code ETag} of a weather body: a digest of what is sent rather than « version + {@code
 * fetchedAt} ». A group's or a stage's time, speed or route changes the passages without touching
 * the publication's version, and the clock alone turns a forecast {@code STALE}; hashing the body
 * catches all of it, and is the same on every instance.
 */
public final class WeatherEtag {

  private WeatherEtag() {}

  public static String of(ObjectMapper objectMapper, Object body) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256").digest(objectMapper.writeValueAsBytes(body));
      return HexFormat.of().formatHex(digest, 0, 16);
    } catch (JacksonException | NoSuchAlgorithmException e) {
      throw new IllegalStateException("Cannot digest a weather body", e);
    }
  }
}
