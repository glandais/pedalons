package fr.pedalons.service.route.network;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import fr.pedalons.domain.route.NetworkEdgesDocument;
import org.junit.jupiter.api.Test;

class NetworkEdgesHeaderTest {

  private static String document(int v, long rev, String status) {
    // keys in the order jsonb writes them (short first), the big arrays among them
    return "{\"v\": "
        + v
        + ", \"at\": \"2026-11-01T00:00:00Z\", \"dv\": {\"streets\": 3, \"x\": [1, 2]}, \"len\":"
        + " 10.5, \"rev\": "
        + rev
        + ", \"edges\": [{\"a\": [1, 2, 3]}, {\"b\": {}}], \"nodes\": [[\"z14:1:1\", 1.0, 2.0, 3]],"
        + " \"status\": \""
        + status
        + "\", \"covered\": 3.0}";
  }

  @Test
  void readsThePlainFields() {
    NetworkEdgesHeader.Header h = NetworkEdgesHeader.read(document(1, 42, "ok"));
    assertNotNull(h);
    assertEquals(1, h.v());
    assertEquals(42L, h.rev());
    assertEquals("ok", h.status());
  }

  @Test
  void aCurrentDocumentIsOneOfTheCurrentVersionWithTheCurrentOriginal() {
    String ok = document(NetworkEdgesDocument.VERSION, 42, "ok");
    assertTrue(NetworkEdgesHeader.current(NetworkEdgesHeader.read(ok), 42L));
    assertTrue(
        NetworkEdgesHeader.current(
            NetworkEdgesHeader.read(document(NetworkEdgesDocument.VERSION, 42, "too_short")), 42L));
  }

  @Test
  void aStaleRevisionAnUnknownVersionAnUnknownStatusOrNoOriginalIsNotCurrent() {
    String ok = document(NetworkEdgesDocument.VERSION, 42, "ok");
    assertFalse(NetworkEdgesHeader.current(NetworkEdgesHeader.read(ok), 43L));
    assertFalse(NetworkEdgesHeader.current(NetworkEdgesHeader.read(ok), null));
    assertFalse(NetworkEdgesHeader.current(NetworkEdgesHeader.read(document(99, 42, "ok")), 42L));
    assertFalse(
        NetworkEdgesHeader.current(
            NetworkEdgesHeader.read(document(NetworkEdgesDocument.VERSION, 42, "weird")), 42L));
  }

  @Test
  void aDocumentThatIsNotAnObjectIsUnreadable() {
    assertNull(NetworkEdgesHeader.read(null));
    assertNull(NetworkEdgesHeader.read("[1, 2]"));
    assertNull(NetworkEdgesHeader.read("not json"));
    assertFalse(NetworkEdgesHeader.current(NetworkEdgesHeader.read("{\"v\": 1"), 1L));
  }
}
