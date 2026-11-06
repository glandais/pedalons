package fr.pedalons.domain.route;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.SerializerProvider;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;
import com.fasterxml.jackson.databind.deser.std.StdDeserializer;
import com.fasterxml.jackson.databind.ser.std.StdSerializer;
import java.io.IOException;
import java.io.Serializable;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import org.jspecify.annotations.Nullable;

/**
 * The surface along one saved track, as stored in the {@code surfaces} JSONB column of a track or
 * of a preview (docs/LEDGER_*.md WEB-100, C1b). Not part of the contract: the API serves the
 * classes derived from it ({@code SurfaceSpans}).
 *
 * <p>Distances are metres along the track, the {@code M} of its line. The ways are stored and never
 * served.
 *
 * <ul>
 *   <li><b>Version 1</b> (osm-surface, {@link #VERSION}): the codes are Valhalla's raw {@code
 *       surface} values, plus {@link #UNKNOWN} and {@link #OFF_NETWORK}, and which class of the
 *       contract a code belongs to is decided on reading. A way is a {@code use} and a {@code
 *       cycle_lane}.
 *   <li><b>Version 2</b> (osm-route-details, {@link #VERSION_ROUTE_DETAILS}, docs/LEDGER_*.md
 *       API-150): the codes are the classes themselves ({@code TrackSurface.code()}), so that every
 *       release reads them the same way and a rollback serves them right. A change of the
 *       projection therefore means re-projecting from the service's own values, kept in {@code
 *       ways}, rather than a change on reading.
 * </ul>
 *
 * @param status a string and not an enum, so that a value of a later release does not make the
 *     whole document unreadable
 * @param reason when unavailable, what the provider said ({@code valhalla-444}), {@code too-short},
 *     or {@code no-typology} when osm-route-details knows nothing of the whole track
 * @param osmChangeset the OpenStreetMap changeset of the data the provider matched on, when it
 *     answered with one (version 1)
 * @param distance the length of the track when it was computed: the base of the rescale on reading
 * @param dataVersions the versions of the data the answer was made from, {@code meta.data_versions}
 *     of the first slice, as the service gave them (version 2)
 */
