package fr.pedalons.service.route.network;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * The digest of what feeds a team's overlay (lot 3b plan §6.2): SHA-256 of the seven aggregates of
 * the {@link Fingerprint} and of {@link #FORMAT}. Sent with the deposit ({@code
 * Ord-Source-Digest}), read back by the status, compared the next night: equal means nothing the
 * service would match has changed. Never logged.
 *
 * <p>Sums can cancel out (a track replaced by another of the same id sum and size is not
 * realistic, but a pair of changes might): the redeposit seven days before expiry bounds the gap
 * to a week.
 */
public final class OverlayDigest {
  private OverlayDigest() {}

  /**
   * The shape of what the backend sends. Raise it when the NDJSON line or the rule that picks the
   * documents changes: every digest then differs and every team is deposited again.
   */
  public static final int FORMAT = 1;

  public static String of(Fingerprint f) {
    String text =
        f.routes()
            + "|"
            + f.routeState()
            + "|"
            + f.tracks()
            + "|"
            + f.trackIds()
            + "|"
            + f.trackVersions()
            + "|"
            + f.documents()
            + "|"
            + f.documentBytes()
            + "|"
            + FORMAT;
    try {
      byte[] hash =
          MessageDigest.getInstance("SHA-256").digest(text.getBytes(StandardCharsets.UTF_8));
      return "p" + FORMAT + "-" + HexFormat.of().formatHex(hash);
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException(e);
    }
  }
}
