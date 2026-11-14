package fr.pedalons.domain.route;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
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
import java.util.List;
import java.util.Map;
import org.jspecify.annotations.Nullable;

/**
 * The street edges osm-route-details matched along one saved track of a team route, as stored in
 * the {@code network_edges} JSONB column of a track (docs/LEDGER_*.md API-198, plan {@code
 * docs/plans/2026-11-13-generateur-boucles-equipe-lot1.md} §2). Not part of the contract: nothing
 * serves it, the team route generator reads it.
 *
 * <p>Keys are short, the document is per track and the team graph reads thousands of them. Nodes
 * are deduplicated and referred to by their index; a polyline is kept as the service sent it. A
 * release must read what a later one wrote (hypersistence's mapper fails on unknown properties), so
 * every level ignores them, and a node is an array that may grow.
 *
 * @param v {@link #VERSION} the document was written with: a bump of it is what makes the backfill
 *     compute it again
 * @param rev the track revision the edges were computed from, the {@code file_id} of the route's
 *     original GPX: a reader uses the document only while it is still the current one
 * @param at when it was computed
 * @param status {@link #STATUS_OK}, or {@link #STATUS_TOO_SHORT} for a track too short to be sent;
 *     a string and not an enum, so that a later value does not make the document unreadable
 * @param api {@code meta.api_version} of the answer
 * @param rules {@code meta.rules_version}
 * @param profile {@code meta.profile}, {@code full} for the routes
 * @param dv {@code meta.data_versions} of the first slice, as received
 * @param len the length of the track on the service's axis, the one {@code fm} and {@code tm}
 *     count on
 * @param unmatched metres of the track the service could not match, per {@code unmatched_reason}
 * @param covered metres of the track covered by an edge
 */
@JsonIgnoreProperties(ignoreUnknown = true)
@JsonInclude(JsonInclude.Include.NON_NULL)
public record NetworkEdgesDocument(
    int v,
    long rev,
    Instant at,
    String status,
    @Nullable String api,
    @Nullable String rules,
    @Nullable String profile,
    @Nullable JsonNode dv,
    double len,
    List<Node> nodes,
    List<Edge> edges,
    Map<String, Double> unmatched,
    double covered)
    implements Serializable {

  /** The shape of this document; the partial index of {@code gpx_tracks} inlines it (V91). */
  public static final int VERSION = 1;

  public static final String STATUS_OK = "ok";
  public static final String STATUS_TOO_SHORT = "too_short";

  /** The key of {@link #dv} that holds the street tiles in the answers of api 1.7. */
  public static final String STREETS_KEY = "streets";

  /** What api 1.7 answers under {@code data_versions}: the street tiles have no id of their own. */
  public static final String TYPOLOGY_KEY = "typology";

  public boolean ok() {
    return STATUS_OK.equals(status);
  }

  /**
   * The version of the street data, as JSON text: {@code data_versions.streets} if the service
   * names it so, else {@code data_versions.typology} (api 1.7, which carries no id or date: it
   * cannot tell two tile updates apart), null when neither is there.
   */
  public @Nullable String streetsVersion() {
    if (dv == null) {
      return null;
    }
    JsonNode streets = dv.get(STREETS_KEY);
    if (streets != null && !streets.isNull()) {
      return streets.toString();
    }
    JsonNode typology = dv.get(TYPOLOGY_KEY);
    return typology == null || typology.isNull() ? null : typology.toString();
  }

  /** A document of a track too short to be sent: no edge, so that no backfill picks it again. */
  public static NetworkEdgesDocument tooShort(long rev, Instant now, double length) {
    return new NetworkEdgesDocument(
        VERSION,
        rev,
        now,
        STATUS_TOO_SHORT,
        null,
        null,
        null,
        null,
        length,
        List.of(),
        List.of(),
        Map.of(),
        0);
  }

  /**
   * {@code [id, lat, lon, degree]}, stored as an array and read leaving out any element after the
   * fourth (a later release may add some).
   */
  @JsonSerialize(using = Node.Writer.class)
  @JsonDeserialize(using = Node.Reader.class)
  public record Node(String id, double lat, double lon, int degree) implements Serializable {

    static final class Writer extends StdSerializer<Node> {
      Writer() {
        super(Node.class);
      }

      @Override
      public void serialize(Node n, JsonGenerator g, SerializerProvider p) throws IOException {
        g.writeStartArray();
        g.writeString(n.id());
        g.writeNumber(n.lat());
        g.writeNumber(n.lon());
        g.writeNumber(n.degree());
        g.writeEndArray();
      }
    }

    static final class Reader extends StdDeserializer<Node> {
      Reader() {
        super(Node.class);
      }

      @Override
      public Node deserialize(JsonParser p, DeserializationContext c) throws IOException {
        JsonNode n = c.readTree(p);
        if (!n.isArray()) {
          c.reportInputMismatch(Object.class, "a node is an array");
        }
        return new Node(
            n.path(0).asText(), n.path(1).asDouble(), n.path(2).asDouble(), n.path(3).asInt());
      }
    }
  }

  /**
   * An edge: what the service says of one run of streets the track rode. {@code fn} / {@code tn}
   * index {@link #nodes} and are absent for an end the service did not know; the offsets are
   * absent with an unknown {@code fn}. {@code st}, {@code sc}/{@code sd}/{@code ss}, {@code wk},
   * {@code tt}, {@code bi} and {@code ft} are present only when homogeneous along the edge (the
   * mix of the others is read from the track's {@code surfaces} document, by {@code fm}/{@code tm}).
   *
   * @param fm {@code from_m} on the track's axis
   * @param p {@code partial}
   * @param len {@code length_m} of the complete edge
   * @param trv {@code traversed_m}
   * @param fo {@code from_offset_m}
   * @param to {@code to_offset_m}
   * @param ow {@code oneway}: {@code both}, {@code forward} or {@code against}
   * @param g {@code geometry}, a polyline of precision 6 in the direction of travel
   * @param fg {@code from_gain_cum_m}
   * @param fl {@code from_loss_cum_m}
   * @param sc surface class, {@code sd} its detail, {@code ss} its source
   * @param tt {@code tracktype} (api 1.8), {@code bi} {@code bicycle}, {@code ft} {@code foot}
   */
  @JsonIgnoreProperties(ignoreUnknown = true)
  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record Edge(
      @JsonProperty("fm") double fm,
      @JsonProperty("tm") double tm,
      @JsonProperty("fn") @Nullable Integer fn,
      @JsonProperty("tn") @Nullable Integer tn,
      @JsonProperty("p") boolean p,
      @JsonProperty("len") @Nullable Double len,
      @JsonProperty("trv") double trv,
      @JsonProperty("fo") @Nullable Double fo,
      @JsonProperty("to") @Nullable Double to,
      @JsonProperty("ow") @Nullable String ow,
      @JsonProperty("g") @Nullable String g,
      @JsonProperty("fg") double fg,
      @JsonProperty("tg") double tg,
      @JsonProperty("fl") double fl,
      @JsonProperty("tl") double tl,
      @JsonProperty("st") @Nullable String st,
      @JsonProperty("sc") @Nullable String sc,
      @JsonProperty("sd") @Nullable String sd,
      @JsonProperty("ss") @Nullable String ss,
      @JsonProperty("wk") @Nullable String wk,
      @JsonProperty("tt") @Nullable String tt,
      @JsonProperty("bi") @Nullable String bi,
      @JsonProperty("ft") @Nullable String ft)
      implements Serializable {}
}