// The JSONB column is read by hypersistence's own ObjectMapper, which fails on unknown
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
    List<WayRange> ways,
    @JsonInclude(JsonInclude.Include.NON_NULL) @Nullable JsonNode dataVersions)
    implements Serializable {

  public static final int VERSION = 1;

  /** A document made from the answer of osm-route-details. */
  public static final int VERSION_ROUTE_DETAILS = 2;

  public static final String STATUS_OK = "ok";
  public static final String STATUS_UNAVAILABLE = "unavailable";

  /** Not matched on the network, a stretch the provider could not answer for, or no surface tagged. */
  public static final String UNKNOWN = "unknown";

  /** A straight piece of the route planner (DIRECT): drawn on purpose, outside any way. */
  public static final String OFF_NETWORK = "off_network";

  /** Without {@code dataVersions}: a version 1 document. */
  public TrackSurfaceDocument(
      int version,
      String status,
      @Nullable String reason,
      @Nullable Long osmChangeset,
      Instant computedAt,
      String costing,
      double distance,
      List<SurfaceRange> surfaces,
      List<WayRange> ways) {
    this(
        version, status, reason, osmChangeset, computedAt, costing, distance, surfaces, ways, null);
  }

  public static TrackSurfaceDocument unavailable(
      String reason, double distance, String costing, Instant now) {
    return unavailable(VERSION, reason, distance, costing, now);
  }

  /** As {@link #unavailable(String, double, String, Instant)}, in the given {@code version}. */
  public static TrackSurfaceDocument unavailable(
      int version, String reason, double distance, String costing, Instant now) {
    return new TrackSurfaceDocument(
        version, STATUS_UNAVAILABLE, reason, null, now, costing, distance, List.of(), List.of());
  }

  public boolean ok() {
    return STATUS_OK.equals(status);
  }

  /**
   * {@code [from, to, code]}: metres along the track, a Valhalla {@code surface} value (version 1)
   * or a {@code TrackSurface.code()} (version 2), or {@link #UNKNOWN} / {@link #OFF_NETWORK}. Stored
   * as an array, and read leaving out any element after the third (a later release may add some).
   */
  @JsonSerialize(using = SurfaceRange.Writer.class)
  @JsonDeserialize(using = SurfaceRange.Reader.class)
  public record SurfaceRange(double from, double to, String code) implements Serializable {

    static final class Writer extends StdSerializer<SurfaceRange> {
      Writer() {
        super(SurfaceRange.class);
      }

      @Override
      public void serialize(SurfaceRange r, JsonGenerator g, SerializerProvider p)
          throws IOException {
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
      public SurfaceRange deserialize(JsonParser p, DeserializationContext c) throws IOException {
        JsonNode n = array(p, c);
        String code = text(n, 2);
        return new SurfaceRange(
            n.path(0).asDouble(), n.path(1).asDouble(), code == null ? UNKNOWN : code);
      }
    }
  }

  /**
   * {@code [from, to, use, cycleLane, structure, matched, class, detail]}, stored as an array like
   * {@link SurfaceRange}, null when unknown. Version 1 stops at Valhalla's {@code use} and {@code
   * cycle_lane}: the elements after the last known one are not written. Version 2 holds what
   * osm-route-details said of the stretch: its {@code way_kind} in place of {@code use}, no {@code
   * cycleLane}, then the raw values the class of the surface was projected from, so that a change
   * of the projection needs no call to the service. A release that stops at the fourth element
   * reads such a way as a {@code use} alone.
   */
  @JsonSerialize(using = WayRange.Writer.class)
  @JsonDeserialize(using = WayRange.Reader.class)
  public record WayRange(
      double from,
      double to,
      @Nullable String use,
      @Nullable String cycleLane,
      @Nullable String structure,
      @Nullable Boolean matched,
      @Nullable String surfaceClass,
      @Nullable String detail)
      implements Serializable {

    /** A way of a version 1 document. */
    public WayRange(double from, double to, @Nullable String use, @Nullable String cycleLane) {
      this(from, to, use, cycleLane, null, null, null, null);
    }

    static final class Writer extends StdSerializer<WayRange> {
      Writer() {
        super(WayRange.class);
      }

      @Override
      public void serialize(WayRange r, JsonGenerator g, SerializerProvider p) throws IOException {
        g.writeStartArray();
        g.writeNumber(r.from());
        g.writeNumber(r.to());
        writeNullable(g, r.use());
        writeNullable(g, r.cycleLane());
        // Only up to the last known element: a version 1 way keeps its four
        List<@Nullable Object> rest =
            Arrays.asList(r.structure(), r.matched(), r.surfaceClass(), r.detail());
        int known = rest.size();
        while (known > 0 && rest.get(known - 1) == null) {
          known--;
        }
        for (int i = 0; i < known; i++) {
          if (rest.get(i) instanceof Boolean flag) {
            g.writeBoolean(flag);
          } else {
            writeNullable(g, (String) rest.get(i));
          }
        }
        g.writeEndArray();
      }
    }

    static final class Reader extends StdDeserializer<WayRange> {
      Reader() {
        super(WayRange.class);
      }

      @Override
      public WayRange deserialize(JsonParser p, DeserializationContext c) throws IOException {
        JsonNode n = array(p, c);
        JsonNode matched = n.path(5);
        return new WayRange(
            n.path(0).asDouble(),
            n.path(1).asDouble(),
            text(n, 2),
            text(n, 3),
            text(n, 4),
            matched.isBoolean() ? Boolean.valueOf(matched.asBoolean()) : null,
            text(n, 6),
            text(n, 7));
      }
    }

    private static void writeNullable(JsonGenerator g, @Nullable String value) throws IOException {
      if (value == null) {
        g.writeNull();
      } else {
        g.writeString(value);
      }
    }
  }

  /** The whole array, so that whatever follows the elements known to this release is dropped. */
  private static JsonNode array(JsonParser p, DeserializationContext c) throws IOException {
    JsonNode node = c.readTree(p);
    if (!node.isArray()) {
      c.reportInputMismatch(Object.class, "a range is an array");
    }
    return node;
  }

  private static @Nullable String text(JsonNode array, int index) {
    JsonNode value = array.path(index);
    return value.isNull() || value.isMissingNode() ? null : value.asText();
  }
}
