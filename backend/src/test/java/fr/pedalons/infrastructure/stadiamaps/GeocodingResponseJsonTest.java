package fr.pedalons.infrastructure.stadiamaps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

/**
 * The shape of real {@code GET /geocoding/v2/autocomplete} and {@code GET
 * /geocoding/v2/place_details} answers, as captured on api-eu.stadiamaps.com on 2026-10-17 and
 * trimmed (docs/LEDGER_*.md API-129). A plain unit test: nothing here needs Quarkus, and the point
 * is the record mapping — v2 has no {@code label}, an autocomplete hit usually has no geometry,
 * GeoJSON puts longitude first, and unknown properties must be ignored without failing.
 */
class GeocodingResponseJsonTest {

  private static final String AUTOCOMPLETE =
      """
      {"features":[
         {"type":"Feature","geometry":null,
          "properties":{"coarse_location":"France","gid":"whosonfirst:locality:101750851",
            "layer":"locality","name":"Annecy","precision":"centroid"}},
         {"type":"Feature","geometry":null,
          "properties":{"coarse_location":"Annecy, France","gid":"whosonfirst:neighbourhood:1",
            "layer":"neighbourhood","name":"Annecy-le-Vieux","precision":"centroid"}}
       ],
       "type":"FeatureCollection"}
      """;

  private static final String PLACE_DETAILS =
      """
      {"features":[
         {"type":"Feature","bbox":[6.0821,45.8726,6.1758,45.9378],
          "geometry":{"type":"Point","coordinates":[6.12273,45.89964]},
          "properties":{"coarse_location":"France","gid":"whosonfirst:localadmin:404379599",
            "layer":"localadmin","name":"Annecy","precision":"centroid",
            "context":{"iso_3166_a2":"FR","iso_3166_a3":"FRA"}}}
       ],
       "type":"FeatureCollection"}
      """;

  private static final ObjectMapper MAPPER = new ObjectMapper();

  @Test
  void autocomplete_shouldReadGidAndBuildTheDisplayName_withNoPosition() throws Exception {
    GeocodingResponse response = MAPPER.readValue(AUTOCOMPLETE, GeocodingResponse.class);

    assertEquals(2, response.featuresOrEmpty().size());
    GeocodingFeature annecy = response.featuresOrEmpty().get(0);
    assertEquals("whosonfirst:locality:101750851", annecy.gid());
    // No label in v2: name + coarse_location.
    assertEquals("Annecy, France", annecy.displayName());
    // geometry: null is the norm in a v2 autocomplete; the position comes from place_details.
    assertNull(annecy.lat());
    assertNull(annecy.lon());

    assertEquals(
        "Annecy-le-Vieux, Annecy, France", response.featuresOrEmpty().get(1).displayName());
  }

  @Test
  void placeDetails_shouldReadThePointInLatLonOrder() throws Exception {
    GeocodingResponse response = MAPPER.readValue(PLACE_DETAILS, GeocodingResponse.class);

    GeocodingFeature annecy = response.featuresOrEmpty().get(0);
    // Asked for locality:101750851, answered localadmin:404379599 — never match on the id.
    assertEquals("whosonfirst:localadmin:404379599", annecy.gid());
    assertEquals("Annecy, France", annecy.displayName());
    // GeoJSON: [lon, lat]. Swapping them would put Annecy in the Indian Ocean.
    assertEquals(45.89964, annecy.lat());
    assertEquals(6.12273, annecy.lon());
  }

  @Test
  void autocomplete_shouldReadAGeometryWhenOneIsPresent() throws Exception {
    // v2 may give a point for some hits: used whenever present, saving a place lookup.
    GeocodingResponse response =
        MAPPER.readValue(
            """
            {"features":[{"type":"Feature",
              "geometry":{"type":"Point","coordinates":[5.909277,45.584386]},
              "properties":{"gid":"whosonfirst:locality:101749323","name":"Chambéry",
                "coarse_location":"France"}}],"type":"FeatureCollection"}
            """,
            GeocodingResponse.class);

    GeocodingFeature chambery = response.featuresOrEmpty().get(0);
    assertEquals(45.584386, chambery.lat());
    assertEquals(5.909277, chambery.lon());
  }

  @Test
  void displayName_withoutCoarseLocation_shouldBeTheNameAlone() {
    assertEquals("Annecy", feature("Annecy", null).displayName());
    assertEquals("Annecy", feature("Annecy", "  ").displayName());
    assertEquals("Annecy, France", feature(" Annecy ", " France ").displayName());
  }

  @Test
  void displayName_withoutName_shouldBeNull() {
    assertNull(feature(null, "France").displayName());
    assertNull(feature(" ", "France").displayName());
    assertNull(new GeocodingFeature(null, null).displayName());
  }

  @Test
  void aPointWithOneCoordinate_shouldReadAsNoPosition() {
    GeocodingFeature feature =
        new GeocodingFeature(new GeocodingFeature.Geometry(List.of(6.1)), null);
    assertNull(feature.lat());
    assertNull(feature.lon());
  }

  @Test
  void aCollectionWithoutFeatures_shouldReadAsEmpty() throws Exception {
    GeocodingResponse response =
        MAPPER.readValue("{\"type\":\"FeatureCollection\"}", GeocodingResponse.class);
    assertEquals(0, response.featuresOrEmpty().size());
  }

  private static GeocodingFeature feature(String name, String coarseLocation) {
    return new GeocodingFeature(
        null, new GeocodingFeature.Properties("whosonfirst:locality:1", name, coarseLocation));
  }
}
