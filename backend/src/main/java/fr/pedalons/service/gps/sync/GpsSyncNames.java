package fr.pedalons.service.gps.sync;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;

/**
 * The names and fingerprints of the routes sent to GPS services (docs/LEDGER_*.md API-120 §3.5,
 * D4, D10). Pure functions: the planner, the worker and the manual upload must agree on them.
 */
public final class GpsSyncNames {

  /** What the services show comfortably; Garmin truncates long names on the device. */
  static final int MAX_NAME_LENGTH = 80;

  private static final DateTimeFormatter DAY = DateTimeFormatter.ISO_LOCAL_DATE;
  private static final String SEPARATOR = " · ";

  private GpsSyncNames() {}

  /**
   * {@code YYYY-MM-DD · group · route}, the date local to the ride. The date first keeps apart two
   * rides on the same route, and avoids the prefix collisions Garmin devices are known for. A blank
   * group name is left out.
   */
  public static String autoName(
      Instant groupStartAt, String timezone, String groupName, String routeName) {
    ZoneId zone;
    try {
      zone = ZoneId.of(timezone);
    } catch (DateTimeException e) {
      zone = ZoneId.of("Europe/Paris");
    }
    StringBuilder name = new StringBuilder(DAY.format(groupStartAt.atZone(zone)));
    if (!groupName.isBlank()) {
      name.append(SEPARATOR).append(groupName.strip());
    }
    name.append(SEPARATOR).append(routeName.strip());
    return truncate(name.toString());
  }

  static String truncate(String name) {
    if (name.length() <= MAX_NAME_LENGTH) {
      return name;
    }
    int end = MAX_NAME_LENGTH - 1;
    // Never cut a surrogate pair in two.
    if (Character.isHighSurrogate(name.charAt(end - 1))) {
      end--;
    }
    return name.substring(0, end).stripTrailing() + "…";
  }

  /**
   * The fingerprint of what is sent: the GPX asset and the name. A new GPX makes a new asset, so the
   * fingerprint changes exactly when the trace does — the sanitisation backfill, which rewrites a
   * file in place, sends nothing again (D4).
   */
  public static String hash(Long gpxAssetId, String name) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256")
              .digest((gpxAssetId + "|" + name).getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 unavailable", e);
    }
  }

  /** Wahoo's {@code external_id} of a synchronised route: stable for the ride (D10). */
  public static String wahooExternalId(Long domainId, Long rideId) {
    return "pedalons-" + domainId + "-" + rideId;
  }
}
