package fr.pedalons.infrastructure.stadiamaps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import java.util.List;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.Test;

/** The seam to the Stadia Maps geocoder: what it sends, and what it does when the provider misbehaves. */
@QuarkusTest
class GeocodingLookupTest {

  @Inject GeocodingLookup geocodingLookup;

  @InjectMock @RestClient StadiaMapsGeocodingClient geocodingClient;

  @Test
  void search_whenTheProviderFails_shouldReturnEmptyRatherThanPropagate() {
    // A geocoder assists a form field that also accepts a position entered by hand. An outage at
    // Stadia Maps (or a spent quota, 429) must not stop someone from saving their team's meeting
    // point, so the failure is swallowed here rather than surfacing as a 500 on a form.
    when(geocodingClient.autocomplete(anyString(), anyInt(), anyString()))
        .thenThrow(new RuntimeException("upstream down"));

    assertTrue(geocodingLookup.search("chambery-outage", "fr").isEmpty());
  }

  @Test
  void search_whenTheCollectionHasNoFeatures_shouldReturnEmpty() {
    when(geocodingClient.autocomplete(anyString(), anyInt(), anyString()))
        .thenReturn(new GeocodingResponse(null));

    assertTrue(geocodingLookup.search("nulle-part", "fr").isEmpty());
  }

  @Test
  void normalize_shouldFoldCaseAndCollapseWhitespace() {
    // This is what makes the cache hit at all: an autocomplete sends every prefix of what is being
    // typed, and each miss is a billed call. A key that told "Lyon " from "lyon" would not.
    assertEquals(
        "saint jean de maurienne", GeocodingLookup.normalize("  Saint   Jean   de  Maurienne "));
    assertEquals(GeocodingLookup.normalize("lyon"), GeocodingLookup.normalize("LYON"));
  }

  @Test
  void search_shouldAskForTheFiveHitsTheAutocompleteShows() {
    when(geocodingClient.autocomplete(anyString(), anyInt(), anyString()))
        .thenReturn(new GeocodingResponse(List.of()));

    geocodingLookup.search("annecy-limit", "fr");

    org.mockito.Mockito.verify(geocodingClient).autocomplete("annecy-limit", 5, "fr");
  }
}
