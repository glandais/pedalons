package fr.pedalons.infrastructure.stadiamaps;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.annotation.ClientHeaderParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * The Stadia Maps geocoder, {@code GET /geocoding/v1/autocomplete}, called from the server for the
 * clients' form fields (docs/LEDGER_*.md OPS-49).
 *
 * <p><b>v1 on purpose, not v2.</b> {@code /geocoding/v2/autocomplete} answers with {@code geometry:
 * null} and expects a second call, {@code /geocoding/v2/place?ids=}, once the user has picked a
 * result. v1 returns the coordinates and the label in one call, which is all a form field that
 * stores a position needs. To revisit if Stadia Maps retires the v1 endpoints.
 *
 * <p>Same host, same key and same header as the routing client ({@code StadiaMapsClient}): the base
 * URL is {@code quarkus.rest-client.stadiamaps.url} ({@code https://api-eu.stadiamaps.com}, the
 * EU-only host) and the key goes in {@code Authorization: Stadia-Auth}, never in a query
 * parameter. A config key of its own all the same: two interfaces sharing one config key is not
 * something to bet a feature on.
 *
 * <p>The response is a GeoJSON {@code FeatureCollection}: {@code features[].geometry.coordinates}
 * is {@code [lon, lat]}, {@code features[].properties} carries {@code gid}, {@code label}, {@code
 * name}, {@code layer}… ({@link GeocodingFeature}).
 */
@RegisterRestClient(configKey = "stadiamaps-geocoding")
@Path("/geocoding/v1")
@ClientHeaderParam(
    name = "Authorization",
    value = "Stadia-Auth ${pedalons.routing.stadiamaps.api-key}")
public interface StadiaMapsGeocodingClient {

  /**
   * @param text what is being typed
   * @param size the maximum number of features returned
   * @param language a BCP 47 tag; localises the labels only, not which places match
   */
  @GET
  @Path("/autocomplete")
  @Produces(MediaType.APPLICATION_JSON)
  GeocodingResponse autocomplete(
      @QueryParam("text") String text,
      @QueryParam("size") int size,
      @QueryParam("lang") String language);
}
