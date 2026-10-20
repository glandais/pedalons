package fr.pedalons.domain.route;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.io.Serializable;
import java.time.Instant;
import java.util.List;
import org.jspecify.annotations.Nullable;
import tools.jackson.core.JsonGenerator;
import tools.jackson.core.JsonParser;
import tools.jackson.databind.DeserializationContext;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.annotation.JsonDeserialize;
import tools.jackson.databind.annotation.JsonSerialize;
import tools.jackson.databind.deser.std.StdDeserializer;
import tools.jackson.databind.ser.std.StdSerializer;

/**
 * The surface along one saved track, as stored in the {@code surfaces} JSONB column of a track or
 * of a preview (docs/LEDGER_*.md WEB-100, C1b). Not part of the contract: the API serves the
 * classes derived from it ({@code SurfaceSpans}).
 *
 * <p>Distances are metres along the track, the {@code M} of its line. The codes are Valhalla's raw
 * {@code surface} values, plus {@link #UNKNOWN} and {@link #OFF_NETWORK}: which of the classes of
 * the contract a code belongs to is decided on reading, so that changing the classes needs no
 * recompute. The ways ({@code use}, {@code cycle_lane}) are stored and never served.
 *
 * @param status a string and not an enum, so that a value of a later release does not make the
 *     whole document unreadable
 * @param reason when unavailable, what the provider said ({@code valhalla-444}) or {@code
 *     too-short}
 * @param osmChangeset the OpenStreetMap changeset of the data the provider matched on, when it
 *     answered with one
 * @param distance the length of the track when it was computed: the base of the rescale on reading
 */
// The JSONB column is read by JsonbMapper, a plain Jackson ObjectMapper that fails on unknown
// properties: a release must read a document written by a later one (rolling deploy, rollback).
@JsonIgnoreProperties(ignoreUnknown = true)
public record TrackSurfaceDocument(
    int version,
    String status,
    @Nullable String reason,
    @Nullable Long osmChangeset,
    Instant computedAt,
    String costing,
    double distance,
    List<SurfaceRange> surfaces,
    List<WayRange> ways)
    implements Serializable {

  public static final int VERSION = 1;
  public static final String STATUS_OK = "ok";
  public static final String STATUS_UNAVAILABLE = "unavailable";

  /** Not matched on the network, a stretch the provider could not answer for, or no surface tagged. */
  public static final String UNKNOWN = "unknown";

  /** A straight piece of the route planner (DIRECT): drawn on purpose, outside any way. */
  public static final String OFF_NETWORK = "off_network";

  public static TrackSurfaceDocument unavailable(
      String reason, double distance, String costing, Instant now) {
    return new TrackSurfaceDocument(
        VERSION, STATUS_UNAVAILABLE, reason, null, now, costing, distance, List.of(), List.of());
  }

  public boolean ok() {
    return STATUS_OK.equals(status);
  }

  /**
   * {@code [from, to, code]}: metres along the track, a Valhalla {@code surface} value or {@link
   * #UNKNOWN} / {@link #OFF_NETWORK}. Stored as an array, and read leaving out any element after
   * the third (a later release may add some).
   */
  @JsonSerialize(using = SurfaceRange.Writer.class)
  @JsonDeserialize(using = SurfaceRange.Reader.class)
  public record SurfaceRange(double from, double to, String code) implements Serializable {

    static final class Writer extends StdSerializer<SurfaceRange> {
      Writer() {
        super(SurfaceRange.class);
      }

      @Override
      public void serialize(SurfaceRange r, JsonGenerator g, SerializationContext p) {
        g.writeStartArray();
        g.writeNumber(r.from());
        g.writeNumber(r.to());
        g.writeString(r.code());
        g.writeEndArray();
      }
    }

    static final class Reader extends StdDeserializer<SurfaceRange> {
      Reader() {
        super(SurfaceRange.class);
      }

      @Override
      public SurfaceRange deserialize(JsonParser p, DeserializationContext c) {
        JsonNode n = array(p, c);
        String code = text(n, 2);
        return new SurfaceRange(
            n.path(0).asDouble(), n.path(1).asDouble(), code == null ? UNKNOWN : code);
      }
    }
  }

  /**
   * {@code [from, to, use, cycleLane]}: Valhalla's {@code use} and {@code cycle_lane}, null when
   * unknown. Stored as an array, like {@link SurfaceRange}.
   */
  @JsonSerialize(using = WayRange.Writer.class)
  @JsonDeserialize(using = WayRange.Reader.class)
  public record WayRange(double from, double to, @Nullable String use, @Nullable String cycleLane)
      implements Serializable {

    static final class Writer extends StdSerializer<WayRange> {
      Writer() {
        super(WayRange.class);
      }

      @Override
      public void serialize(WayRange r, JsonGenerator g, SerializationContext p) {
        g.writeStartArray();
        g.writeNumber(r.from());
        g.writeNumber(r.to());
        writeNullable(g, r.use());
        writeNullable(g, r.cycleLane());
        g.writeEndArray();
      }
    }

    static final class Reader extends StdDeserializer<WayRange> {
      Reader() {
        super(WayRange.class);
      }

      @Override
      public WayRange deserialize(JsonParser p, DeserializationContext c) {
        JsonNode n = array(p, c);
        return new WayRange(n.path(0).asDouble(), n.path(1).asDouble(), text(n, 2), text(n, 3));
      }
    }

    private static void writeNullable(JsonGenerator g, @Nullable String value) {
      if (value == null) {
        g.writeNull();
      } else {
        g.writeString(value);
      }
    }
  }

  /** The whole array, so that whatever follows the elements known to this release is dropped. */
  private static JsonNode array(JsonParser p, DeserializationContext c) {
    JsonNode node = c.readTree(p);
    if (!node.isArray()) {
      c.reportInputMismatch(Object.class, "a range is an array");
    }
    return node;
  }

  private static @Nullable String text(JsonNode array, int index) {
    JsonNode value = array.path(index);
    return value.isNull() || value.isMissingNode() ? null : value.asString();
  }
}
