package fr.pedalons.service.geocode;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/**
 * The gate in front of the place lookup (docs/LEDGER_*.md API-129): what is shaped enough like a GID
 * to be worth a call billed 20 credits. A plain unit test — the wiring is {@code
 * GeocodeResourceTest}.
 */
class GeocodeServiceIdTest {

  @Test
  void realGids_shouldPass() {
    assertTrue(GeocodeService.isValidId("whosonfirst:locality:101750851"));
    assertTrue(GeocodeService.isValidId("whosonfirst:localadmin:404379599"));
    assertTrue(GeocodeService.isValidId("openstreetmap:venue:node/1"));
    assertTrue(GeocodeService.isValidId("openaddresses:address:fr/countrywide:a1b2-c3.d4"));
  }

  @Test
  void anythingElse_shouldBeRefused() {
    assertFalse(GeocodeService.isValidId(null));
    assertFalse(GeocodeService.isValidId(""));
    assertFalse(GeocodeService.isValidId("annecy"));
    assertFalse(GeocodeService.isValidId("whosonfirst:locality"));
    assertFalse(GeocodeService.isValidId("whosonfirst:locality:"));
    assertFalse(GeocodeService.isValidId("WhosOnFirst:locality:1"));
    assertFalse(GeocodeService.isValidId("whosonfirst:locality:1&size=40"));
    assertFalse(GeocodeService.isValidId("whosonfirst:locality:1 2"));
    assertFalse(GeocodeService.isValidId("whosonfirst:locality:1\n"));
  }

  @Test
  void anIdOverTheBound_shouldBeRefused() {
    String prefix = "whosonfirst:locality:";
    assertTrue(
        GeocodeService.isValidId(
            prefix + "1".repeat(GeocodeService.MAX_ID_LENGTH - prefix.length())));
    assertFalse(
        GeocodeService.isValidId(
            prefix + "1".repeat(GeocodeService.MAX_ID_LENGTH - prefix.length() + 1)));
  }
}
