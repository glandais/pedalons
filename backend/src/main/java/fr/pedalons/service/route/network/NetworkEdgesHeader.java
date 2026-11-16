package fr.pedalons.service.route.network;

import com.fasterxml.jackson.core.JsonFactory;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.JsonToken;
import fr.pedalons.domain.route.NetworkEdgesDocument;
import java.io.IOException;
import org.jspecify.annotations.Nullable;

/**
 * The three top-level fields of a stored {@code network_edges} document that say whether it is
 * current ({@code v}, {@code rev}, {@code status}), read by a streaming parser that skips {@code
 * nodes} and {@code edges}: a 4 MB document is never built (lot 3b plan §6.3). Pure.
 *
 * <p>The rule is the lot 1 one: the version of the code, a status {@code ok} or {@code too_short}
 * and a revision equal to the {@code file_id} of the route's current original GPX. A document that
 * is not current is sent as {@code null}, and counts as unreadable at the service.
 */
public final class NetworkEdgesHeader {

  private static final JsonFactory FACTORY = new JsonFactory();

  private NetworkEdgesHeader() {}

  /** What the header says; absent fields are {@code null}. */
  public record Header(@Nullable Integer v, @Nullable Long rev, @Nullable String status) {
    boolean complete() {
      return v != null && rev != null && status != null;
    }
  }

  /** The header, or {@code null} when the text is not a JSON object. */
  public static @Nullable Header read(@Nullable String document) {
    if (document == null) {
      return null;
    }
    Integer v = null;
    Long rev = null;
    String status = null;
    try (JsonParser parser = FACTORY.createParser(document)) {
      if (parser.nextToken() != JsonToken.START_OBJECT) {
        return null;
      }
      while (parser.nextToken() == JsonToken.FIELD_NAME) {
        String name = parser.currentName();
        JsonToken value = parser.nextToken();
        switch (name) {
          case "v" -> v = value == JsonToken.VALUE_NUMBER_INT ? parser.getIntValue() : null;
          case "rev" -> rev = value == JsonToken.VALUE_NUMBER_INT ? parser.getLongValue() : null;
          case "status" -> status = value == JsonToken.VALUE_STRING ? parser.getText() : null;
          default -> parser.skipChildren();
        }
        if (v != null && rev != null && status != null) {
          break;
        }
      }
    } catch (IOException | RuntimeException e) {
      return null;
    }
    return new Header(v, rev, status);
  }

  /** Whether the document may serve: the lot 1 rule, against the route's current original. */
  public static boolean current(@Nullable Header header, @Nullable Long original) {
    return header != null
        && original != null
        && header.v() != null
        && header.v() == NetworkEdgesDocument.VERSION
        && (NetworkEdgesDocument.STATUS_OK.equals(header.status())
            || NetworkEdgesDocument.STATUS_TOO_SHORT.equals(header.status()))
        && header.rev() != null
        && header.rev().equals(original);
  }
}
