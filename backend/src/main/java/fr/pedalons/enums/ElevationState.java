package fr.pedalons.enums;

/**
 * Where a stored elevation profile stands, kept on the route or preview itself (docs/LEDGER_*.md
 * API-131).
 *
 * <p>Not to be mixed with {@link ElevationQuality}, which only picks the source a computation reads.
 */
public enum ElevationState {
  /** The fast profile is stored and the HD recomputation is scheduled. */
  PENDING,
  /** The precise profile (IGN LiDAR HD) is stored. */
  HD,
  /** The fast profile is kept: the HD recomputation failed for good. */
  FAST;

  /**
   * The state a stored value stands for: {@code null} is a track computed before the column
   * existed (pipeline v2, IGN) — or by the previous release during a rolling deploy — hence HD.
   */
  public static ElevationState orHd(@org.jspecify.annotations.Nullable ElevationState stored) {
    return stored == null ? HD : stored;
  }
}
