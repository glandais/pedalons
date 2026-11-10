package fr.pedalons.service.gps.sync;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HexFormat;
import org.jspecify.annotations.Nullable;

/**
 * The names and fingerprints of the routes sent to GPS services (docs/LEDGER_*.md API-120 §3.5,
 * D4, D10). Pure functions: the planner, the worker and the manual upload must agree on them.
 */
public final class GpsSyncNames {

  /** What the services show comfortably; Garmin truncates long names on the device. */
  static final int MAX_NAME_LENGTH = 80;

  private static final DateTimeFormatter DAY = DateTimeFormatter.ISO_LOCAL_DATE;
  private static final String SEPARATOR = " · ";
  private static final String STAGE_SEPARATOR = " - ";

  private GpsSyncNames() {}

  /**
   * {@code YYYY-MM-DD · group · route}, the date local to the ride. The date first keeps apart two
   * rides on the same route, and avoids the prefix collisions Garmin devices are known for. A blank
   * group name is left out.
   */
  public static String autoName(
      Instant groupStartAt, String timezone, String groupName, String routeName) {
    StringBuilder name = new StringBuilder(localDay(groupStartAt, timezone));
    if (!groupName.isBlank()) {
      name.append(SEPARATOR).append(groupName.strip());
    }
    name.append(SEPARATOR).append(routeName.strip());
    return truncate(name.toString());
  }

  /**
   * {@code YYYY-MM-DD - trip - stage}, the date local to the stage (its own zone, not the trip's),
   * with an ASCII separator. A blank trip or stage name is left out. No stage number: a stage
   * reordered keeps its row, and must keep its name with it.
   *
   * <p>Not {@link #autoName}'s {@code ·}: that one is part of the fingerprint of every ride row
   * already sent, and changing it would send them all again (D4).
   */
  public static String stageName(
      Instant stageStartAt, String timezone, String tripName, String stageName) {
    StringBuilder name = new StringBuilder(localDay(stageStartAt, timezone));
    if (!tripName.isBlank()) {
      name.append(STAGE_SEPARATOR).append(tripName.strip());
    }
    if (!stageName.isBlank()) {
      name.append(STAGE_SEPARATOR).append(stageName.strip());
    }
    return truncate(name.toString());
  }

  /** The date of {@code at} in {@code timezone}, Europe/Paris for an unknown zone. */
  private static String localDay(Instant at, String timezone) {
    ZoneId zone;
    try {
      zone = ZoneId.of(timezone);
    } catch (DateTimeException e) {
      zone = ZoneId.of("Europe/Paris");
    }
    return DAY.format(at.atZone(zone));
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
   * What identifies the content of a GPX asset: its content revision when the file was replaced in
   * place by a track edit, else its id. Rows never replaced have no revision, so their key (and
   * therefore their hash) is what it was before the revision existed: no mass re-push.
   * docs/LEDGER_*.md API-128.
   */
  public static Long contentKey(Long assetId, @Nullable Long contentRevision) {
    return contentRevision != null ? contentRevision : assetId;
  }

  /**
   * The fingerprint of what is sent: the GPX content key (see {@link #contentKey}) and the name. A
   * track edit replaces the file under the same asset row but stamps a new content revision, so the
   * fingerprint changes exactly when the trace does — the sanitisation backfill, which rewrites a
   * file in place without touching the revision, sends nothing again (D4). docs/LEDGER_*.md API-128.
   */
  public static String hash(Long contentKey, String name) {
    try {
      byte[] digest =
          MessageDigest.getInstance("SHA-256")
              .digest((contentKey + "|" + name).getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 unavailable", e);
    }
  }

  /**
   * Wahoo's {@code external_id} of a synchronised route: stable for the ride, or the trip stage
   * whose id the row holds in {@code rideId} (D10).
   */
  public static String wahooExternalId(Long domainId, Long rideId) {
    return "pedalons-" + domainId + "-" + rideId;
  }
}
