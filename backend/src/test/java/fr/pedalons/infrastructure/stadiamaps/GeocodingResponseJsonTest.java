package fr.pedalons.infrastructure.stadiamaps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

/**
 * The shape of a real {@code GET /geocoding/v1/autocomplete} answer, as captured on
 * api-eu.stadiamaps.com on 2026-10-17 and trimmed. A plain unit test: nothing here needs Quarkus,
 * and the point is the record mapping — GeoJSON puts longitude first, and {@code properties} has
 * forty fields we must ignore without failing.
 */
class GeocodingResponseJsonTest {

  private static final String SAMPLE =
      """
      {"bbox":[5.871464,45.547972,5.9415,45.6482014],
       "features":[
         {"type":"Feature","bbox":[5.871464,45.547972,5.9415,45.616299],
          "geometry":{"type":"Point","coordinates":[5.909277,45.584386]},
          "properties":{"accuracy":"centroid",
            "addendum":{"concordances":{"gn:id":3027422,"wd:id":"Q165090","wk:page":"Chambéry"}},
            "gid":"whosonfirst:locality:101749323","id":"101749323",
            "label":"Chambéry, France","layer":"locality","name":"Chambéry",
            "continent":"Europe","country":"France","country_a":"FRA","country_code":"FR",
            "county":"Chambéry","localadmin":"Chambéry","locality":"Chambéry",
            "region":"Auvergne-Rhône-Alpes","source":"whosonfirst","confidence":0.6}},
         {"type":"Feature","geometry":null,
          "properties":{"gid":"openstreetmap:venue:node/1","label":"Sans point"}}
       ],
       "geocoding":{"version":"0.2","query":{"text":"chambéry","size":5,"lang":{"iso6391":"fr"}}},
       "type":"FeatureCollection"}
      """;

  @Test
  void shouldReadCoordinatesLabelAndGid_andIgnoreTheRest() throws Exception {
    GeocodingResponse response = new ObjectMapper().readValue(SAMPLE, GeocodingResponse.class);

    assertEquals(2, response.featuresOrEmpty().size());
    GeocodingFeature chambery = response.featuresOrEmpty().get(0);
    assertEquals("whosonfirst:locality:101749323", chambery.gid());
    assertEquals("Chambéry, France", chambery.label());
    // GeoJSON: [lon, lat]. Swapping them would put Chambéry in the Indian Ocean.
    assertEquals(45.584386, chambery.lat());
    assertEquals(5.909277, chambery.lon());

    GeocodingFeature noPoint = response.featuresOrEmpty().get(1);
    assertEquals("Sans point", noPoint.label());
    assertNull(noPoint.lat());
    assertNull(noPoint.lon());
  }

  @Test
  void aCollectionWithoutFeatures_shouldReadAsEmpty() throws Exception {
    GeocodingResponse response =
        new ObjectMapper().readValue("{\"type\":\"FeatureCollection\"}", GeocodingResponse.class);
    assertEquals(0, response.featuresOrEmpty().size());
  }
}
