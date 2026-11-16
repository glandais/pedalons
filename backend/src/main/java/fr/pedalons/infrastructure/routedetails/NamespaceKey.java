package fr.pedalons.infrastructure.routedetails;

import java.util.Base64;
import java.util.regex.Pattern;

/**
 * The secret of an environment towards the route generator of osm-route-details ({@code
 * Ord-Namespace-Key}, lot 3b plan §1): 32 random bytes in base64url without padding, 43
 * characters. The service derives from it the storage namespace and the encryption key of the team
 * overlays and keeps none of it.
 *
 * <p>{@link #toString()} never shows it: a key in a log line, an exception message or a metric tag
 * would be the whole environment. Only {@link #reveal()} gives it, for the header.
 */
public final class NamespaceKey {

  /** Characters of a key. */
  public static final int LENGTH = 43;

  private static final Pattern FORMAT = Pattern.compile("^[A-Za-z0-9_-]{" + LENGTH + "}$");

  private final String value;

  private NamespaceKey(String value) {
    this.value = value;
  }

  /**
   * @throws IllegalArgumentException when {@code text} is not 43 characters of the base64url
   *     alphabet that decode to 32 bytes; the message never quotes the text
   */
  public static NamespaceKey parse(String text) {
    if (text == null || !FORMAT.matcher(text).matches()) {
      throw new IllegalArgumentException(
          "The route generator namespace key must be " + LENGTH + " base64url characters");
    }
    byte[] bytes;
    try {
      bytes = Base64.getUrlDecoder().decode(text);
    } catch (IllegalArgumentException e) {
      throw new IllegalArgumentException("The route generator namespace key is not base64url");
    }
    if (bytes.length != 32) {
      throw new IllegalArgumentException("The route generator namespace key must be 32 bytes");
    }
    return new NamespaceKey(text);
  }

  /** The key as the header carries it. */
  public String reveal() {
    return value;
  }

  @Override
  public String toString() {
    return "NamespaceKey[hidden]";
  }
}
