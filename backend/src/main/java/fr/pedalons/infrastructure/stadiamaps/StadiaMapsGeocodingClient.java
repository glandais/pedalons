package fr.pedalons.infrastructure.stadiamaps;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.annotation.ClientHeaderParam;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

/**
 * The Stadia Maps geocoder, v2, called from the server for the clients' form fields
 * (docs/LEDGER_*.md OPS-49, API-129): {@code GET /geocoding/v2/autocomplete} while the user types,
 * then {@code GET /geocoding/v2/place_details} once, for the one result they picked.
 *
 * <p><b>Why two calls rather than v1's one.</b> v1 autocomplete returned coordinates and label in a
 * single call but costs 20 credits a request; v2 autocomplete costs 1 credit a request and answers
 * {@code geometry: null} for most hits, the position coming from a Place Lookup at 20 credits per
 * GID (stadiamaps.com/pricing, as of 2026-10-17). A search of about four keystrokes followed by a
 * pick is therefore ~80 credits in v1 and ~24 in v2. The arithmetic only holds if the lookup runs
 * on <em>selection</em>: resolving the five suggestions up front would be 5 × 20 credits per
 * keystroke, worse than v1.
 *
 * <p>Same host, same key and same header as the routing client ({@code StadiaMapsClient}): the base
 * URL is {@code quarkus.rest-client.stadiamaps.url} ({@code https://api-eu.stadiamaps.com}, the
 * EU-only host) and the key goes in {@code Authorization: Stadia-Auth}, never in a query
 * parameter. A config key of its own all the same: two interfaces sharing one config key is not
 * something to bet a feature on.
 *
 * <p>Both endpoints answer a GeoJSON {@code FeatureCollection} ({@link GeocodingResponse}): {@code
 * features[].geometry} is {@code null} or a point whose {@code coordinates} are {@code [lon, lat]};
 * {@code features[].properties} carries {@code gid}, {@code name}, {@code coarse_location}, {@code
 * layer}… — and no {@code label}, unlike v1 ({@link GeocodingFeature}).
 */
@RegisterRestClient(configKey = "stadiamaps-geocoding")
@Path("/geocoding/v2")
@ClientHeaderParam(
    name = "Authorization",
    value = "Stadia-Auth ${pedalons.routing.stadiamaps.api-key}")
public interface StadiaMapsGeocodingClient {

  /**
   * 1 credit a request.
   *
   * @param text what is being typed
   * @param size the maximum number of features returned
   * @param language a BCP 47 tag; localises the names only, not which places match
   */
  @GET
  @Path("/autocomplete")
  @Produces(MediaType.APPLICATION_JSON)
  GeocodingResponse autocomplete(
      @QueryParam("text") String text,
      @QueryParam("size") int size,
      @QueryParam("lang") String language);

  /**
   * 20 credits per GID: always call it with a single one, the one the user picked.
   *
   * <p>The feature returned may carry another {@code gid} than the one asked for (asking for a
   * {@code locality} can answer the matching {@code localadmin}): take the first feature, never
   * match on the id.
   *
   * @param ids a Pelias global id, e.g. {@code whosonfirst:locality:101750851}
   * @param language a BCP 47 tag
   */
  @GET
  @Path("/place_details")
  @Produces(MediaType.APPLICATION_JSON)
  GeocodingResponse placeDetails(
      @QueryParam("ids") String ids, @QueryParam("lang") String language);
}
