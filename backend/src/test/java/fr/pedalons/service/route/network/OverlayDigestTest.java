package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigInteger;
import org.junit.jupiter.api.Test;

class OverlayDigestTest {

  private static Fingerprint fingerprint(long routes, long documentBytes) {
    return new Fingerprint(routes, 5, 7, BigInteger.valueOf(12345), 3, 7, documentBytes);
  }

  @Test
  void theSameFingerprintGivesTheSameDigest() {
    assertEquals(OverlayDigest.of(fingerprint(3, 100)), OverlayDigest.of(fingerprint(3, 100)));
  }

  @Test
  void eachFieldChangesTheDigest() {
    String base = OverlayDigest.of(fingerprint(3, 100));
    assertNotEquals(base, OverlayDigest.of(fingerprint(4, 100)));
    assertNotEquals(base, OverlayDigest.of(fingerprint(3, 101)));
    assertNotEquals(
        base, OverlayDigest.of(new Fingerprint(3, 6, 7, BigInteger.valueOf(12345), 3, 7, 100)));
    assertNotEquals(
        base, OverlayDigest.of(new Fingerprint(3, 5, 7, BigInteger.valueOf(12346), 3, 7, 100)));
  }

  @Test
  void itCarriesTheFormatAndIsHexadecimal() {
    String digest = OverlayDigest.of(fingerprint(3, 100));
    assertTrue(digest.matches("p" + OverlayDigest.FORMAT + "-[0-9a-f]{64}"), digest);
  }
}
