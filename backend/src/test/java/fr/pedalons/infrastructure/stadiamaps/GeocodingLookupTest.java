package fr.pedalons.infrastructure.stadiamaps;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import fr.pedalons.common.exception.ServiceUnavailableException;
import fr.pedalons.dto.error.ErrorCode;
import io.quarkus.test.InjectMock;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.ws.rs.ProcessingException;
import jakarta.ws.rs.WebApplicationException;
import java.util.List;
import java.util.Optional;
import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.junit.jupiter.api.Test;

/**
 * The seam to the Stadia Maps geocoder: what it sends, and what it does when the provider
 * misbehaves. Every test uses a query or an id of its own: the caches outlive a test method.
 */
@QuarkusTest
class GeocodingLookupTest {

  @Inject GeocodingLookup geocodingLookup;

  @InjectMock @RestClient StadiaMapsGeocodingClient geocodingClient;

  private static GeocodingFeature point(String gid, double lon, double lat) {
    return new GeocodingFeature(
        new GeocodingFeature.Geometry(List.of(lon, lat)),
        new GeocodingFeature.Properties(gid, "Annecy", "France"));
  }

  @Test
  void search_whenTheProviderFails_shouldReturnEmptyRatherThanPropagate() {
    // A geocoder assists an optional form field. An outage at Stadia Maps (or a spent quota, 429)
    // must not stop someone from saving their team, so the failure is swallowed here rather than
    // surfacing as a 500 on a form.
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

    verify(geocodingClient).autocomplete("annecy-limit", 5, "fr");
  }

  @Test
  void place_shouldTakeTheFirstFeatureWithAPoint_whateverItsGid() {
    // place_details may answer another GID than the one asked (locality → localadmin).
    when(geocodingClient.placeDetails("whosonfirst:locality:9001", "fr"))
        .thenReturn(
            new GeocodingResponse(
                List.of(
                    new GeocodingFeature(null, new GeocodingFeature.Properties("x:y:1", "A", null)),
                    point("whosonfirst:localadmin:404379599", 6.12273, 45.89964))));

    Optional<GeocodingFeature> place = geocodingLookup.place("whosonfirst:locality:9001", "fr");

    assertTrue(place.isPresent());
    assertEquals(45.89964, place.get().lat());
    assertEquals(6.12273, place.get().lon());
  }

  @Test
  void place_shouldBeCached_onIdAndLanguage() {
    // 20 credits a lookup: the second ask for the same place must not reach Stadia Maps.
    when(geocodingClient.placeDetails("whosonfirst:locality:9002", "fr"))
        .thenReturn(new GeocodingResponse(List.of(point("whosonfirst:locality:9002", 6.1, 45.9))));

    geocodingLookup.place("whosonfirst:locality:9002", "fr");
    geocodingLookup.place("whosonfirst:locality:9002", "fr");

    verify(geocodingClient, times(1)).placeDetails("whosonfirst:locality:9002", "fr");
  }

  @Test
  void place_whenTheProviderKnowsNothing_shouldBeEmpty() {
    when(geocodingClient.placeDetails("whosonfirst:locality:9003", "fr"))
        .thenReturn(new GeocodingResponse(List.of()));

    assertTrue(geocodingLookup.place("whosonfirst:locality:9003", "fr").isEmpty());
  }

  @Test
  void place_whenTheProviderRejectsTheId_shouldBeEmpty() {
    when(geocodingClient.placeDetails("whosonfirst:locality:9004", "fr"))
        .thenThrow(new WebApplicationException(400));

    assertTrue(geocodingLookup.place("whosonfirst:locality:9004", "fr").isEmpty());
  }

  @Test
  void place_whenTheProviderAnswers404_shouldBeEmpty() {
    // An upstream 404 is an unknown id, like a 400: empty, so the endpoint answers 404 too.
    when(geocodingClient.placeDetails("whosonfirst:locality:9007", "fr"))
        .thenThrow(new WebApplicationException(404));

    assertTrue(geocodingLookup.place("whosonfirst:locality:9007", "fr").isEmpty());
  }

  @Test
  void place_whenTheKeyIsRejected_shouldBeA503_notAnUnknownPlace() {
    // A 401 is our misconfiguration, not the user's id: it must not turn into a cached "no such
    // place" (which would hide a bad key behind silent 404s for 24 hours).
    when(geocodingClient.placeDetails("whosonfirst:locality:9008", "fr"))
        .thenThrow(new WebApplicationException(401));

    ServiceUnavailableException e =
        assertThrows(
            ServiceUnavailableException.class,
            () -> geocodingLookup.place("whosonfirst:locality:9008", "fr"));
    assertEquals(ErrorCode.GEOCODING_UNAVAILABLE, e.getErrorCode());
  }

  @Test
  void place_whenTheProviderFailsWith5xx_shouldBeA503() {
    when(geocodingClient.placeDetails("whosonfirst:locality:9009", "fr"))
        .thenThrow(new WebApplicationException(500));

    ServiceUnavailableException e =
        assertThrows(
            ServiceUnavailableException.class,
            () -> geocodingLookup.place("whosonfirst:locality:9009", "fr"));
    assertEquals(ErrorCode.GEOCODING_UNAVAILABLE, e.getErrorCode());
  }

  @Test
  void place_whenTheQuotaIsSpent_shouldBeA503_andNotCached() {
    // Unlike search, the user has picked a place and waits for its position: they must be told.
    when(geocodingClient.placeDetails("whosonfirst:locality:9005", "fr"))
        .thenThrow(new WebApplicationException(429));

    ServiceUnavailableException e =
        assertThrows(
            ServiceUnavailableException.class,
            () -> geocodingLookup.place("whosonfirst:locality:9005", "fr"));
    assertEquals(ErrorCode.GEOCODING_UNAVAILABLE, e.getErrorCode());

    assertThrows(
        ServiceUnavailableException.class,
        () -> geocodingLookup.place("whosonfirst:locality:9005", "fr"));
    verify(geocodingClient, times(2)).placeDetails("whosonfirst:locality:9005", "fr");
  }

  @Test
  void place_whenTheProviderIsUnreachable_shouldBeA503() {
    when(geocodingClient.placeDetails("whosonfirst:locality:9006", "fr"))
        .thenThrow(new ProcessingException("timeout"));

    assertThrows(
        ServiceUnavailableException.class,
        () -> geocodingLookup.place("whosonfirst:locality:9006", "fr"));
  }
}
