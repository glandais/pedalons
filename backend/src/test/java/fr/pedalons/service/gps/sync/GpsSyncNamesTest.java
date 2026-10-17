package fr.pedalons.service.gps.sync;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import org.junit.jupiter.api.Test;

/** The names and fingerprints of synchronised routes (docs/LEDGER_*.md API-120 §3.5, D4). */
class GpsSyncNamesTest {

  // 2026-10-17 23:30 UTC is already the 18th in Paris.
  private static final Instant LATE_EVENING = Instant.parse("2026-10-17T23:30:00Z");

  @Test
  void name_startsWithTheLocalDate() {
    assertEquals(
        "2026-10-18 · Groupe A · Boucle",
        GpsSyncNames.autoName(LATE_EVENING, "Europe/Paris", "Groupe A", "Boucle"));
  }

  @Test
  void name_leavesABlankGroupOut() {
    assertEquals("2026-10-17 · Boucle", GpsSyncNames.autoName(LATE_EVENING, "UTC", " ", "Boucle"));
  }

  @Test
  void name_isTruncated() {
    String name = GpsSyncNames.autoName(LATE_EVENING, "UTC", "Groupe", "x".repeat(200));
    assertEquals(GpsSyncNames.MAX_NAME_LENGTH, name.length());
    assertTrue(name.endsWith("…"));
  }

  @Test
  void name_survivesAnUnknownZone() {
    assertTrue(GpsSyncNames.autoName(LATE_EVENING, "Not/AZone", "G", "R").startsWith("2026-10-18"));
  }

  @Test
  void hash_followsTheAssetAndTheName() {
    String base = GpsSyncNames.hash(1L, "a");
    assertEquals(base, GpsSyncNames.hash(1L, "a"));
    assertNotEquals(base, GpsSyncNames.hash(2L, "a"));
    assertNotEquals(base, GpsSyncNames.hash(1L, "b"));
    assertEquals(64, base.length());
  }

  @Test
  void contentKey_isTheAssetIdUntilARevisionExists() {
    assertEquals(5L, GpsSyncNames.contentKey(5L, null));
    assertEquals(9L, GpsSyncNames.contentKey(5L, 9L));
    // Existing rows (null revision) keep their old fingerprint: no mass re-push (API-128).
    assertEquals(
        GpsSyncNames.hash(5L, "n"), GpsSyncNames.hash(GpsSyncNames.contentKey(5L, null), "n"));
  }

  @Test
  void hash_ofAnUnrevisedAssetIsTheFormulaBeforeRevisionsExisted() throws Exception {
    // Neutrality guard (API-128): sha256(assetId + "|" + name), byte for byte, or every synced
    // route would be pushed again at deployment.
    byte[] digest =
        java.security.MessageDigest.getInstance("SHA-256")
            .digest(
                "123456789|2026-10-18 · Boucle".getBytes(java.nio.charset.StandardCharsets.UTF_8));
    String legacy = java.util.HexFormat.of().formatHex(digest);

    assertEquals(
        legacy,
        GpsSyncNames.hash(GpsSyncNames.contentKey(123456789L, null), "2026-10-18 · Boucle"));
    assertNotEquals(
        legacy,
        GpsSyncNames.hash(GpsSyncNames.contentKey(123456789L, 987L), "2026-10-18 · Boucle"));
  }
}
