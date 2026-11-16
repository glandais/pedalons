package fr.pedalons.infrastructure.routedetails;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.Base64;
import org.junit.jupiter.api.Test;

class NamespaceKeyTest {

  private static final String VALID = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8";

  @Test
  void a43CharacterKeyOf32BytesIsAccepted() {
    assertEquals(43, VALID.length());
    assertEquals(VALID, NamespaceKey.parse(VALID).reveal());
  }

  @Test
  void paddingIsRefused() {
    assertThrows(IllegalArgumentException.class, () -> NamespaceKey.parse(VALID + "="));
  }

  @Test
  void aKeyOf31BytesIsRefused() {
    String shorter = Base64.getUrlEncoder().withoutPadding().encodeToString(new byte[31]);
    assertThrows(IllegalArgumentException.class, () -> NamespaceKey.parse(shorter));
  }

  @Test
  void theStandardAlphabetIsRefused() {
    assertThrows(
        IllegalArgumentException.class, () -> NamespaceKey.parse("+" + VALID.substring(1)));
    assertThrows(
        IllegalArgumentException.class, () -> NamespaceKey.parse("/" + VALID.substring(1)));
  }

  @Test
  void nullAndEmptyAreRefused() {
    assertThrows(IllegalArgumentException.class, () -> NamespaceKey.parse(""));
    assertThrows(IllegalArgumentException.class, () -> NamespaceKey.parse(null));
  }

  @Test
  void theErrorMessageNeverQuotesTheText() {
    IllegalArgumentException e =
        assertThrows(IllegalArgumentException.class, () -> NamespaceKey.parse("secret+value"));
    assertFalse(e.getMessage().contains("secret"));
  }

  @Test
  void toStringHidesTheKey() {
    assertFalse(NamespaceKey.parse(VALID).toString().contains(VALID.substring(0, 12)));
  }
}
